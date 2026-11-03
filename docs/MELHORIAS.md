# Melhorias da segunda etapa — PIM IV

Este documento descreve as melhorias feitas no ModaMax depois da migração para SQL Server, API REST e app Flutter.
Para cada melhoria há o problema que existia, a solução adotada, os arquivos envolvidos e como conferir o resultado.

| # | Melhoria | Onde aparece |
|---|----------|--------------|
| 1 | Pedidos com vários produtos | Web (telas de pedido) |
| 2 | Recuperação de senha segura | Web (tela de login) |
| 3 | Dashboard com gráficos | Web, API e app |
| 4 | Testes automatizados | Projeto `tests/` e pipeline de CI |
| 5 | Modo rápido com SQLite | Execução local, sem Docker |
| 6 | Bloqueio de login e limite de tentativas | Web e API |
| 7 | Erros padronizados e logs estruturados | API e servidor |
| 8 | Testes com SQL Server real | `tests/ModaMax.IntegrationTests` e CI |
| 9 | Fotos e código de barras dos produtos | Web e API |
| 10 | Leitor de código de barras | App |
| 11 | Exportação de relatórios em PDF e Excel | Web |
| 12 | VLibras e ajustes de layout | Web |

---

## 1. Pedidos com vários produtos na Web

### Problema
- A tela de pedidos da Web aceitava **um único produto** por pedido. A API já aceitava vários.
- A regra de estoque estava **repetida**: uma cópia no `PedidoController` (Web) e outra no `PedidoService` (API).
  Uma correção feita num lugar podia ser esquecida no outro.

### Solução
- As telas de **novo pedido** e de **edição** compartilham o mesmo formulário (`_PedidoForm.cshtml`).
  Nele é possível adicionar e remover linhas de produto, cada uma com quantidade e desconto.
- O **total estimado** é recalculado no navegador enquanto o usuário digita, já aplicando o preço de atacado.
  O valor gravado continua sendo calculado no servidor.
- A Web passou a usar o **`PedidoService`**, o mesmo da API. As regras ficam num lugar só:
  - preço de atacado com 10% de desconto;
  - validação de estoque (também quando o mesmo produto aparece em duas linhas);
  - baixa e devolução de estoque com registro em `MovimentacoesEstoque`;
  - tudo dentro de uma transação: se um item falha, nada é gravado.
- Ao editar um pedido, o estoque que ele já reservava é devolvido antes da nova validação.
  Assim, o próprio pedido pode reutilizar esse estoque.
- A tela de detalhes mostra o subtotal de cada item e pede confirmação antes de cancelar.

### Correção encontrada durante o teste: arredondamento de 1 centavo
O C# usa por padrão o "arredondamento bancário", que arredonda o meio para o número par: 108,765 vira 108,76.
O total estimado na tela (JavaScript) mostrava 108,77. A regra passou a usar **arredondamento comercial**
(`MidpointRounding.AwayFromZero`), em que 0,5 sempre sobe, e os dois valores agora batem.

### Mudança de regra na API
O cancelamento de pedidos pela API (`PUT /api/pedidos/{id}/cancelar`) agora segue a mesma regra da Web:
só os níveis **Estratégico** e **Tático** podem cancelar. O app esconde o botão de cancelar para o nível Operacional.

### Arquivos
- `modamax.web/Services/PedidoService.cs`
- `modamax.web/Controllers/PedidoController.cs`
- `modamax.web/Controllers/Api/PedidosApiController.cs`
- `modamax.web/ViewModels/PedidoFormViewModel.cs`
- `modamax.web/Views/Pedido/_PedidoForm.cshtml`, `Create.cshtml`, `Edit.cshtml`, `Details.cshtml`, `Historico.cshtml`
- `modamax_mobile/lib/screens/pedidos_screen.dart`

### Como conferir
1. Entre como `estrategico@modamax.com` e abra **Pedidos > Novo pedido**.
2. Adicione dois produtos, escolha **Atacado** e informe um desconto (por exemplo `10,50`).
3. Salve: a tela de detalhes mostra os itens, os subtotais e o total, e o estoque dos dois produtos diminui.
4. Cancele o pedido: o estoque volta ao valor anterior.

---

## 2. Recuperação de senha segura

