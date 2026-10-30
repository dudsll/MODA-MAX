using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Dtos;
using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.Controllers.Api;

[ApiController]
[Route("api/auth")]
public class AuthApiController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly TokenService _tokenService;

    public AuthApiController(AppDbContext context, TokenService tokenService)
    {
        _context = context;
        _tokenService = tokenService;
    }

    // POST /api/auth/login
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request)
    {
        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Email == request.Email);
        if (usuario == null || !SenhaService.Verificar(usuario, request.Senha))
        {
            return Unauthorized(new { mensagem = "Email ou senha invalidos." });
        }

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
