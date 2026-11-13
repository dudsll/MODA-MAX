# ModaMax

Solução integrada para a gestão da ModaMax Distribuidora e Varejo: aplicação Web (ASP.NET Core MVC), API REST, aplicativo mobile (Flutter) e banco de dados SQL Server. A solução centraliza vendas, pagamentos, estoque, clientes, metas, relatórios e auditoria, com uma interface inspirada no design da Apple, em modo claro e escuro.

## Sobre o projeto

O ModaMax foi criado para organizar a operação comercial de uma distribuidora de moda que vende no varejo e no atacado, com foco em vendas, estoque e indicadores para a tomada de decisão.

Principais recursos:

- **Painel** com faturamento, pedidos e ticket médio do mês comparados ao mesmo período do mês anterior, valores a receber, gráficos e alertas de reposição.
- **Metas de vendas** com anéis de progresso no estilo do app Atividade (faturamento, pedidos e peças), projeção de fechamento e histórico.
- **Pedidos** com vários produtos, preço de atacado, **pagamento** (PIX, cartão em até 6x, débito, boleto ou dinheiro), **QR Code PIX** (BR Code) e confirmação de recebimento.
- **Central de reposição** que prevê, pelo ritmo de vendas, quantos dias o estoque dura e quanto comprar, com pedido de compra em Excel por fornecedor.
- **Produtos** com foto, código de barras EAN/GTIN, histórico de movimentações e **etiquetas com código de barras** para imprimir.
- **Curva ABC** de produtos (Pareto) e relatórios por período exportáveis em PDF e Excel.
- **Busca global** estilo Spotlight (⌘K / Ctrl+K) por produtos, clientes, pedidos e telas.
- **Instalável como aplicativo** (PWA) no computador e no celular, com página offline.
- Controle de usuários por nível de acesso, bloqueio após tentativas de senha e limite de requisições.
- Tradutor de LIBRAS (VLibras), modo escuro e layout responsivo.
- API REST com autenticação JWT e erros padronizados (Problem Details), consumida pelo aplicativo.
- App mobile com painel e anéis de meta, produtos com foto, leitor de código de barras, entrada de estoque, reposição, pedidos com pagamento e PIX copia e cola (com modo offline).
- Banco SQL Server com procedures, triggers e dados de demonstração criados automaticamente.

## Tecnologias utilizadas

- .NET 10 / ASP.NET Core MVC (aplicação Web)
- ASP.NET Core Web API com autenticação JWT (API REST)
- Entity Framework Core 10 + migrations
- SQL Server 2022 (procedures, triggers e constraints)
- Flutter (aplicativo mobile) com `mobile_scanner` (leitor de código de barras)
- ClosedXML (Excel) e QuestPDF (PDF, licença Community)
- Serilog (logs estruturados)
- xUnit e Testcontainers (testes, inclusive com SQL Server real)
- QRCoder (QR Code do PIX)
- Docker / Docker Compose e GitHub Actions (CI)
- Bootstrap 5.3, Chart.js 4 e ícones Lucide (todos servidos pelo próprio sistema, funcionam sem internet), VLibras

## Arquitetura

```text
App Flutter ──HTTP/JSON + JWT──┐
                               ├──> API REST (Controllers/Api) ──┐
Navegador ──sessão─> MVC (Controllers + Views) ──────────────────┼──> Services (regras) ──> EF Core ──> SQL Server
                                                                  └─────────────────────────────────────> procedures / triggers
```

| Camada | Pasta | Responsabilidade |
| ------ | ----- | ---------------- |
| Apresentação Web | `Controllers/`, `Views/`, `ViewModels/` | Telas MVC e controle de acesso por sessão (`Filters/RequireUserAttribute`) |
| API REST | `Controllers/Api/`, `Dtos/` | Endpoints JSON consumidos pelo app mobile |
| Regras de negócio | `Services/` | Pedidos e pagamentos, PIX, metas, reposição, Curva ABC, relatórios e exportação, login com bloqueio, fotos, código de barras e etiquetas, hash de senha, token |
| Infraestrutura | `Infraestrutura/` | Limite de requisições por IP e erros padronizados da API |
| Dados | `Models/`, `Data/`, `Migrations/` | Entidades, `AppDbContext`, seed e evolução do banco |
| Mobile | `../modamax_mobile/` | App Flutter (login, painel, produtos, clientes, pedidos) |

## Estrutura do projeto

