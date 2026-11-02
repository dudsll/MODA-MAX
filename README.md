# ModaMax

Solução integrada para a gestão da ModaMax Distribuidora e Varejo: aplicação Web (ASP.NET Core MVC), API REST, aplicativo mobile (Flutter) e banco de dados SQL Server. A solução centraliza cadastros, estoque, pedidos, usuários, relatórios e auditoria.

## Sobre o projeto

O ModaMax Web foi criado para organizar processos básicos de uma operação comercial de moda, com foco em controle de produtos, clientes, pedidos e indicadores gerenciais.

Principais recursos:

- Dashboard com totais de produtos, clientes, pedidos, usuários, faturamento e alertas de estoque.
- Gestão de produtos, categorias e fornecedores.
- Cadastro e manutenção de clientes.
- Registro, edição, cancelamento e histórico de pedidos.
- Controle de usuários por nível de acesso.
- Relatórios por período.
- Registro de logs de auditoria.
- API REST com autenticação JWT consumida pelo aplicativo mobile.
- App mobile com painel, consulta de produtos, cadastro de clientes e registro de pedidos (com modo offline).
- Banco SQL Server com procedures, triggers e dados de demonstração criados automaticamente.

## Tecnologias utilizadas

- .NET 10 / ASP.NET Core MVC (aplicação Web)
- ASP.NET Core Web API com autenticação JWT (API REST)
- Entity Framework Core 10 + migrations
- SQL Server 2022 (procedures, triggers e constraints)
- Flutter (aplicativo mobile)
- Docker / Docker Compose e GitHub Actions (CI)
- Bootstrap e jQuery

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
| Regras de negócio | `Services/` | Pedidos (estoque, atacado, transação), hash de senha, emissão de token |
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
├── tests/ModaMax.Tests/         # testes automatizados (xUnit)
└── modamax.web/
    ├── Controllers/  (Api/ = API REST)
    ├── Data/
    ├── Dtos/
    ├── Filters/
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

Esse modo cria um arquivo `modamax_local.db` com os dados de demonstração. Ele serve para desenvolvimento e para os testes; as procedures e triggers só existem no SQL Server, então os endpoints que usam procedure (relatório de vendas, estoque baixo e entrada de estoque) só funcionam no modo completo abaixo.

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

São 29 testes: regras de pedido (estoque, atacado, edição, cancelamento), recuperação de senha (token de uso único, expiração, hash) e testes de integração da API e das páginas, com a aplicação rodando em memória.

Para subir tudo em containers (banco + Web/API em `http://localhost:8080`):

```bash
docker compose up -d --build
```

### 3. App mobile (Flutter)

```bash
cd modamax_mobile
flutter create . --platforms=android,ios --project-name modamax_mobile
flutter pub get
flutter run
```

`flutter create .` só gera as pastas `android/` e `ios/` (não sobrescreve `lib/`). Como a API local usa HTTP, no Android adicione `android:usesCleartextTraffic="true"` na tag `<application>` de `android/app/src/main/AndroidManifest.xml`.

O app usa `http://10.0.2.2:5248` no emulador Android e `http://localhost:5248` no simulador iOS. Para apontar para outro servidor:

```bash
flutter run --dart-define=API_URL=https://seu-servidor
```

## Banco de dados

SQL Server, com a estrutura versionada por migrations do EF Core (`modamax.web/Migrations`):

- `EstruturaInicialSqlServer`: tabelas, chaves, índices e constraints (`CHECK` de estoque, preço, quantidade e valor).
- `ProceduresETriggers`:
  - `sp_RelatorioVendasPeriodo`: vendas por dia no período (usada em `GET /api/relatorios/vendas`).
  - `sp_ProdutosEstoqueBaixo`: produtos abaixo do limite de estoque (`GET /api/produtos/estoque-baixo`).
  - `sp_RegistrarEntradaEstoque`: entrada de mercadoria com movimentação, em transação (`POST /api/produtos/{id}/entrada-estoque`).
  - `trg_Produto_AuditaPreco` e `trg_Pedido_AuditaStatus`: auditoria automática em `LogSistema`.

