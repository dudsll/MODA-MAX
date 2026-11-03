using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using ModaMax.Web.Data;
using modamax.web.Dtos;
using modamax.web.Infraestrutura;
using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.Controllers.Api;

[ApiController]
[Route("api/auth")]
public class AuthApiController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly TokenService _tokenService;
    private readonly LoginService _loginService;
    private readonly SegurancaOptions _seguranca;

    public AuthApiController(AppDbContext context, TokenService tokenService, LoginService loginService, SegurancaOptions seguranca)
    {
        _context = context;
        _tokenService = tokenService;
        _loginService = loginService;
        _seguranca = seguranca;
    }

    // POST /api/auth/login
    // 401: e-mail ou senha errados · 423: conta bloqueada por tentativas · 429: muitas tentativas do mesmo IP
    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(LimiteRequisicoes.Login)]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request)
    {
        var resultado = await _loginService.AutenticarAsync(request.Email, request.Senha);
        if (resultado.Situacao == SituacaoLogin.Bloqueado)
        {
            return Problem(detail: LoginService.MensagemBloqueio(_seguranca), statusCode: StatusCodes.Status423Locked);
        }
        if (resultado.Situacao == SituacaoLogin.Invalido)
        {
            return Problem(detail: "Email ou senha invalidos.", statusCode: StatusCodes.Status401Unauthorized);
        }

        var usuario = resultado.Usuario!;
        var (token, expiraEm) = _tokenService.Gerar(usuario);

        _context.LogsSistema.Add(new LogSistema
        {
            IdUsuario = usuario.IdUsuario,
            Acao = $"Login pelo app mobile: {usuario.Email}.",
            Data = DateTime.Now
        });
        await _context.SaveChangesAsync();

        return new LoginResponse(token, expiraEm, usuario.IdUsuario, usuario.Nome, usuario.Email, usuario.Nivel);
    }
}
