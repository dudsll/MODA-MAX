using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;

namespace modamax.web.Controllers;

[RequireUser("Estrategico", "Tatico")]
public class CategoriaController : Controller
{
    private readonly AppDbContext _context;

    public CategoriaController(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IActionResult> Index()
    {
        return View(await _context.Categorias.OrderBy(c => c.Nome).ToListAsync());
    }

    public async Task<IActionResult> Details(int? id)
    {
        if (id == null) return NotFound();
        var categoria = await _context.Categorias.FirstOrDefaultAsync(c => c.IdCategoria == id);
        return categoria == null ? NotFound() : View(categoria);
    }

    public IActionResult Create()
    {
        return View(new Categoria());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create([Bind("Nome")] Categoria categoria)
    {
        if (!ModelState.IsValid) return View(categoria);
        _context.Categorias.Add(categoria);
        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Categoria criada: {categoria.Nome}.");
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int? id)
    {
        if (id == null) return NotFound();
        var categoria = await _context.Categorias.FindAsync(id);
        return categoria == null ? NotFound() : View(categoria);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, [Bind("IdCategoria,Nome")] Categoria categoria)
    {
        if (id != categoria.IdCategoria) return NotFound();
        if (!ModelState.IsValid) return View(categoria);
        _context.Update(categoria);
        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Categoria alterada: {categoria.Nome}.");
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Delete(int? id)
    {
        if (id == null) return NotFound();
        var categoria = await _context.Categorias.FirstOrDefaultAsync(c => c.IdCategoria == id);
        return categoria == null ? NotFound() : View(categoria);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico")]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var categoria = await _context.Categorias.FindAsync(id);
        if (categoria != null)
        {
            _context.Categorias.Remove(categoria);
            await _context.SaveChangesAsync();
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Categoria removida: {categoria.Nome}.");
        }

        return RedirectToAction(nameof(Index));
    }
}