### Problema (falha de segurança)
A tela "Recuperar senha" trocava a senha de **qualquer usuário** sabendo apenas o e-mail dele.
Bastava saber o e-mail de um gerente para tomar a conta.

### Solução
O fluxo agora segue o padrão usado pelos sistemas reais:

1. O usuário informa o e-mail em **Recuperar senha**.
2. O sistema gera um **token aleatório** de 32 bytes e envia por e-mail um link `/Account/RedefinirSenha?token=...`.
3. O usuário abre o link e cadastra a nova senha (mínimo de 6 caracteres).

Proteções do fluxo:
- **Validade de 30 minutos.**
- **Uso único:** depois de usado, o link deixa de funcionar.
- **Um link por vez:** pedir um novo link invalida os anteriores.
- **Só o hash no banco:** a tabela `RecuperacoesSenha` guarda o hash SHA-256 do token, nunca o token em si.
  Quem tiver acesso ao banco não consegue montar um link válido.
- **Mesma mensagem para qualquer e-mail:** a tela responde igual exista ou não a conta.
  Assim ninguém descobre quais e-mails estão cadastrados.
- **Senha nova com hash**, como no cadastro (PBKDF2, via `PasswordHasher`).

### Envio do e-mail
- Com SMTP configurado (`Smtp__Host`, `Smtp__Porta`, `Smtp__Usuario`, `Smtp__Senha`, `Smtp__Remetente`), o e-mail é enviado de verdade.
- Sem SMTP, o e-mail vai para o log. Em ambiente de desenvolvimento o link também aparece na própria tela,
  o que facilita a demonstração na apresentação. Em produção o link nunca aparece na tela.

### Banco de dados
- Nova tabela `RecuperacoesSenha` (`IdRecuperacao`, `IdUsuario`, `TokenHash`, `CriadoEm`, `ExpiraEm`, `UsadoEm`),
  com chave estrangeira para `Usuarios` e índice único em `TokenHash`.
- Migration `20261031213905_RecuperacaoSenha`. O script `Database/modamax_sqlserver.sql` foi gerado novamente.

### Arquivos
- `modamax.web/Services/RecuperacaoSenhaService.cs`, `modamax.web/Services/EmailService.cs`
- `modamax.web/Models/RecuperacaoSenha.cs`, `modamax.web/ViewModels/RecuperacaoSenhaViewModels.cs`
- `modamax.web/Controllers/AccountController.cs`
- `modamax.web/Views/Account/RecuperarSenha.cshtml`, `RedefinirSenha.cshtml`, `LinkInvalido.cshtml`

### Como conferir
1. Na tela de login, clique em **Recuperar senha** e informe `estrategico@modamax.com`.
2. Em desenvolvimento, o link aparece na tela. Abra e cadastre uma nova senha.
3. Abra o mesmo link de novo: aparece **Link inválido**.
4. A senha antiga não entra mais e a nova entra.

---

## 3. Dashboard com gráficos

### Solução
A página inicial ganhou quatro gráficos, feitos com Chart.js:

| Gráfico | O que mostra |
|---------|--------------|
| Faturamento por mês | Soma dos pedidos dos últimos 6 meses, sem os cancelados |
| Mais vendidos | Os 5 produtos com mais unidades vendidas |
| Pedidos por status | Quantidade de pedidos em cada status |
| Estoque por categoria | Unidades em estoque em cada categoria |

- O cálculo fica no **`DashboardService`**, usado pela Web e pela API.
- Novo endpoint **`GET /api/dashboard/graficos`** (exige login) com os mesmos dados em JSON.
- O **app Flutter** mostra o faturamento por mês e os mais vendidos, desenhados só com widgets do Flutter, sem pacote extra.
  Os dados também ficam no cache offline do app.
- Os gráficos têm descrição para leitores de tela (`aria-label`).
- **Correção:** o card de faturamento da página inicial deixou de somar pedidos cancelados.

### Dados de demonstração
Os dados iniciais agora incluem cerca de 48 vendas espalhadas pelos últimos 4 meses, para os gráficos não aparecerem vazios
na apresentação. O estoque inicial foi aumentado para comportar essas vendas.

