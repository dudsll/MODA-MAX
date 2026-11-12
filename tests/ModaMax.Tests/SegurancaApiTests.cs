using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace ModaMax.Tests;

// Cada teste sobe a aplicacao com um banco proprio: bloquear uma conta aqui nao afeta os outros testes.
public class SegurancaApiTests
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task Conta_e_bloqueada_apos_cinco_senhas_erradas()
    {
        using var factory = new ModaMaxFactory();
        var cliente = factory.CreateClient();

        for (var i = 1; i <= 4; i++)
        {
            var errada = await cliente.PostAsJsonAsync("/api/auth/login", new { email = "tatico@modamax.com", senha = "errada" });
            Assert.Equal(HttpStatusCode.Unauthorized, errada.StatusCode);
        }

        var quinta = await cliente.PostAsJsonAsync("/api/auth/login", new { email = "tatico@modamax.com", senha = "errada" });
        Assert.Equal((HttpStatusCode)423, quinta.StatusCode);
        var corpo = await quinta.Content.ReadFromJsonAsync<JsonElement>(Json);
        Assert.Contains("bloqueada temporariamente", corpo.GetProperty("detail").GetString());

        // A senha certa tambem e recusada enquanto durar o bloqueio.
        var certa = await cliente.PostAsJsonAsync("/api/auth/login", new { email = "tatico@modamax.com", senha = "123456" });
        Assert.Equal((HttpStatusCode)423, certa.StatusCode);
    }

    [Fact]
    public async Task Muitas_tentativas_do_mesmo_ip_recebem_429()
    {
        using var factory = ModaMaxFactory.ComLimiteDeRequisicoes(3);
        var cliente = factory.CreateClient();

        for (var i = 0; i < 3; i++)
        {
            await cliente.PostAsJsonAsync("/api/auth/login", new { email = "ninguem@modamax.com", senha = "x" });
        }

        var bloqueada = await cliente.PostAsJsonAsync("/api/auth/login", new { email = "estrategico@modamax.com", senha = "123456" });
        Assert.Equal(HttpStatusCode.TooManyRequests, bloqueada.StatusCode);
        Assert.Equal("application/problem+json", bloqueada.Content.Headers.ContentType?.MediaType);
        Assert.True(bloqueada.Headers.Contains("Retry-After"));
    }
}