```text
modamax.web/
├── modamax.web.sln
├── docker-compose.yml           # SQL Server + Web/API em containers
├── .github/workflows/ci.yml     # pipeline de integração contínua
├── Database/
│   └── modamax_sqlserver.sql    # script completo do banco (gerado das migrations)
├── modamax_mobile/              # aplicativo Flutter
├── tests/ModaMax.Tests/         # testes de regras e da API (xUnit + SQLite em memória)
├── tests/ModaMax.IntegrationTests/  # testes com SQL Server real (Testcontainers)
└── modamax.web/
    ├── Controllers/  (Api/ = API REST)
    ├── Data/
    ├── Dtos/
    ├── Filters/
    ├── Infraestrutura/
    ├── Migrations/
    ├── Models/
    ├── Services/
    ├── ViewModels/
    ├── Views/
    ├── Dockerfile
    └── Program.cs
```

## Pré-requisitos

- [.NET SDK 10](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (para o SQL Server). Em Mac com Apple Silicon, ative *Use Rosetta for x86/amd64 emulation* nas configurações do Docker Desktop.
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (para o app mobile)

## Como executar

### Modo rápido, sem Docker (SQLite)

Para abrir o sistema na hora, sem instalar o SQL Server:

```bash
dotnet run --project modamax.web/modamax.web.csproj --launch-profile sqlite
```

Esse modo cria um arquivo `modamax_local.db` com os dados de demonstração e serve para desenvolvimento, apresentações e testes. As procedures e triggers só existem no SQL Server: no modo rápido, a entrada de estoque é feita pelo próprio sistema (mesma regra, em transação), e os endpoints de relatório de vendas e de estoque baixo da API, que chamam procedures, só funcionam no modo completo abaixo.

### 1. Banco de dados (SQL Server em Docker)

```bash
docker compose up -d sqlserver
```

A senha de desenvolvimento do `sa` é `ModaMax@Dev2026` (pode ser trocada com a variável `SA_PASSWORD`).

### 2. Aplicação Web + API

```bash
dotnet run --project modamax.web/modamax.web.csproj
```

Na primeira execução as migrations criam as tabelas, procedures e triggers, e o seed insere os dados de demonstração.

- Web: `http://localhost:5248`
- Documentação da API (Swagger): `http://localhost:5248/swagger`
- Monitoramento (health check): `http://localhost:5248/health`

### Testes automatizados

```bash
dotnet test tests/ModaMax.Tests
```

São 95 testes, com a aplicação rodando em memória (SQLite): regras de pedido e de pagamento, PIX (BR Code e CRC16), metas, central de reposição, Curva ABC, código de barras e desenho do EAN-13, bloqueio de login e limite de requisições, recuperação de senha, fotos, relatórios e exportações, e a API de ponta a ponta (permissões, Problem Details, pagamentos, metas, reposição, busca por código, cadastro e exclusão de produtos e clientes, envio de foto e arquivos do PWA).

```bash
dotnet test tests/ModaMax.IntegrationTests
```

São mais 14 testes que sobem um SQL Server 2022 de verdade com Testcontainers e verificam as procedures, os triggers, as restrições `CHECK` (estoque e parcelas), os índices únicos (código de barras e meta por mês), as transações, a entrada de estoque pela procedure, as metas e a Curva ABC. Precisam do Docker; sem ele, aparecem como ignorados. No CI eles são obrigatórios (`MODAMAX_TESTES_SQLSERVER=1`).

Para subir tudo em containers (banco + Web/API em `http://localhost:8080`):

```bash
docker compose up -d --build
```

### 3. App mobile (Flutter)

As pastas `android/` e `ios/` já estão no repositório, com a permissão de câmera, o acesso à API local por HTTP e o acesso à galeria para as fotos dos produtos.

```bash
cd modamax_mobile
flutter pub get
flutter run
```

O app usa `http://10.0.2.2:5248` no emulador Android e `http://localhost:5248` no simulador iOS. Para apontar para outro servidor:

```bash
flutter run --dart-define=API_URL=https://seu-servidor
```

No login, os botões **Diretoria**, **Gerência** e **Vendas** preenchem os acessos de demonstração (senha `123456`). Para esconder numa versão de produção: `--dart-define=ESCONDER_DEMO=true`.

O que o app faz: painel com anéis de meta e reposição, com cada indicador abrindo a tela correspondente (cada aba mantém a sua navegação e a barra inferior fica sempre visível); produtos agrupados por modelo, com os itens (tamanho e cor) dentro da tela do modelo, filtros por tipo, fornecedor, tamanho, cor, disponibilidade e preço, leitor de código de barras, entrada de estoque e cadastro, edição e exclusão com foto pela câmera; clientes com ficha no estilo do app Contatos; pedidos com forma de pagamento e PIX copia e cola. Para apagar um cliente ou produto, use **Apagar** no fim da tela de edição ou arraste o item da lista para a esquerda (cliente: gerência e diretoria; produto: diretoria; quem já tem pedidos não pode ser apagado).

**Visual de cada sistema.** O app usa os componentes nativos de cada plataforma, com a mesma lógica: no iPhone, os da Apple (Cupertino) — barra de abas e títulos grandes do iOS, listas agrupadas, formulários como os de Contatos, alertas e menus de ação do iOS, deslizar para revelar "Apagar", puxar para atualizar e a tipografia San Francisco; no Android, os do Material 3. As peças ficam em `lib/widgets/adaptativo.dart`.

**Teste de ponta a ponta.** `integration_test/fluxos_test.dart` abre o app de verdade e percorre os fluxos principais (login, painel, busca, filtros, itens, clientes, pedidos com PIX e cartão, cancelamento). Com a API rodando em modo demonstração e um simulador ligado (a partir de uma pasta fora do iCloud, como no script do iPhone):

```bash
flutter test integration_test -d <id-do-simulador>
```

#### No iPhone (pelo cabo)

1. Suba a API aceitando conexões da rede:

```bash
dotnet run --project modamax.web/modamax.web.csproj --launch-profile sqlite --urls http://0.0.0.0:5248
```

2. No Xcode, adicione o seu Apple ID em **Xcode > Settings > Accounts** (a conta gratuita serve; o app instalado vale por 7 dias).
3. Ligue o iPhone no Mac pelo cabo, toque em **Confiar** e ative **Ajustes > Privacidade e Segurança > Modo de Desenvolvedor**.
4. Rode o script, que compila, assina com a sua conta e instala o app usando o IP do Mac na rede:

```bash
./modamax_mobile/preparar_iphone.sh
```

5. Na primeira vez, confie no seu perfil em **Ajustes > Geral > VPN e Gerenciamento de Dispositivo** e permita o acesso à rede local quando o app pedir.

O script compila uma cópia em `~/Developer/ModaMax-mobile`: pastas sincronizadas com o iCloud (como Documentos) deixam atributos nos arquivos que impedem o Xcode de assinar o app. O Team da conta Apple é gravado só nessa cópia, nunca no repositório.

## Banco de dados

SQL Server, com a estrutura versionada por migrations do EF Core (`modamax.web/Migrations`):

- `EstruturaInicialSqlServer`: tabelas, chaves, índices e constraints (`CHECK` de estoque, preço, quantidade e valor).
- `ProceduresETriggers`:
  - `sp_RelatorioVendasPeriodo`: vendas por dia no período (usada em `GET /api/relatorios/vendas`).
  - `sp_ProdutosEstoqueBaixo`: produtos abaixo do limite de estoque (`GET /api/produtos/estoque-baixo`).
  - `sp_RegistrarEntradaEstoque`: entrada de mercadoria com movimentação, em transação (`POST /api/produtos/{id}/entrada-estoque`).
  - `trg_Produto_AuditaPreco` e `trg_Pedido_AuditaStatus`: auditoria automática em `LogSistema`.
- `RecuperacaoSenha`: tabela dos links de redefinição de senha.
- `FotosCodigoBarrasBloqueioLogin`: código de barras (índice único filtrado) e foto do produto; tentativas e bloqueio no usuário.
- `MetasEPagamentos`: tabela `Meta` (uma por mês) e forma, parcelas (`CHECK` de 1 a 6), situação e data do pagamento no pedido.

O script completo está em `Database/modamax_sqlserver.sql`. Para gerá-lo de novo:

```bash
dotnet ef migrations script --project modamax.web -o Database/modamax_sqlserver.sql
```

## API REST

Todas as rotas (menos o login) exigem o cabeçalho `Authorization: Bearer <token>`. Os erros seguem o padrão Problem Details (RFC 9457), com a mensagem para o usuário no campo `detail`:

```json
{ "title": "Requisicao invalida.", "status": 400, "detail": "Estoque insuficiente para Saia Jeans (disponivel: 17).", "traceId": "00-..." }
```

Códigos usados: 400 (dados inválidos), 401 (sem login ou senha errada), 403 (nível sem permissão), 404 (não encontrado), 409 (conflito), 423 (conta bloqueada) e 429 (muitas tentativas).

| Método | Rota | Descrição |
| ------ | ---- | --------- |
| POST | `/api/auth/login` | Autentica e devolve o token JWT |
| GET | `/api/dashboard` | Indicadores gerais |
| GET | `/api/categorias` | Categorias |
| GET | `/api/fornecedores` | Fornecedores (formulário de produto do app) |
| GET/POST | `/api/produtos` | Lista (filtros `busca`, `categoriaId`, `somenteDisponiveis`) e cadastra |
| GET/PUT/DELETE | `/api/produtos/{id}` | Consulta, altera e exclui |
| GET | `/api/produtos/codigo/{codigo}` | Produto pelo código de barras (leitor do app) |
| POST | `/api/produtos/{id}/foto` | Envia a foto (multipart, campo `foto`) |
| PUT | `/api/pedidos/{id}/pagamento` | Confirma o pagamento do pedido |
| GET | `/api/pedidos/{id}/pix` | PIX copia e cola do pedido pendente |
| GET | `/api/metas/atual` | Progresso das metas do mês |
| GET | `/api/reposicao` | Central de reposição (críticos primeiro) |
| GET | `/api/produtos/estoque-baixo` | Procedure de estoque baixo |
| POST | `/api/produtos/{id}/entrada-estoque` | Procedure de entrada de estoque |
| GET/POST | `/api/clientes` | Lista e cadastra |
| GET/PUT/DELETE | `/api/clientes/{id}` | Consulta, altera e exclui |
| GET/POST | `/api/pedidos` | Lista e registra pedido com vários itens, forma de pagamento e parcelas |
| GET | `/api/pedidos/{id}` | Detalhe do pedido |
| PUT | `/api/pedidos/{id}/cancelar` | Cancela e devolve os itens ao estoque |
| GET | `/api/relatorios/vendas` | Procedure de vendas por período |

## Acesso inicial

O seed inicial cria três usuários para teste (as senhas ficam gravadas com hash no banco):

| Perfil            | E-mail                    | Senha    | Nível       |
| ----------------- | ------------------------- | -------- | ----------- |
| Diretoria ModaMax | `estrategico@modamax.com` | `123456` | Estratégico |
| Gestora Comercial | `tatico@modamax.com`      | `123456` | Tático      |
| Operador de Loja  | `operacional@modamax.com` | `123456` | Operacional |

## Níveis de acesso

O controle de acesso é feito pelo filtro `RequireUserAttribute`, com base no nível salvo na sessão do usuário.

- Estratégico: acesso completo, incluindo usuários, logs e exclusões restritas.
- Tático: acesso às rotinas gerenciais, cadastros e relatórios.
- Operacional: acesso às rotinas operacionais, como consulta e movimentação de pedidos, produtos e clientes.

## Funcionalidades por módulo

### Painel

Saudação, faturamento, pedidos e ticket médio do mês com a variação em relação ao mesmo período do mês anterior, total a receber, anéis de meta, gráficos (Chart.js) de faturamento por mês, mais vendidos, pedidos por status e estoque por categoria, pedidos recentes e produtos que precisam de reposição. Os gráficos acompanham o tema claro/escuro.

### Metas

Três anéis concêntricos (faturamento, pedidos e peças) mostram quanto da meta do mês já foi atingido, com a projeção de fechamento pelo ritmo atual e quanto é preciso vender por dia. Sem meta cadastrada, o sistema sugere a média dos três meses anteriores com 10% de crescimento. O histórico mostra os meses em que a meta foi batida. Só o nível Estratégico define metas.

### Pedidos e pagamentos

Pedidos com vários produtos (total estimado em tempo real), preço de atacado, forma de pagamento e parcelas (só no crédito, até 6x). Nos detalhes, um pedido PIX pendente mostra o **QR Code** e o **PIX copia e cola** no padrão BR Code do Banco Central (com CRC16), e o botão **Confirmar pagamento** registra o recebimento. Cancelar um pedido pago muda o pagamento para **Estornado**. A chave PIX é de demonstração (configurável em `Pix:Chave`).

### Central de reposição

Para cada produto, calcula a média de vendas dos últimos 30 dias, quantos dias o estoque dura e a quantidade a comprar para cobrir o prazo de entrega (7 dias) mais 30 dias de vendas, classificando em **Crítico**, **Atenção** ou **Em dia**. Gerência e diretoria registram a entrada de mercadoria ali mesmo e exportam o **pedido de compra** em Excel, com uma aba por fornecedor. Os parâmetros ficam em `Reposicao` no `appsettings.json`.

### Produtos e etiquetas

Listar, filtrar (inclusive pelo código de barras), cadastrar, editar e excluir produtos, com foto (JPG, PNG ou WebP de até 2 MB, conferida pelo conteúdo do arquivo) e código de barras EAN/GTIN validado pelo dígito verificador. Os detalhes mostram o código de barras desenhado, a previsão de reposição e a linha do tempo das últimas entradas e saídas. A tela **Etiquetas** gera etiquetas com nome, preço e código de barras EAN-13 para imprimir e colar nas peças — o app lê essas etiquetas com a câmera.

### Categorias e clientes

Cadastro, consulta, edição e exclusão de categorias e de clientes pessoa física e jurídica.

### Relatórios e Curva ABC

Pedidos, peças, faturamento, ticket médio, produtos mais vendidos e vendas por dia no período, exportáveis em PDF e Excel. A **Curva ABC** classifica os produtos pelo faturamento (A até 80% do acumulado, B até 95%, C o restante), com gráfico de Pareto e exportação em Excel. Acesso dos níveis Estratégico e Tático.

### Busca global

Em qualquer tela, ⌘K (Mac) ou Ctrl+K abre a busca no estilo Spotlight: produtos (nome, categoria ou código de barras), clientes (nome, documento ou e-mail), pedidos (número ou cliente) e atalhos para as telas, navegável pelo teclado.

### Usuários e auditoria

Gestão de usuários e consulta aos registros de auditoria. Acesso restrito ao nível Estratégico.

### Aplicativo instalável (PWA)

O sistema Web tem manifesto e service worker: no Chrome/Edge aparece "Instalar ModaMax", e no iPhone "Adicionar à Tela de Início". Os arquivos visuais ficam em cache e, sem internet, aparece uma página offline.

## Integração contínua e implantação

O workflow `.github/workflows/ci.yml` roda a cada push/pull request:

1. compila a Web/API, roda os 95 testes, sobe um SQL Server em container para os 14 testes de integração e gera o script do banco a partir das migrations;
2. roda `flutter analyze` e `flutter test` no app mobile;
3. monta a imagem Docker da aplicação.

Em produção, configure por variáveis de ambiente (nunca no repositório):

- `ConnectionStrings__DefaultConnection`: conexão com o SQL Server / Azure SQL;
- `Jwt__Key`: chave de assinatura dos tokens (mínimo de 32 caracteres);
- `Smtp__Host`, `Smtp__Porta`, `Smtp__Usuario`, `Smtp__Senha`, `Smtp__Remetente`: envio dos e-mails de recuperação de senha. Sem SMTP, o e-mail vai para o log (e, em desenvolvimento, o link aparece na tela).
- `Seguranca__MaxTentativasLogin` (5), `Seguranca__MinutosBloqueio` (15) e `Seguranca__LimiteRequisicoesPorMinuto` (10): proteção do login.
- `Fotos__Pasta`: pasta das fotos dos produtos (no Docker Compose ela fica no volume `fotos-produtos`).

Em produção os logs saem no console em JSON (Serilog), prontos para Application Insights ou outra ferramenta de monitoramento.

## Segurança

- Senhas armazenadas com hash PBKDF2 (`PasswordHasher` do ASP.NET Core Identity).
- Conta bloqueada por 15 minutos após 5 senhas erradas seguidas (Web e API) e limite de 10 tentativas de login ou de recuperação de senha por minuto para cada IP.
- Recuperação de senha por link enviado por e-mail: token aleatório de uso único, válido por 30 minutos, gravado só como hash SHA-256; a resposta é a mesma exista ou não o e-mail.
- API protegida por JWT com papéis por nível de acesso (`Estrategico`, `Tatico`, `Operacional`).
- Web protegida por sessão e filtro de nível de acesso, com tokens antifalsificação nos formulários.
- Regras de integridade no banco (chaves estrangeiras, `CHECK`, e-mail de usuário único).
- Auditoria de ações em `LogSistema` (aplicação e triggers) e logs estruturados sem dados pessoais desnecessários.
- Upload de fotos validado pelo conteúdo do arquivo, com tamanho máximo e nome aleatório.
- Container Docker rodando com usuário sem privilégios de root.

## Licença

Consulte o arquivo `LICENSE` para mais detalhes.