### Arquivos
- `modamax.web/Services/DashboardService.cs`
- `modamax.web/Controllers/HomeController.cs`, `modamax.web/Controllers/Api/GestaoApiController.cs`
- `modamax.web/ViewModels/DashboardViewModel.cs`, `modamax.web/Views/Home/Index.cshtml`, `modamax.web/wwwroot/css/site.css`
- `modamax.web/Data/DbInitializer.cs`
- `modamax_mobile/lib/widgets/graficos.dart`, `models.dart`, `services/api_service.dart`, `screens/home_screen.dart`

### Observação para a apresentação
O Chart.js é carregado de uma CDN. Sem internet, a página abre normalmente, mas os gráficos não aparecem.

---

## 4. Testes automatizados

Novo projeto `tests/ModaMax.Tests` (xUnit) com **29 testes**. Eles rodam com um banco SQLite em memória,
então não precisam de Docker nem de SQL Server.

| Arquivo | O que cobre |
|---------|-------------|
| `PedidoServiceTests.cs` | Pedido com vários itens, preço de atacado e arredondamento, estoque insuficiente, mesmo produto em duas linhas, desconto maior que o item, cancelamento, edição, exclusão |
| `RecuperacaoSenhaServiceTests.cs` | E-mail inexistente, uso único, token expirado, novo pedido invalida o link anterior, banco guarda só o hash, token inventado |
| `ApiTests.cs` | A aplicação inteira rodando em memória: login, endpoints protegidos, criação de pedido pela API, permissão de cancelamento por nível, gráficos, páginas públicas |

Para ter certeza de que os testes pegam erros de verdade, o arredondamento antigo foi recolocado de propósito
e o teste correspondente falhou. Depois a correção voltou.

Os testes também rodam no **pipeline de CI** (etapa "Testes automatizados") a cada push e pull request.

Para rodar localmente:

```bash
dotnet test tests/ModaMax.Tests
```

---

## 5. Modo rápido com SQLite

Para abrir o sistema sem subir o SQL Server no Docker:

```bash
dotnet run --project modamax.web/modamax.web.csproj --launch-profile sqlite
```

- O banco `modamax_local.db` é criado na hora, já com os dados de demonstração, e fica fora do Git.
- O modo oficial continua sendo o **SQL Server**. As stored procedures (relatório de vendas, estoque baixo e entrada de estoque)
  só funcionam nele.

---

## Outras mudanças

- O sistema usa sempre o formato brasileiro (R$, vírgula decimal e datas dd/mm/aaaa), inclusive no Docker e no Azure,
  onde o servidor costuma estar em inglês.
- O README foi atualizado com o modo rápido, os testes, as variáveis de SMTP e as novas regras de segurança.

## Limitações conhecidas

- Os gráficos dependem de internet (Chart.js via CDN).
- Sem SMTP configurado, o e-mail de recuperação não é enviado de verdade; em produção é preciso configurar um servidor de e-mail.
- O app Flutter não tem testes das telas novas; a validação dele no CI é feita pelo `flutter analyze` e pelo teste existente.

---

# Terceira etapa

## 6. Bloqueio de login e limite de tentativas

**Problema:** era possível testar senhas sem limite, tanto na Web quanto na API.

**Solução:**
- O `LoginService`, usado pela Web e pela API, conta as senhas erradas seguidas. Na 5ª a conta fica **bloqueada por 15 minutos**; durante o bloqueio nem a senha certa entra. O bloqueio vai para o log de auditoria.
- Um login certo zera o contador, e redefinir a senha pelo link de recuperação desbloqueia a conta.
- Cada endereço IP pode tentar login ou recuperação de senha **10 vezes por minuto**; depois disso recebe 429 (*Too Many Requests*).
- Os valores ficam em `Seguranca` no `appsettings.json`.
- Novas colunas `TentativasFalhas` e `BloqueadoAte` na tabela `Usuario`.

**Como conferir:** erre a senha de `tatico@modamax.com` cinco vezes; a tela mostra "Conta bloqueada temporariamente".

## 7. Erros padronizados na API e logs estruturados

