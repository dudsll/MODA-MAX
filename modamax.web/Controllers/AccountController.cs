using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.ViewModels;

namespace modamax.web.Controllers;

public class AccountController : Controller
{
    private readonly AppDbContext _context;

    public AccountController(AppDbContext context)
    {
        _context = context;
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
    public async Task<IActionResult> Login(LoginViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return View(viewModel);
        }

        var usuario = await _context.Usuarios
            .FirstOrDefaultAsync(u => u.Email == viewModel.Email && u.Senha == viewModel.Senha);

        if (usuario == null)
        {
            ModelState.AddModelError(string.Empty, "Email ou senha invalidos.");
            return View(viewModel);
        }

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
        return View(new ResetPasswordViewModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RecuperarSenha(ResetPasswordViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return View(viewModel);
        }

        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Email == viewModel.Email);
        if (usuario == null)
        {
            ModelState.AddModelError(string.Empty, "Usuario nao encontrado.");
            return View(viewModel);
        }

        usuario.Senha = viewModel.NovaSenha;
        await _context.SaveChangesAsync();
        TempData["Mensagem"] = "Senha atualizada com sucesso.";
        return RedirectToAction(nameof(Login));
    }

    public IActionResult AcessoNegado()
    {
        return View();
    }
}