O script completo está em `Database/modamax_sqlserver.sql`. Para gerá-lo de novo:

```bash
dotnet ef migrations script --project modamax.web -o Database/modamax_sqlserver.sql
```

## API REST

Todas as rotas (menos o login) exigem o cabeçalho `Authorization: Bearer <token>`.

| Método | Rota | Descrição |
| ------ | ---- | --------- |
| POST | `/api/auth/login` | Autentica e devolve o token JWT |
| GET | `/api/dashboard` | Indicadores gerais |
| GET | `/api/categorias` | Categorias |
| GET/POST | `/api/produtos` | Lista (filtros `busca`, `categoriaId`, `somenteDisponiveis`) e cadastra |
| GET/PUT/DELETE | `/api/produtos/{id}` | Consulta, altera e exclui |
| GET | `/api/produtos/estoque-baixo` | Procedure de estoque baixo |
| POST | `/api/produtos/{id}/entrada-estoque` | Procedure de entrada de estoque |
| GET/POST | `/api/clientes` | Lista e cadastra |
| GET/PUT/DELETE | `/api/clientes/{id}` | Consulta, altera e exclui |
| GET/POST | `/api/pedidos` | Lista e registra pedido com vários itens |
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

### Dashboard

Exibe indicadores gerais e gráficos (Chart.js) de faturamento por mês, produtos mais vendidos, pedidos por status e estoque por categoria, além de produtos com menor estoque, pedidos recentes e logs. O app mobile mostra os mesmos indicadores.

### Produtos

Permite listar, filtrar, visualizar, criar, editar e excluir produtos, respeitando o nível de acesso do usuário.

### Categorias

Permite gerenciar categorias de produtos.

### Clientes

Permite cadastrar, consultar, editar e excluir clientes.

### Pedidos

Permite registrar pedidos com vários produtos (com total estimado em tempo real), editar itens, consultar detalhes, cancelar pedidos e visualizar histórico por cliente. Web e API usam as mesmas regras (`PedidoService`): preço de atacado, validação e baixa de estoque em transação.

### Usuários

Permite gerenciar usuários do sistema. Acesso restrito ao nível Estratégico.

### Relatórios

Permite consultar dados consolidados por período. Acesso permitido aos níveis Estratégico e Tático.

### Logs

Permite consultar registros de auditoria do sistema. Acesso restrito ao nível Estratégico.

## Integração contínua e implantação

O workflow `.github/workflows/ci.yml` roda a cada push/pull request:

1. compila a Web/API, roda os testes automatizados e gera o script do banco a partir das migrations;
2. roda `flutter analyze` e `flutter test` no app mobile;
3. monta a imagem Docker da aplicação.

Em produção, configure por variáveis de ambiente (nunca no repositório):

- `ConnectionStrings__DefaultConnection`: conexão com o SQL Server / Azure SQL;
- `Jwt__Key`: chave de assinatura dos tokens (mínimo de 32 caracteres);
- `Smtp__Host`, `Smtp__Porta`, `Smtp__Usuario`, `Smtp__Senha`, `Smtp__Remetente`: envio dos e-mails de recuperação de senha. Sem SMTP, o e-mail vai para o log (e, em desenvolvimento, o link aparece na tela).

## Segurança

- Senhas armazenadas com hash PBKDF2 (`PasswordHasher` do ASP.NET Core Identity).
- Recuperação de senha por link enviado por e-mail: token aleatório de uso único, válido por 30 minutos, gravado só como hash SHA-256; a resposta é a mesma exista ou não o e-mail.
- API protegida por JWT com papéis por nível de acesso (`Estrategico`, `Tatico`, `Operacional`).
- Web protegida por sessão e filtro de nível de acesso, com tokens antifalsificação nos formulários.
- Regras de integridade no banco (chaves estrangeiras, `CHECK`, e-mail de usuário único).
- Auditoria de ações em `LogSistema` (aplicação e triggers).

## Licença

Consulte o arquivo `LICENSE` para mais detalhes.
