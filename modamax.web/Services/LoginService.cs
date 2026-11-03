using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using ModaMax.Web.Data;
using modamax.web.Models;

namespace modamax.web.Services;

public enum SituacaoLogin
{
    Sucesso,
    Invalido,
    Bloqueado
}

public record ResultadoLogin(SituacaoLogin Situacao, Usuario? Usuario = null, DateTime? BloqueadoAte = null);

public class SegurancaOptions
{
    public int MaxTentativasLogin { get; set; } = 5;

    public int MinutosBloqueio { get; set; } = 15;

    // Limite de tentativas de login e de recuperacao de senha por endereco IP a cada minuto.
    public int LimiteRequisicoesPorMinuto { get; set; } = 10;
}

// Autenticacao usada pela Web e pela API, com bloqueio temporario da conta
// depois de varias senhas erradas seguidas (protecao contra forca bruta).
public class LoginService
{
    private readonly AppDbContext _context;
    private readonly SegurancaOptions _opcoes;
    private readonly ILogger<LoginService> _logger;

    public LoginService(AppDbContext context, SegurancaOptions opcoes, ILogger<LoginService>? logger = null)
    {
        _context = context;
        _opcoes = opcoes;
        _logger = logger ?? NullLogger<LoginService>.Instance;
    }

    public async Task<ResultadoLogin> AutenticarAsync(string email, string senha)
    {
        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Email == email);
        if (usuario == null)
        {
            // O e-mail digitado nao vai para o log: pode ser um dado pessoal de outra pessoa (LGPD).
            _logger.LogWarning("Login recusado: e-mail nao cadastrado");
            return new ResultadoLogin(SituacaoLogin.Invalido);
        }

        var agora = DateTime.UtcNow;

        // Durante o bloqueio a senha nem e conferida: assim quem tenta adivinhar nao ganha informacao.
        if (usuario.BloqueadoAte > agora)
        {
            _logger.LogWarning("Login recusado: conta {IdUsuario} bloqueada ate {BloqueadoAte}", usuario.IdUsuario, usuario.BloqueadoAte);
            return new ResultadoLogin(SituacaoLogin.Bloqueado, BloqueadoAte: usuario.BloqueadoAte);
        }

        if (!SenhaService.Verificar(usuario, senha))
        {
            usuario.TentativasFalhas++;
            if (usuario.TentativasFalhas >= _opcoes.MaxTentativasLogin)
            {
                usuario.TentativasFalhas = 0;
                usuario.BloqueadoAte = agora.AddMinutes(_opcoes.MinutosBloqueio);
                _context.LogsSistema.Add(new LogSistema
                {
                    IdUsuario = usuario.IdUsuario,
                    Acao = $"Conta {usuario.Email} bloqueada por {_opcoes.MinutosBloqueio} minutos apos {_opcoes.MaxTentativasLogin} senhas erradas.",
                    Data = DateTime.Now
                });
                await _context.SaveChangesAsync();

                _logger.LogWarning("Conta {IdUsuario} bloqueada apos {Tentativas} senhas erradas", usuario.IdUsuario, _opcoes.MaxTentativasLogin);
                return new ResultadoLogin(SituacaoLogin.Bloqueado, BloqueadoAte: usuario.BloqueadoAte);
            }

            await _context.SaveChangesAsync();
            _logger.LogWarning("Senha errada para a conta {IdUsuario} ({Tentativas} de {Maximo})",
                usuario.IdUsuario, usuario.TentativasFalhas, _opcoes.MaxTentativasLogin);
            return new ResultadoLogin(SituacaoLogin.Invalido);
        }

        if (usuario.TentativasFalhas != 0 || usuario.BloqueadoAte != null)
        {
            usuario.TentativasFalhas = 0;
            usuario.BloqueadoAte = null;
            await _context.SaveChangesAsync();
        }

        _logger.LogInformation("Login da conta {IdUsuario} ({Nivel})", usuario.IdUsuario, usuario.Nivel);
        return new ResultadoLogin(SituacaoLogin.Sucesso, usuario);
    }

    public static string MensagemBloqueio(SegurancaOptions opcoes) =>
        $"Conta bloqueada temporariamente por excesso de tentativas. Tente novamente em {opcoes.MinutosBloqueio} minutos ou redefina a senha.";
}
