using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;

namespace ModaMax.Tests;

// Sobe a aplicacao inteira em memoria, com SQLite no lugar do SQL Server.
public sealed class ModaMaxFactory : WebApplicationFactory<Program>
{
    private readonly string _banco = $"Data Source=testes-{Guid.NewGuid():N};Mode=Memory;Cache=Shared";
    private readonly SqliteConnection _conexaoAberta;
    private readonly int _limiteRequisicoes;

    public string PastaFotos { get; } = Path.Combine(Path.GetTempPath(), $"modamax-testes-fotos-{Guid.NewGuid():N}");

    // Os testes fazem muitos logins seguidos; o limite por IP so e baixo no teste que o verifica.
    // (O xUnit exige um unico construtor publico nas fixtures.)
    public ModaMaxFactory() : this(limiteRequisicoes: 1000)
    {
    }

    public static ModaMaxFactory ComLimiteDeRequisicoes(int limite) => new(limite);

    private ModaMaxFactory(int limiteRequisicoes)
    {
        _limiteRequisicoes = limiteRequisicoes;
        // Mantem o banco em memoria vivo enquanto a fabrica existir.
        _conexaoAberta = new SqliteConnection(_banco);
        _conexaoAberta.Open();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("Database:Provider", "Sqlite");
        builder.UseSetting("ConnectionStrings:DefaultConnection", _banco);
        builder.UseSetting("Jwt:Key", "chave-de-teste-com-mais-de-32-caracteres-modamax");
        builder.UseSetting("Seguranca:LimiteRequisicoesPorMinuto", _limiteRequisicoes.ToString());
        builder.UseSetting("Fotos:Pasta", PastaFotos);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (!disposing) return;
        _conexaoAberta.Dispose();
        if (Directory.Exists(PastaFotos)) Directory.Delete(PastaFotos, recursive: true);
    }
}

