#!/bin/zsh
# Gera o APK do app e instala num celular Android ligado ao Mac (cabo USB ou Wi-Fi), usando a
# API do Mac.
#
# 1. Copia o app para ~/Developer/ModaMax-android (fora da pasta sincronizada com o iCloud,
#    que deixa a compilacao lenta e coloca atributos nos arquivos).
# 2. Configura o endereco da API com o IP do Mac na rede (porta 5248) e gera o APK final.
# 3. Copia o APK para a Mesa (ModaMax.apk), para enviar ou instalar a mao, e instala no celular
#    se houver um conectado. Sem celular, so gera o arquivo.
#
# A API precisa estar rodando aceitando conexoes da rede:
#   dotnet run --project modamax.web/modamax.web.csproj --launch-profile sqlite --urls http://0.0.0.0:5248
#
# Primeira vez no celular: ative as Opcoes do desenvolvedor (Configuracoes > Sobre o telefone >
# toque 7 vezes em "Numero da versao") e, nelas, a "Depuracao USB". Ao ligar o cabo, aceite o
# aviso "Permitir depuracao USB?". Sem cabo: abra o ModaMax.apk no celular e permita instalar.
#
# Uso: ./preparar_android.sh [ip-do-mac]
set -e
ORIGEM="${0:A:h}"
DESTINO="$HOME/Developer/ModaMax-android"
IP="${1:-$(ipconfig getifaddr en0)}"
[[ -z "$IP" ]] && { echo "Nao encontrei o IP do Mac na rede. Informe: ./preparar_android.sh 192.168.0.10"; exit 1; }

# Java e SDK instalados pelo Homebrew (openjdk@21 e android-commandlinetools).
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$ANDROID_HOME/platform-tools/adb"

mkdir -p "$DESTINO"
rsync -a --delete --exclude build --exclude .dart_tool --exclude ios/Pods --exclude android/.gradle "$ORIGEM/" "$DESTINO/"
cd "$DESTINO"
flutter pub get
flutter build apk --release --dart-define=API_URL="http://$IP:5248"
APK="$DESTINO/build/app/outputs/flutter-apk/app-release.apk"
cp "$APK" "$HOME/Desktop/ModaMax.apk"

CELULAR=$("$ADB" devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1; exit }')
if [[ -z "$CELULAR" ]]; then
  echo "APK gerado: $HOME/Desktop/ModaMax.apk (API: http://$IP:5248)"
  echo "Nenhum Android conectado. Ligue o cabo com a depuracao USB ativa, ou instale o APK a mao."
  exit 0
fi
"$ADB" -s "$CELULAR" install -r "$APK" >/dev/null
echo "App instalado no Android ($CELULAR). API: http://$IP:5248"
