using Microsoft.EntityFrameworkCore;
using modamax.web.Services;

namespace ModaMax.Tests;

public class RecuperacaoSenhaServiceTests : IDisposable
{
    private readonly BancoDeTeste _banco = new();

    public void Dispose() => _banco.Dispose();

    [Fact]
    public async Task Email_inexistente_nao_gera_token()
    {
        using var contexto = _banco.NovoContexto();
        Assert.Null(await new RecuperacaoSenhaService(contexto).GerarAsync("ninguem@teste.com"));
    }

    [Fact]
    public async Task Token_valido_troca_a_senha_e_so_pode_ser_usado_uma_vez()
    {
        using var contexto = _banco.NovoContexto();
        var servico = new RecuperacaoSenhaService(contexto);
        var (_, token) = (await servico.GerarAsync(_banco.Usuario.Email))!.Value;

        var usuario = await servico.RedefinirAsync(token, "senha-nova");

        Assert.NotNull(usuario);
        Assert.True(SenhaService.Verificar(usuario, "senha-nova"));
        Assert.False(SenhaService.Verificar(usuario, "senha-antiga"));
        Assert.Null(await servico.RedefinirAsync(token, "outra-senha"));
    }

    [Fact]
    public async Task Token_expirado_e_recusado()
    {
        using var contexto = _banco.NovoContexto();
        var servico = new RecuperacaoSenhaService(contexto);
        var (_, token) = (await servico.GerarAsync(_banco.Usuario.Email))!.Value;

        var registro = await contexto.RecuperacoesSenha.SingleAsync();
        registro.ExpiraEm = DateTime.UtcNow.AddMinutes(-1);
        await contexto.SaveChangesAsync();

        Assert.False(await servico.TokenValidoAsync(token));
        Assert.Null(await servico.RedefinirAsync(token, "senha-nova"));
    }

    [Fact]
    public async Task Novo_pedido_invalida_o_link_anterior()
    {
        using var contexto = _banco.NovoContexto();
        var servico = new RecuperacaoSenhaService(contexto);
        var (_, primeiro) = (await servico.GerarAsync(_banco.Usuario.Email))!.Value;
        var (_, segundo) = (await servico.GerarAsync(_banco.Usuario.Email))!.Value;

        Assert.False(await servico.TokenValidoAsync(primeiro));
        Assert.True(await servico.TokenValidoAsync(segundo));
    }

    [Fact]
    public async Task Banco_guarda_so_o_hash_do_token()
    {
        using var contexto = _banco.NovoContexto();
        var (_, token) = (await new RecuperacaoSenhaService(contexto).GerarAsync(_banco.Usuario.Email))!.Value;

        var registro = await contexto.RecuperacoesSenha.SingleAsync();
        Assert.NotEqual(token, registro.TokenHash);
        Assert.Equal(64, registro.TokenHash.Length);
    }

    [Fact]
    public async Task Token_vazio_ou_inventado_e_invalido()
    {
        using var contexto = _banco.NovoContexto();
        var servico = new RecuperacaoSenhaService(contexto);

        Assert.False(await servico.TokenValidoAsync(null));
        Assert.False(await servico.TokenValidoAsync("token-inventado"));
    }
}
