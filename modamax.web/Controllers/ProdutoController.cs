using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;

namespace modamax.web.Controllers;

public class ProdutoController : Controller
{
    private readonly AppDbContext _context;

    public ProdutoController(AppDbContext context)
    {
        _context = context;
    }

    [RequireUser("Estrategico", "Tatico", "Operacional")]
    public async Task<IActionResult> Index(string? busca, int? categoriaId, string? tamanho, bool somenteDisponiveis = false)
    {
        var query = _context.Produtos
            .Include(p => p.Categoria)
            .Include(p => p.Fornecedor)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(busca))
        {
            query = query.Where(p =>
                p.Nome.Contains(busca) ||
                p.IdProduto.ToString().Contains(busca));
        }

        if (categoriaId.HasValue)
        {
            query = query.Where(p => p.IdCategoria == categoriaId.Value);
        }

        if (!string.IsNullOrWhiteSpace(tamanho))
        {
            query = query.Where(p => p.Tamanho == tamanho);
        }

        if (somenteDisponiveis)
        {
            query = query.Where(p => p.Estoque > 0);
        }

        ViewBag.Busca = busca;
        ViewBag.CategoriaId = categoriaId;
        ViewBag.Tamanho = tamanho;
        ViewBag.SomenteDisponiveis = somenteDisponiveis;
        ViewBag.CategoriasFiltro = new SelectList(await _context.Categorias.OrderBy(c => c.Nome).ToListAsync(), "IdCategoria", "Nome", categoriaId);

        var produtos = await query.OrderBy(p => p.Nome).ToListAsync();

        return View(produtos);
    }

    [RequireUser("Estrategico", "Tatico", "Operacional")]
    public async Task<IActionResult> Details(int? id)
    {
        if (id == null)
        {
            return NotFound();
        }

        var produto = await _context.Produtos
            .Include(p => p.Categoria)
            .Include(p => p.Fornecedor)
            .FirstOrDefaultAsync(m => m.IdProduto == id);

        if (produto == null)
        {
            return NotFound();
        }

        return View(produto);
    }

    [RequireUser("Estrategico", "Tatico")]
    public IActionResult Create()
    {
        CarregarCombos();
        return View(new Produto());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> Create([Bind("IdProduto,Nome,Descricao,Tamanho,Cor,Preco,Estoque,IdCategoria,IdFornecedor")] Produto produto)
    {
        if (!ModelState.IsValid)
        {
            CarregarCombos(produto.IdCategoria, produto.IdFornecedor);
            return View(produto);
        }

        _context.Add(produto);
        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Produto cadastrado: {produto.Nome}.");
        return RedirectToAction(nameof(Index));
    }

    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> Edit(int? id)
    {
        if (id == null)
        {
            return NotFound();
        }

        var produto = await _context.Produtos.FindAsync(id);
        if (produto == null)
        {
            return NotFound();
        }

        CarregarCombos(produto.IdCategoria, produto.IdFornecedor);
        return View(produto);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> Edit(int id, [Bind("IdProduto,Nome,Descricao,Tamanho,Cor,Preco,Estoque,IdCategoria,IdFornecedor")] Produto produto)
    {
        if (id != produto.IdProduto)
        {
            return NotFound();
        }

        if (!ModelState.IsValid)
        {
            CarregarCombos(produto.IdCategoria, produto.IdFornecedor);
            return View(produto);
        }

        try
        {
            _context.Update(produto);
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!ProdutoExists(produto.IdProduto))
            {
                return NotFound();
            }

            throw;
        }

        return RedirectToAction(nameof(Index));
    }

    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> Delete(int? id)
    {
        if (id == null)
        {
            return NotFound();
        }

        var produto = await _context.Produtos
            .Include(p => p.Categoria)
            .Include(p => p.Fornecedor)
            .FirstOrDefaultAsync(m => m.IdProduto == id);

        if (produto == null)
        {
            return NotFound();
        }

        return View(produto);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico")]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var produto = await _context.Produtos.FindAsync(id);
        if (produto != null)
        {
            _context.Produtos.Remove(produto);
            await _context.SaveChangesAsync();
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Produto removido: {produto.Nome}.");
        }

        return RedirectToAction(nameof(Index));
    }

    private bool ProdutoExists(int id)
    {
        return _context.Produtos.Any(e => e.IdProduto == id);
    }

    private void CarregarCombos(int? categoriaSelecionada = null, int? fornecedorSelecionado = null)
    {
        ViewBag.Categorias = new SelectList(_context.Categorias.OrderBy(c => c.Nome), "IdCategoria", "Nome", categoriaSelecionada);
        ViewBag.Fornecedores = new SelectList(_context.Fornecedores.OrderBy(f => f.Nome), "IdFornecedor", "Nome", fornecedorSelecionado);
    }
}
