using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;

namespace modamax.web.Controllers;

// Etiquetas com codigo de barras EAN-13 para imprimir e colar nas pecas (lidas pelo app).
[RequireUser("Estrategico", "Tatico", "Operacional")]
public class EtiquetaController : Controller
{
    private readonly AppDbContext _context;

    public EtiquetaController(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IActionResult> Index(int? categoriaId, int? idProduto, int copias = 1)
    {
        copias = Math.Clamp(copias, 1, 20);
        var consulta = _context.Produtos.AsNoTracking().Include(p => p.Categoria).AsQueryable();
        if (idProduto.HasValue)
        {
            consulta = consulta.Where(p => p.IdProduto == idProduto.Value);
        }
        else if (categoriaId.HasValue)
        {
            consulta = consulta.Where(p => p.IdCategoria == categoriaId.Value);
        }

        ViewBag.Categorias = new SelectList(await _context.Categorias.OrderBy(c => c.Nome).ToListAsync(), "IdCategoria", "Nome", categoriaId);
        ViewBag.CategoriaId = categoriaId;
        ViewBag.Copias = copias;
        var produtos = await consulta.OrderBy(p => p.Nome).ToListAsync();
        return View(produtos.SelectMany(p => Enumerable.Repeat(p, copias)).ToList());
    }
}
