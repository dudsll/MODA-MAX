using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Infraestrutura;
using modamax.web.Services;
using modamax.web.ViewModels;

namespace modamax.web.Controllers;

public class AccountController : Controller
{
    private readonly AppDbContext _context;
    private readonly RecuperacaoSenhaService _recuperacaoSenha;
    private readonly IEmailService _emailService;
    private readonly IWebHostEnvironment _environment;
    private readonly LoginService _loginService;
    private readonly SegurancaOptions _seguranca;

    public AccountController(
        AppDbContext context,
        RecuperacaoSenhaService recuperacaoSenha,
        IEmailService emailService,
        IWebHostEnvironment environment,
        LoginService loginService,
        SegurancaOptions seguranca)
    {
        _context = context;
        _recuperacaoSenha = recuperacaoSenha;
        _emailService = emailService;
        _environment = environment;
        _loginService = loginService;
        _seguranca = seguranca;
    }

    [HttpGet]
    public IActionResult Login()
    {
        if (HttpContext.Session.GetInt32("UsuarioId").HasValue)
        {
            return RedirectToAction("Index", "Home");
        }

        return View(new LoginViewModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting(LimiteRequisicoes.Login)]
    public async Task<IActionResult> Login(LoginViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return View(viewModel);
        }

        var resultado = await _loginService.AutenticarAsync(viewModel.Email, viewModel.Senha);
        if (resultado.Situacao != SituacaoLogin.Sucesso)
        {
            ModelState.AddModelError(string.Empty, resultado.Situacao == SituacaoLogin.Bloqueado
                ? LoginService.MensagemBloqueio(_seguranca)
                : "Email ou senha invalidos.");
            return View(viewModel);
        }

        var usuario = resultado.Usuario!;

        HttpContext.Session.SetInt32("UsuarioId", usuario.IdUsuario);
        HttpContext.Session.SetString("UsuarioNome", usuario.Nome);
        HttpContext.Session.SetString("UsuarioNivel", usuario.Nivel);

        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Login realizado por {usuario.Email}.");

        return RedirectToAction("Index", "Home");
    }

    public IActionResult Logout()
    {
        HttpContext.Session.Clear();
        return RedirectToAction(nameof(Login));
    }

    [HttpGet]
    public IActionResult RecuperarSenha()
    {
        return View(new EsqueciSenhaViewModel());
    }

    // Sempre mostra a mesma mensagem, exista ou nao o e-mail, para nao revelar quem tem conta.
    [HttpPost]
    [ValidateAntiForgeryToken]
    [EnableRateLimiting(LimiteRequisicoes.Login)]
    public async Task<IActionResult> RecuperarSenha(EsqueciSenhaViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return View(viewModel);
        }

        var gerado = await _recuperacaoSenha.GerarAsync(viewModel.Email);
        if (gerado != null)
        {
            var (usuario, token) = gerado.Value;
            var link = Url.Action(nameof(RedefinirSenha), "Account", new { token }, Request.Scheme)!;

            await _emailService.EnviarAsync(
                usuario.Email,
                "ModaMax - redefinicao de senha",
                $"""
                <p>Ola, {WebUtility.HtmlEncode(usuario.Nome)}.</p>
                <p>Recebemos um pedido para redefinir sua senha no ModaMax.
                Clique no link abaixo em ate {(int)RecuperacaoSenhaService.Validade.TotalMinutes} minutos:</p>
                <p><a href="{link}">Redefinir minha senha</a></p>
                <p>Se nao foi voce, ignore este e-mail. Sua senha atual continua valendo.</p>
                """);

            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Recuperacao de senha solicitada para {usuario.Email}.");

            // Sem SMTP em desenvolvimento, o link aparece na tela para facilitar testes e demonstracoes.
            if (!_emailService.EnviaDeVerdade && _environment.IsDevelopment())
            {
                TempData["LinkDesenvolvimento"] = link;
            }
        }

        TempData["Mensagem"] = "Se o e-mail estiver cadastrado, enviamos um link para redefinir a senha.";
        return RedirectToAction(nameof(RecuperarSenha));
    }

    [HttpGet]
    public async Task<IActionResult> RedefinirSenha(string? token)
    {
        if (!await _recuperacaoSenha.TokenValidoAsync(token))
        {
            return View("LinkInvalido");
        }

        return View(new RedefinirSenhaViewModel { Token = token! });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RedefinirSenha(RedefinirSenhaViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return View(viewModel);
        }

        var usuario = await _recuperacaoSenha.RedefinirAsync(viewModel.Token, viewModel.NovaSenha);
        if (usuario == null)
        {
            return View("LinkInvalido");
        }

        _context.LogsSistema.Add(new modamax.web.Models.LogSistema
        {
            IdUsuario = usuario.IdUsuario,
            Acao = $"Senha redefinida por link de recuperacao: {usuario.Email}.",
            Data = DateTime.Now
        });
        await _context.SaveChangesAsync();

        TempData["Mensagem"] = "Senha atualizada com sucesso. Entre com a nova senha.";
        return RedirectToAction(nameof(Login));
    }

    public IActionResult AcessoNegado()
    {
        return View();
    }
}
