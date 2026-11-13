#!/bin/zsh
# Compila o app e instala num iPhone ligado ao Mac (cabo ou mesma rede), usando a API do Mac.
#
# 1. Copia o app para ~/Developer/ModaMax-mobile. Pastas sincronizadas com o iCloud
#    (como Documentos) colocam atributos nos arquivos que impedem o Xcode de assinar o app.
# 2. Usa o Team da conta Apple adicionada no Xcode (Xcode > Settings > Accounts).
#    Para escolher outro: TEAM=ABCDE12345 ./preparar_iphone.sh
# 3. Configura o endereco da API com o IP do Mac na rede (porta 5248), compila e instala.
#    Sem iPhone conectado, so abre o projeto no Xcode.
#
# A API precisa estar rodando aceitando conexoes da rede:
#   dotnet run --project modamax.web/modamax.web.csproj --launch-profile sqlite --urls http://0.0.0.0:5248
#
# Primeira vez no iPhone: ative Ajustes > Privacidade e Seguranca > Modo de Desenvolvedor e,
# depois de instalar, confie no perfil em Ajustes > Geral > VPN e Gerenciamento de Dispositivo.
#
# Uso: ./preparar_iphone.sh [ip-do-mac]
set -e
ORIGEM="${0:A:h}"
DESTINO="$HOME/Developer/ModaMax-mobile"
IP="${1:-$(ipconfig getifaddr en0)}"
[[ -z "$IP" ]] && { echo "Nao encontrei o IP do Mac no Wi-Fi. Informe: ./preparar_iphone.sh 192.168.0.10"; exit 1; }
TEAM="${TEAM:-$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | awk -F'= ' '/teamID/ { gsub(/[; "]/, "", $2); print $2; exit }')}"

mkdir -p "$DESTINO"
rsync -a --delete --exclude build --exclude .dart_tool --exclude ios/Pods "$ORIGEM/" "$DESTINO/"
cd "$DESTINO"
flutter pub get

if [[ -z "$TEAM" ]]; then
  flutter build ios --config-only --debug --no-codesign --dart-define=API_URL="http://$IP:5248"
  echo "Nenhuma conta Apple no Xcode. Adicione em Xcode > Settings > Accounts e rode de novo."
  open ios/Runner.xcworkspace
  exit 0
fi

# Team so na copia: o repositorio continua sem o identificador pessoal de ninguem.
sed -i '' "s/^\(\t*\)PRODUCT_BUNDLE_IDENTIFIER = br.com.modamax.modamaxMobile;/\1DEVELOPMENT_TEAM = $TEAM;\n\1PRODUCT_BUNDLE_IDENTIFIER = br.com.modamax.modamaxMobile;/" ios/Runner.xcodeproj/project.pbxproj

flutter build ios --config-only --release --dart-define=API_URL="http://$IP:5248"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/xcode \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet build
APP="build/xcode/Build/Products/Release-iphoneos/Runner.app"

IPHONE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /(available|connected)/ && !/simulated/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }')
if [[ -z "$IPHONE" ]]; then
  echo "App compilado em $DESTINO/$APP, mas nenhum iPhone conectado foi encontrado."
  exit 0
fi
xcrun devicectl device install app --device "$IPHONE" "$APP" >/dev/null
echo "App instalado no iPhone ($IPHONE). API: http://$IP:5248"
