using Microsoft.EntityFrameworkCore;
using modamax.web.Services;

namespace ModaMax.Tests;

public class LoginServiceTests : IDisposable
{
    private readonly BancoDeTeste _banco = new();
    private readonly SegurancaOptions _opcoes = new() { MaxTentativasLogin = 3, MinutosBloqueio = 15 };

    public void Dispose() => _banco.Dispose();

    private LoginService NovoServico(out ModaMax.Web.Data.AppDbContext contexto)
    {
        contexto = _banco.NovoContexto();
        return new LoginService(contexto, _opcoes);
    }

    [Fact]
    public async Task Senha_correta_autentica()
    {
        var servico = NovoServico(out var contexto);
        using (contexto)
        {
            var resultado = await servico.AutenticarAsync("usuario@teste.com", "senha-antiga");

            Assert.Equal(SituacaoLogin.Sucesso, resultado.Situacao);
            Assert.Equal(_banco.Usuario.IdUsuario, resultado.Usuario!.IdUsuario);
        }
    }

    [Fact]
    public async Task Email_inexistente_e_recusado_sem_bloquear_ninguem()
    {
        var servico = NovoServico(out var contexto);
        using (contexto)
        {
            for (var i = 0; i < 5; i++)
            {
                Assert.Equal(SituacaoLogin.Invalido, (await servico.AutenticarAsync("ninguem@teste.com", "x")).Situacao);
            }
        }

        using var verificacao = _banco.NovoContexto();
        Assert.Null(verificacao.Usuarios.AsNoTracking().Single().BloqueadoAte);
    }

    [Fact]
    public async Task Conta_e_bloqueada_apos_as_tentativas_erradas_e_recusa_ate_a_senha_certa()
    {
        var servico = NovoServico(out var contexto);
        using (contexto)
        {
            Assert.Equal(SituacaoLogin.Invalido, (await servico.AutenticarAsync("usuario@teste.com", "errada")).Situacao);
            Assert.Equal(SituacaoLogin.Invalido, (await servico.AutenticarAsync("usuario@teste.com", "errada")).Situacao);
            var terceira = await servico.AutenticarAsync("usuario@teste.com", "errada");

            Assert.Equal(SituacaoLogin.Bloqueado, terceira.Situacao);
            Assert.True(terceira.BloqueadoAte > DateTime.UtcNow.AddMinutes(14));

            // Durante o bloqueio, nem a senha certa entra.
            Assert.Equal(SituacaoLogin.Bloqueado, (await servico.AutenticarAsync("usuario@teste.com", "senha-antiga")).Situacao);
        }

        using var verificacao = _banco.NovoContexto();
        Assert.Contains(verificacao.LogsSistema, l => l.Acao.Contains("bloqueada"));
    }

    [Fact]
    public async Task Bloqueio_expirado_libera_o_login_e_zera_o_contador()
    {
        using (var preparo = _banco.NovoContexto())
        {
            var usuario = preparo.Usuarios.Single();
            usuario.BloqueadoAte = DateTime.UtcNow.AddMinutes(-1);
            usuario.TentativasFalhas = 2;
            preparo.SaveChanges();
        }

        var servico = NovoServico(out var contexto);
        using (contexto)
        {
            Assert.Equal(SituacaoLogin.Sucesso, (await servico.AutenticarAsync("usuario@teste.com", "senha-antiga")).Situacao);
        }

        using var verificacao = _banco.NovoContexto();
        var depois = verificacao.Usuarios.AsNoTracking().Single();
        Assert.Equal(0, depois.TentativasFalhas);
        Assert.Null(depois.BloqueadoAte);
    }

    [Fact]
    public async Task Login_certo_antes_do_limite_zera_as_falhas()
    {
        var servico = NovoServico(out var contexto);
        using (contexto)
        {
            await servico.AutenticarAsync("usuario@teste.com", "errada");
            await servico.AutenticarAsync("usuario@teste.com", "errada");
            await servico.AutenticarAsync("usuario@teste.com", "senha-antiga");
            // Depois do acerto, mais duas falhas ainda nao bloqueiam (limite e 3 seguidas).
            await servico.AutenticarAsync("usuario@teste.com", "errada");
            var resultado = await servico.AutenticarAsync("usuario@teste.com", "errada");

            Assert.Equal(SituacaoLogin.Invalido, resultado.Situacao);
        }
    }

    [Fact]
    public async Task Redefinir_a_senha_pelo_link_desbloqueia_a_conta()
    {
        using (var preparo = _banco.NovoContexto())
        {
            var usuario = preparo.Usuarios.Single();
            usuario.BloqueadoAte = DateTime.UtcNow.AddMinutes(10);
            preparo.SaveChanges();
        }

        using (var contexto = _banco.NovoContexto())
        {
            var recuperacao = new RecuperacaoSenhaService(contexto);
            var (_, token) = (await recuperacao.GerarAsync("usuario@teste.com"))!.Value;
            await recuperacao.RedefinirAsync(token, "senha-nova");
        }

        var servico = NovoServico(out var contextoLogin);
        using (contextoLogin)
        {
            Assert.Equal(SituacaoLogin.Sucesso, (await servico.AutenticarAsync("usuario@teste.com", "senha-nova")).Situacao);
        }
    }
}
