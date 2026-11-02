using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.Controllers;

[RequireUser("Estrategico")]
public class UsuarioController : Controller
{
    private readonly AppDbContext _context;

    public UsuarioController(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IActionResult> Index()
    {
        return View(await _context.Usuarios.OrderBy(u => u.Nome).ToListAsync());
    }

    public async Task<IActionResult> Details(int? id)
    {
        if (id == null) return NotFound();
        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.IdUsuario == id);
        return usuario == null ? NotFound() : View(usuario);
    }

    public IActionResult Create()
    {
        return View(new Usuario());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create([Bind("Nome,Email,Senha,Nivel")] Usuario usuario)
    {
        if (!ModelState.IsValid) return View(usuario);
        usuario.Senha = SenhaService.GerarHash(usuario, usuario.Senha);
        _context.Usuarios.Add(usuario);
        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Usuario cadastrado: {usuario.Email}.");
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int? id)
    {
        if (id == null) return NotFound();
        var usuario = await _context.Usuarios.FindAsync(id);
        return usuario == null ? NotFound() : View(usuario);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, [Bind("IdUsuario,Nome,Email,Senha,Nivel")] Usuario usuario)
    {
        if (id != usuario.IdUsuario) return NotFound();

        // Senha em branco na edicao significa "manter a senha atual".
        ModelState.Remove(nameof(Usuario.Senha));
        if (!ModelState.IsValid) return View(usuario);

        var existente = await _context.Usuarios.FindAsync(id);
        if (existente == null) return NotFound();

        existente.Nome = usuario.Nome;
        existente.Email = usuario.Email;
        existente.Nivel = usuario.Nivel;
        if (!string.IsNullOrWhiteSpace(usuario.Senha))
        {
            existente.Senha = SenhaService.GerarHash(existente, usuario.Senha);
        }

        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Usuario alterado: {usuario.Email}.");
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Delete(int? id)
    {
        if (id == null) return NotFound();
        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.IdUsuario == id);
        return usuario == null ? NotFound() : View(usuario);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var usuario = await _context.Usuarios.FindAsync(id);
        if (usuario != null)
        {
            _context.Usuarios.Remove(usuario);
            await _context.SaveChangesAsync();
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Usuario removido: {usuario.Email}.");
        }

        return RedirectToAction(nameof(Index));
    }
}
