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

    public ModaMaxFactory()
    {
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
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing) _conexaoAberta.Dispose();
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
        var corpo = await resposta.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Contains("Estoque insuficiente", corpo.GetProperty("mensagem").GetString());
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
}