public class ApiTests : IClassFixture<ModaMaxFactory>
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly ModaMaxFactory _factory;

    public ApiTests(ModaMaxFactory factory)
    {
        _factory = factory;
    }

    private async Task<HttpClient> ClienteLogadoAsync(string email)
    {
        var cliente = _factory.CreateClient();
        var resposta = await cliente.PostAsJsonAsync("/api/auth/login", new { email, senha = "123456" });
        resposta.EnsureSuccessStatusCode();
        var corpo = await resposta.Content.ReadFromJsonAsync<JsonElement>(Json);
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", corpo.GetProperty("token").GetString());
        return cliente;
    }

    [Fact]
    public async Task Login_com_senha_errada_retorna_401()
    {
        var resposta = await _factory.CreateClient().PostAsJsonAsync("/api/auth/login", new { email = "tatico@modamax.com", senha = "errada" });
        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    [Fact]
    public async Task Endpoints_protegidos_exigem_token()
    {
        var resposta = await _factory.CreateClient().GetAsync("/api/produtos");
        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    [Theory]
    [InlineData("jeans")]
    [InlineData("JEANS")]
    [InlineData("JeAnS")]
    public async Task Busca_de_produtos_e_clientes_ignora_maiusculas(string termo)
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var produtos = await cliente.GetFromJsonAsync<JsonElement[]>($"/api/produtos?busca={termo}", Json);
        Assert.NotEmpty(produtos!);
        Assert.All(produtos!, p => Assert.Contains("jeans", p.GetProperty("nome").GetString()!, StringComparison.OrdinalIgnoreCase));

        var clientes = await cliente.GetFromJsonAsync<JsonElement[]>("/api/clientes?busca=AMANDA", Json);
        Assert.Contains(clientes!, c => c.GetProperty("nome").GetString() == "Amanda da Silva");
    }

    [Fact]
    public async Task Busca_trata_caracteres_do_like_como_texto()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var produtos = await cliente.GetFromJsonAsync<JsonElement[]>("/api/produtos?busca=%25", Json);
        Assert.Empty(produtos!); // "%" nao vira curinga que traz tudo
    }

    private static async Task<int> CriarPedidoAsync(HttpClient cliente)
    {
        var produtos = await cliente.GetFromJsonAsync<JsonElement[]>("/api/produtos?somenteDisponiveis=true", Json);
        var clientes = await cliente.GetFromJsonAsync<JsonElement[]>("/api/clientes", Json);
        var resposta = await cliente.PostAsJsonAsync("/api/pedidos", new
        {
            idCliente = clientes![0].GetProperty("idCliente").GetInt32(),
            tiposVenda = "Varejo",
            itens = new[] { new { idProduto = produtos![0].GetProperty("idProduto").GetInt32(), quantidade = 1, desconto = 0 } }
        });
        resposta.EnsureSuccessStatusCode();
        return (await resposta.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("idPedido").GetInt32();
    }

    private static async Task<string> StatusDoPedidoAsync(HttpClient cliente, int id) =>
        (await cliente.GetFromJsonAsync<JsonElement>($"/api/pedidos/{id}", Json)).GetProperty("status").GetString()!;

    [Fact]
    public async Task Vendas_finaliza_o_pedido_e_pode_voltar_para_em_separacao()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var id = await CriarPedidoAsync(cliente);
        Assert.Equal("Em separação", await StatusDoPedidoAsync(cliente, id));

        var resposta = await cliente.PutAsJsonAsync($"/api/pedidos/{id}/status", new { status = "Finalizado" });
        Assert.Equal(HttpStatusCode.NoContent, resposta.StatusCode);
        Assert.Equal("Finalizado", await StatusDoPedidoAsync(cliente, id));

        resposta = await cliente.PutAsJsonAsync($"/api/pedidos/{id}/status", new { status = "Em separação" });
        Assert.Equal(HttpStatusCode.NoContent, resposta.StatusCode);
        Assert.Equal("Em separação", await StatusDoPedidoAsync(cliente, id));
    }

    [Fact]
    public async Task Status_invalido_ou_repetido_retorna_400()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var id = await CriarPedidoAsync(cliente);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await cliente.PutAsJsonAsync($"/api/pedidos/{id}/status", new { status = "Enviado" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await cliente.PutAsJsonAsync($"/api/pedidos/{id}/status", new { status = "Em separação" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await cliente.PutAsJsonAsync("/api/pedidos/999999/status", new { status = "Finalizado" })).StatusCode);
    }

    [Fact]
    public async Task Cancelar_pelo_status_exige_gerencia_e_pedido_cancelado_nao_volta()
    {
        var vendas = await ClienteLogadoAsync("operacional@modamax.com");
        var id = await CriarPedidoAsync(vendas);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await vendas.PutAsJsonAsync($"/api/pedidos/{id}/status", new { status = "Cancelado" })).StatusCode);

        var gerencia = await ClienteLogadoAsync("tatico@modamax.com");
        Assert.Equal(HttpStatusCode.NoContent,
            (await gerencia.PutAsJsonAsync($"/api/pedidos/{id}/status", new { status = "Cancelado" })).StatusCode);
        Assert.Equal("Cancelado", await StatusDoPedidoAsync(gerencia, id));

        var resposta = await gerencia.PutAsJsonAsync($"/api/pedidos/{id}/status", new { status = "Finalizado" });
        Assert.Equal(HttpStatusCode.BadRequest, resposta.StatusCode);
        Assert.Contains("cancelado", (await resposta.Content.ReadAsStringAsync()).ToLowerInvariant());
    }

    [Fact]
    public async Task Criar_pedido_pela_api_baixa_o_estoque()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var produtos = await cliente.GetFromJsonAsync<JsonElement[]>("/api/produtos?somenteDisponiveis=true", Json);
        var produto = produtos![0];
        var idProduto = produto.GetProperty("idProduto").GetInt32();
        var estoqueAntes = produto.GetProperty("estoque").GetInt32();
        var clientes = await cliente.GetFromJsonAsync<JsonElement[]>("/api/clientes", Json);

        var resposta = await cliente.PostAsJsonAsync("/api/pedidos", new
        {
            idCliente = clientes![0].GetProperty("idCliente").GetInt32(),
            tiposVenda = "Varejo",
            itens = new[] { new { idProduto, quantidade = 2, desconto = 0 } }
        });

        Assert.Equal(HttpStatusCode.Created, resposta.StatusCode);
        var depois = await cliente.GetFromJsonAsync<JsonElement>($"/api/produtos/{idProduto}", Json);
        Assert.Equal(estoqueAntes - 2, depois.GetProperty("estoque").GetInt32());
    }

    [Fact]
    public async Task Pedido_com_estoque_insuficiente_retorna_400_com_mensagem()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var produtos = await cliente.GetFromJsonAsync<JsonElement[]>("/api/produtos", Json);
        var clientes = await cliente.GetFromJsonAsync<JsonElement[]>("/api/clientes", Json);

        var resposta = await cliente.PostAsJsonAsync("/api/pedidos", new
        {
            idCliente = clientes![0].GetProperty("idCliente").GetInt32(),
            tiposVenda = "Varejo",
            itens = new[] { new { idProduto = produtos![0].GetProperty("idProduto").GetInt32(), quantidade = 100000, desconto = 0 } }
        });

        Assert.Equal(HttpStatusCode.BadRequest, resposta.StatusCode);
        Assert.Equal("application/problem+json", resposta.Content.Headers.ContentType?.MediaType);
        var corpo = await resposta.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Contains("Estoque insuficiente", corpo.GetProperty("detail").GetString());
        Assert.Equal(400, corpo.GetProperty("status").GetInt32());
    }

    [Fact]
    public async Task Erros_da_api_seguem_o_padrao_problem_details()
    {
        var semToken = await _factory.CreateClient().GetAsync("/api/produtos");
        Assert.Equal("application/problem+json", semToken.Content.Headers.ContentType?.MediaType);

        var cliente = await ClienteLogadoAsync("tatico@modamax.com");
        var inexistente = await cliente.GetAsync("/api/produtos/999999");
        Assert.Equal(HttpStatusCode.NotFound, inexistente.StatusCode);
        var corpo = await inexistente.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Equal("Recurso nao encontrado.", corpo.GetProperty("title").GetString());
        Assert.True(corpo.TryGetProperty("traceId", out _));
    }

    [Fact]
    public async Task Validacao_da_api_explica_o_erro_em_portugues()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var resposta = await cliente.PostAsJsonAsync("/api/pedidos", new { idCliente = 1, tiposVenda = "Varejo", itens = Array.Empty<object>() });

        Assert.Equal(HttpStatusCode.BadRequest, resposta.StatusCode);
        var corpo = await resposta.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Equal("Dados invalidos.", corpo.GetProperty("title").GetString());
        Assert.Equal("O pedido precisa ter ao menos um item.", corpo.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task Produto_e_encontrado_pelo_codigo_de_barras()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");

        var produto = await cliente.GetFromJsonAsync<JsonElement>("/api/produtos/codigo/7891234500014", Json);
        Assert.Equal("Macaquinho Jeans", produto.GetProperty("nome").GetString());

        var desconhecido = await cliente.GetAsync("/api/produtos/codigo/4006381333931");
        Assert.Equal(HttpStatusCode.NotFound, desconhecido.StatusCode);

        var invalido = await cliente.GetAsync("/api/produtos/codigo/4006381333932");
        Assert.Equal(HttpStatusCode.BadRequest, invalido.StatusCode);
    }

    [Fact]
    public async Task Foto_enviada_pela_api_fica_disponivel_no_endereco_devolvido()
    {
        var png = new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D, 1, 2, 3 };
        MultipartFormDataContent Formulario()
        {
            var conteudo = new ByteArrayContent(png);
            conteudo.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            return new MultipartFormDataContent { { conteudo, "foto", "camisa.png" } };
        }

        var operacional = await ClienteLogadoAsync("operacional@modamax.com");
        Assert.Equal(HttpStatusCode.Forbidden, (await operacional.PostAsync("/api/produtos/2/foto", Formulario())).StatusCode);

        var tatico = await ClienteLogadoAsync("tatico@modamax.com");
        var resposta = await tatico.PostAsync("/api/produtos/2/foto", Formulario());
        resposta.EnsureSuccessStatusCode();
        var fotoUrl = (await resposta.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("fotoUrl").GetString();

        Assert.StartsWith("/uploads/produtos/", fotoUrl);
        Assert.Equal(png, await _factory.CreateClient().GetByteArrayAsync(fotoUrl));
    }

    [Fact]
    public async Task Operacional_nao_pode_cancelar_pedido_mas_estrategico_pode()
    {
        var operacional = await ClienteLogadoAsync("operacional@modamax.com");
        var pedidos = await operacional.GetFromJsonAsync<JsonElement[]>("/api/pedidos?status=Finalizado", Json);
        var idPedido = pedidos![0].GetProperty("idPedido").GetInt32();

        var negado = await operacional.PutAsync($"/api/pedidos/{idPedido}/cancelar", null);
        Assert.Equal(HttpStatusCode.Forbidden, negado.StatusCode);

        var estrategico = await ClienteLogadoAsync("estrategico@modamax.com");
        var permitido = await estrategico.PutAsync($"/api/pedidos/{idPedido}/cancelar", null);
        Assert.Equal(HttpStatusCode.NoContent, permitido.StatusCode);
    }

    [Fact]
    public async Task Graficos_do_dashboard_trazem_seis_meses()
    {
        var cliente = await ClienteLogadoAsync("tatico@modamax.com");
        var graficos = await cliente.GetFromJsonAsync<JsonElement>("/api/dashboard/graficos", Json);

        Assert.Equal(6, graficos.GetProperty("vendasPorMes").GetArrayLength());
        Assert.True(graficos.GetProperty("produtosMaisVendidos").GetArrayLength() > 0);
    }

    [Theory]
    [InlineData("/health")]
    [InlineData("/Account/Login")]
    [InlineData("/Account/RecuperarSenha")]
    [InlineData("/openapi/v1.json")]
    public async Task Paginas_publicas_respondem(string caminho)
    {
        var resposta = await _factory.CreateClient().GetAsync(caminho);
        Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
    }

    [Fact]
    public async Task Link_de_redefinicao_invalido_mostra_aviso()
    {
        var html = await _factory.CreateClient().GetStringAsync("/Account/RedefinirSenha?token=inventado");
        Assert.Contains("Link inválido ou expirado", html);
    }

    [Fact]
    public async Task Pedido_com_cartao_parcelado_e_pagamento_pela_api()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var clientes = await cliente.GetFromJsonAsync<JsonElement[]>("/api/clientes", Json);
        object Pedido(string forma, int parcelas) => new
        {
            idCliente = clientes![0].GetProperty("idCliente").GetInt32(),
            tiposVenda = "Varejo",
            formaPagamento = forma,
            parcelas,
            itens = new[] { new { idProduto = 1, quantidade = 1, desconto = 0 } }
        };

        var invalido = await cliente.PostAsJsonAsync("/api/pedidos", Pedido("Pix", 3));
        Assert.Equal(HttpStatusCode.BadRequest, invalido.StatusCode);
        Assert.Contains("parcelado", (await invalido.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("detail").GetString());

        var criado = await cliente.PostAsJsonAsync("/api/pedidos", Pedido("Credito", 3));
        Assert.Equal(HttpStatusCode.Created, criado.StatusCode);
        var pedido = await criado.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Equal("Credito", pedido.GetProperty("formaPagamento").GetString());
        Assert.Equal(3, pedido.GetProperty("parcelas").GetInt32());
        Assert.Equal("Pendente", pedido.GetProperty("statusPagamento").GetString());
        var id = pedido.GetProperty("idPedido").GetInt32();

        Assert.Equal(HttpStatusCode.NoContent, (await cliente.PutAsync($"/api/pedidos/{id}/pagamento", null)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await cliente.PutAsync($"/api/pedidos/{id}/pagamento", null)).StatusCode);
        // Depois de pago, nao ha PIX a gerar.
        Assert.Equal(HttpStatusCode.Conflict, (await cliente.GetAsync($"/api/pedidos/{id}/pix")).StatusCode);
    }

    [Fact]
    public async Task Pix_copia_e_cola_do_pedido_pendente()
    {
        var cliente = await ClienteLogadoAsync("operacional@modamax.com");
        var clientes = await cliente.GetFromJsonAsync<JsonElement[]>("/api/clientes", Json);
        var criado = await cliente.PostAsJsonAsync("/api/pedidos", new
        {
            idCliente = clientes![0].GetProperty("idCliente").GetInt32(),
            tiposVenda = "Varejo",
            itens = new[] { new { idProduto = 2, quantidade = 1, desconto = 0 } }
        });
        var id = (await criado.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("idPedido").GetInt32();

        var pix = await cliente.GetFromJsonAsync<JsonElement>($"/api/pedidos/{id}/pix", Json);
        var copiaECola = pix.GetProperty("copiaECola").GetString()!;
        Assert.StartsWith("000201", copiaECola);
        Assert.Contains($"PEDIDO{id}", copiaECola);
    }

    [Fact]
    public async Task Metas_e_reposicao_pela_api()
    {
        var cliente = await ClienteLogadoAsync("tatico@modamax.com");

        var meta = await cliente.GetFromJsonAsync<JsonElement>("/api/metas/atual", Json);
        Assert.True(meta.GetProperty("faturamento").GetProperty("meta").GetDecimal() > 0);
        Assert.True(meta.TryGetProperty("projecaoFaturamento", out _));

        var reposicao = await cliente.GetFromJsonAsync<JsonElement[]>("/api/reposicao", Json);
        var produtos = await cliente.GetFromJsonAsync<JsonElement[]>("/api/produtos", Json);
        Assert.Equal(produtos!.Length, reposicao!.Length);
        Assert.Contains(reposicao, r => r.GetProperty("situacao").GetString() == "Critico");
    }

    [Fact]
    public async Task Metas_de_qualquer_mes_trazem_detalhes_e_historico()
    {
        var cliente = await ClienteLogadoAsync("tatico@modamax.com");
        var hoje = DateTime.Today;

        var atual = await cliente.GetFromJsonAsync<JsonElement>("/api/metas", Json);
        Assert.Equal("atual", atual.GetProperty("situacao").GetString());
        Assert.Equal(DateTime.DaysInMonth(hoje.Year, hoje.Month), atual.GetProperty("faturamentoPorDia").GetArrayLength());
        Assert.False(atual.GetProperty("podeEditar").GetBoolean());   // gerencia so consulta
        Assert.True(atual.TryGetProperty("mesAnterior", out _));

        var passado = hoje.AddMonths(-2);
        var encerrado = await cliente.GetFromJsonAsync<JsonElement>($"/api/metas?ano={passado.Year}&mes={passado.Month}", Json);
        Assert.Equal("encerrado", encerrado.GetProperty("situacao").GetString());
        Assert.Equal(0, encerrado.GetProperty("diasRestantes").GetInt32());

        var historico = await cliente.GetFromJsonAsync<JsonElement[]>("/api/metas/historico?meses=12", Json);
        Assert.Equal(12, historico!.Length);
        Assert.Equal(hoje.AddMonths(-1).Month, historico[^1].GetProperty("mes").GetInt32());

        Assert.Equal(HttpStatusCode.BadRequest, (await cliente.GetAsync("/api/metas?ano=2026&mes=13")).StatusCode);
    }

    [Fact]
    public async Task So_a_diretoria_edita_metas_e_mes_encerrado_nao_muda()
    {
        var hoje = DateTime.Today;
        var proximo = hoje.AddMonths(1);
        var meta = new { faturamento = 98765.43m, pedidos = 321, pecas = 654 };

        var gerente = await ClienteLogadoAsync("tatico@modamax.com");
        Assert.Equal(HttpStatusCode.Forbidden, (await gerente.PutAsJsonAsync($"/api/metas/{proximo.Year}/{proximo.Month}", meta)).StatusCode);

        var diretor = await ClienteLogadoAsync("estrategico@modamax.com");
        Assert.Equal(HttpStatusCode.NoContent, (await diretor.PutAsJsonAsync($"/api/metas/{proximo.Year}/{proximo.Month}", meta)).StatusCode);

        var salvo = await diretor.GetFromJsonAsync<JsonElement>($"/api/metas?ano={proximo.Year}&mes={proximo.Month}", Json);
        Assert.Equal("futuro", salvo.GetProperty("situacao").GetString());
        Assert.True(salvo.GetProperty("definida").GetBoolean());
        Assert.True(salvo.GetProperty("podeEditar").GetBoolean());
        Assert.Equal(98765.43m, salvo.GetProperty("faturamento").GetProperty("meta").GetDecimal());
        Assert.Equal(321, salvo.GetProperty("pedidos").GetProperty("meta").GetDecimal());

        var passado = hoje.AddMonths(-1);
        Assert.Equal(HttpStatusCode.BadRequest, (await diretor.PutAsJsonAsync($"/api/metas/{passado.Year}/{passado.Month}", meta)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await diretor.PutAsJsonAsync($"/api/metas/{proximo.Year}/{proximo.Month}", new { faturamento = 0, pedidos = 0, pecas = 0 })).StatusCode);
    }

    [Fact]
    public async Task Cadastro_completo_de_produto_pela_api_como_no_app()
    {
        var cliente = await ClienteLogadoAsync("estrategico@modamax.com");

        var categorias = await cliente.GetFromJsonAsync<JsonElement[]>("/api/categorias", Json);
        var fornecedores = await cliente.GetFromJsonAsync<JsonElement[]>("/api/fornecedores", Json);
        Assert.NotEmpty(fornecedores!);
        var produto = new
        {
            nome = "Camisa Jeans Teste",
            descricao = "Criada pelo app",
            tamanho = "M",
            cor = "Azul",
            preco = 129.90m,
            estoque = 12,
            idCategoria = categorias![0].GetProperty("idCategoria").GetInt32(),
            idFornecedor = fornecedores![0].GetProperty("idFornecedor").GetInt32(),
            codigoBarras = (string?)null
        };

        var criado = await cliente.PostAsJsonAsync("/api/produtos", produto);
        Assert.Equal(HttpStatusCode.Created, criado.StatusCode);
        var id = (await criado.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("idProduto").GetInt32();

        var alterado = await cliente.PutAsJsonAsync($"/api/produtos/{id}", produto with { preco = 99.90m, cor = "Preto" });
        Assert.Equal(HttpStatusCode.NoContent, alterado.StatusCode);
        var lido = await cliente.GetFromJsonAsync<JsonElement>($"/api/produtos/{id}", Json);
        Assert.Equal("Preto", lido.GetProperty("cor").GetString());
        Assert.Equal(99.90m, lido.GetProperty("preco").GetDecimal());

        Assert.Equal(HttpStatusCode.NoContent, (await cliente.DeleteAsync($"/api/produtos/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await cliente.GetAsync($"/api/produtos/{id}")).StatusCode);
    }

    [Fact]
    public async Task Excluir_cliente_pela_api_como_no_app()
    {
        var gerencia = await ClienteLogadoAsync("tatico@modamax.com");
        var criado = await gerencia.PostAsJsonAsync("/api/clientes", new
        {
            nome = "Cliente Para Excluir", tipo = "PF", documento = "12345678909", email = "excluir@teste.com"
        });
        Assert.Equal(HttpStatusCode.Created, criado.StatusCode);
        var id = (await criado.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("idCliente").GetInt32();

        // Vendedor nao exclui clientes.
        var vendedor = await ClienteLogadoAsync("operacional@modamax.com");
        Assert.Equal(HttpStatusCode.Forbidden, (await vendedor.DeleteAsync($"/api/clientes/{id}")).StatusCode);

        // Cliente com pedido fica protegido, para nao apagar o historico de vendas.
        var produtos = await gerencia.GetFromJsonAsync<JsonElement[]>("/api/produtos", Json);
        var pedido = await gerencia.PostAsJsonAsync("/api/pedidos", new
        {
            idCliente = id,
            tiposVenda = "Varejo",
            itens = new[] { new { idProduto = produtos![0].GetProperty("idProduto").GetInt32(), quantidade = 1, desconto = 0 } }
        });
        Assert.Equal(HttpStatusCode.Created, pedido.StatusCode);
        var recusado = await gerencia.DeleteAsync($"/api/clientes/{id}");
        Assert.Equal(HttpStatusCode.Conflict, recusado.StatusCode);
        Assert.Contains("pedidos", (await recusado.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("detail").GetString());

        // Sem pedidos, a exclusao funciona.
        var outro = await gerencia.PostAsJsonAsync("/api/clientes", new
        {
            nome = "Cliente Sem Pedidos", tipo = "PF", documento = "98765432100", email = "sempedidos@teste.com"
        });
        var idOutro = (await outro.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("idCliente").GetInt32();
        Assert.Equal(HttpStatusCode.NoContent, (await gerencia.DeleteAsync($"/api/clientes/{idOutro}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await gerencia.GetAsync($"/api/clientes/{idOutro}")).StatusCode);
    }

    [Fact]
    public async Task Entrada_de_estoque_pela_api_funciona_no_modo_sqlite()
    {
        var cliente = await ClienteLogadoAsync("tatico@modamax.com");
        var antes = (await cliente.GetFromJsonAsync<JsonElement>("/api/produtos/6", Json)).GetProperty("estoque").GetInt32();

        var resposta = await cliente.PostAsJsonAsync("/api/produtos/6/entrada-estoque", new { quantidade = 9, observacao = "Teste" });

        resposta.EnsureSuccessStatusCode();
        Assert.Equal(antes + 9, (await resposta.Content.ReadFromJsonAsync<JsonElement>(Json)).GetProperty("estoque").GetInt32());
    }

    [Theory]
    [InlineData("/manifest.webmanifest")]
    [InlineData("/sw.js")]
    [InlineData("/offline.html")]
    [InlineData("/img/icones.svg")]
    [InlineData("/lib/chartjs/chart.umd.min.js")]
    public async Task Arquivos_do_app_instalavel_e_do_design_sao_servidos(string caminho)
    {
        var resposta = await _factory.CreateClient().GetAsync(caminho);
        Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
    }
}