- Todos os erros da API seguem o padrão **Problem Details** (RFC 9457): `title`, `status`, `detail` e `traceId`, com content-type `application/problem+json`. Antes cada endpoint respondia de um jeito (`{ "mensagem": ... }` ou corpo vazio).
- As mensagens de validação passaram para o português, e o app lê o campo `detail`.
- Os logs usam **Serilog**: cada evento guarda seus dados em campos separados, como "Pedido {IdPedido} criado, total {ValorTotal}". Em produção saem em JSON, prontos para o Application Insights. Há também uma linha por requisição com método, caminho, status e tempo. O e-mail digitado em logins recusados não vai para o log (LGPD).
- Arquivos: `Infraestrutura/ErrosApi.cs`, `Infraestrutura/LimiteRequisicoes.cs`, `Program.cs`.

## 8. Testes com SQL Server real

O projeto `tests/ModaMax.IntegrationTests` usa **Testcontainers** para subir um SQL Server 2022 em Docker, aplicar as migrations e testar o que o SQLite não tem:

- as três procedures (inclusive o erro 50001 da quantidade zero);
- os dois triggers de auditoria;
- a restrição `CHECK` de estoque;
- o índice único do código de barras;
- as transações do `PedidoService`.

Sem Docker os testes aparecem como ignorados; no CI eles são obrigatórios. Ao todo, o projeto tem 72 testes (62 + 10).

## 9. Fotos e código de barras dos produtos

- **Foto:** JPG, PNG ou WebP de até 2 MB. O tipo é conferido pelos primeiros bytes do arquivo, e não pela extensão, e o arquivo é gravado com nome aleatório. Aparece na listagem, nos detalhes e no app.
- **Código de barras:** EAN-8, UPC-A, EAN-13 ou GTIN-14, validado pelo dígito verificador e único por produto. Os produtos de demonstração já têm códigos (ex.: `7891234500014`).
- O armazenamento usa a interface `IArmazenamentoFotos`: hoje grava em disco (volume `fotos-produtos` no Docker); na nuvem, basta uma implementação com Azure Blob Storage.
- **API:** `GET /api/produtos/codigo/{codigo}` e `POST /api/produtos/{id}/foto`.
- **Correções encontradas no caminho:**
  - o cadastro deixava digitar o ID do produto, o que falhava no SQL Server;
  - a edição apagaria a foto ao salvar sem enviar outra;
  - o campo de preço não aceitava vírgula no navegador, embora o sistema mostre "189,90".
- Migration `FotosCodigoBarrasBloqueioLogin`.

## 10. Leitor de código de barras no app

- Na aba **Produtos**, o botão "Ler código de barras" abre a câmera (pacote `mobile_scanner`). O produto lido aparece numa ficha com foto, preço e estoque. Gerência e diretoria registram a **entrada de mercadoria** ali mesmo, pela procedure `sp_RegistrarEntradaEstoque`.
- No **Novo pedido**, ler a etiqueta coloca a peça no carrinho; ler de novo aumenta a quantidade.
- Leituras parciais são descartadas pelo dígito verificador, e o código também pode ser digitado: ajuda quem não consegue mirar a câmera e funciona no emulador.
- No iOS é preciso adicionar `NSCameraUsageDescription` ao `Info.plist` depois do `flutter create`.

## 11. Exportação de relatórios em PDF e Excel

- A tela de relatórios ganhou indicadores do período (pedidos, peças, faturamento e ticket médio) e os botões **Exportar PDF** e **Exportar Excel**, que respeitam o filtro de datas.
- O **Excel** (ClosedXML) tem as abas Resumo, Mais vendidos e Vendas por dia, com filtros e formato de moeda.
- O **PDF** (QuestPDF) tem cabeçalho, quadro-resumo, tabelas e número de página.
- **Correção:** as vendas por período eram ordenadas pelo texto "dd/MM/yyyy", o que misturava os meses. Agora a ordem é pela data. Datas invertidas no filtro são trocadas.

## 12. VLibras e ajustes de layout

- O tradutor oficial de LIBRAS do Governo Federal (**VLibras**) aparece em todas as páginas, no botão azul à direita. Era uma proposta do PIM III.
- O painel mostra os cinco indicadores na mesma linha. Antes o faturamento ficava sozinho embaixo, e o menu cabe em uma linha só em telas de notebook.
- O contêiner Docker passou a rodar com usuário sem privilégios de root.
- Um pacote indireto com vulnerabilidade alta (`System.Security.Cryptography.Pkcs`) foi fixado na versão corrigida.
