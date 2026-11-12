using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.Controllers;

public class ProdutoController : Controller
{
    private const string CamposEditaveis = "Nome,Descricao,Tamanho,Cor,Preco,Estoque,IdCategoria,IdFornecedor,CodigoBarras";

    private readonly AppDbContext _context;
    private readonly IArmazenamentoFotos _fotos;
    private readonly ReposicaoService _reposicao;

    public ProdutoController(AppDbContext context, IArmazenamentoFotos fotos, ReposicaoService reposicao)
    {
        _context = context;
        _fotos = fotos;
        _reposicao = reposicao;
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
                p.IdProduto.ToString().Contains(busca) ||
                (p.CodigoBarras != null && p.CodigoBarras == busca.Trim()));
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

        // Linha do tempo das ultimas entradas e saidas e a previsao de reposicao do produto.
        ViewBag.Movimentacoes = await _context.MovimentacoesEstoque.AsNoTracking()
            .Where(m => m.IdProduto == produto.IdProduto)
            .OrderByDescending(m => m.Data)
            .Take(8)
            .ToListAsync();
        ViewBag.Reposicao = (await _reposicao.CalcularAsync()).FirstOrDefault(s => s.IdProduto == produto.IdProduto);
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
    public async Task<IActionResult> Create([Bind(CamposEditaveis)] Produto produto, IFormFile? foto)
    {
        // O codigo (IdProduto) e gerado pelo banco; nao vem do formulario.
        await ValidarCodigoBarrasAsync(produto);
        if (ModelState.IsValid && foto is { Length: > 0 })
        {
            produto.FotoUrl = await SalvarFotoAsync(foto);
        }

        if (!ModelState.IsValid)
        {
            CarregarCombos(produto.IdCategoria, produto.IdFornecedor);
            return View(produto);
        }

        _context.Add(produto);
        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Produto cadastrado: {produto.Nome}.");
        return RedirectToAction(nameof(Details), new { id = produto.IdProduto });
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
    public async Task<IActionResult> Edit(int id, [Bind(CamposEditaveis)] Produto dados, IFormFile? foto, bool removerFoto = false)
    {
        // Carrega o produto do banco e copia so os campos do formulario:
        // assim a foto atual nao se perde quando nenhuma foto nova e enviada.
        var produto = await _context.Produtos.FindAsync(id);
        if (produto == null)
        {
            return NotFound();
        }

        dados.IdProduto = id;
        dados.FotoUrl = produto.FotoUrl;
        await ValidarCodigoBarrasAsync(dados);

        string? novaFoto = null;
        if (ModelState.IsValid && foto is { Length: > 0 })
        {
            novaFoto = await SalvarFotoAsync(foto);
        }

        if (!ModelState.IsValid)
        {
            CarregarCombos(dados.IdCategoria, dados.IdFornecedor);
            return View(dados);
        }

        var fotoAntiga = produto.FotoUrl;
        produto.Nome = dados.Nome;
        produto.Descricao = dados.Descricao;
        produto.Tamanho = dados.Tamanho;
        produto.Cor = dados.Cor;
        produto.Preco = dados.Preco;
        produto.Estoque = dados.Estoque;
        produto.IdCategoria = dados.IdCategoria;
        produto.IdFornecedor = dados.IdFornecedor;
        produto.CodigoBarras = dados.CodigoBarras;
        if (novaFoto != null || removerFoto)
        {
            produto.FotoUrl = novaFoto;
        }

        await _context.SaveChangesAsync();
        if (produto.FotoUrl != fotoAntiga)
        {
            await _fotos.ExcluirAsync(fotoAntiga);
        }

        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Produto alterado: {produto.Nome}.");
        return RedirectToAction(nameof(Details), new { id = produto.IdProduto });
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
            await _fotos.ExcluirAsync(produto.FotoUrl);
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Produto removido: {produto.Nome}.");
        }

        return RedirectToAction(nameof(Index));
    }

    private async Task ValidarCodigoBarrasAsync(Produto produto)
    {
        produto.CodigoBarras = CodigoBarras.Normalizar(produto.CodigoBarras);
        if (produto.CodigoBarras == null)
        {
            return;
        }

        if (!CodigoBarras.EhValido(produto.CodigoBarras))
        {
            ModelState.AddModelError(nameof(Produto.CodigoBarras), CodigoBarras.MensagemInvalido);
        }
        else if (await _context.Produtos.AnyAsync(p => p.CodigoBarras == produto.CodigoBarras && p.IdProduto != produto.IdProduto))
        {
            ModelState.AddModelError(nameof(Produto.CodigoBarras), "Já existe outro produto com este código de barras.");
        }
    }

    private async Task<string?> SalvarFotoAsync(IFormFile foto)
    {
        try
        {
            await using var conteudo = foto.OpenReadStream();
            return await _fotos.SalvarAsync(conteudo, HttpContext.RequestAborted);
        }
        catch (FotoInvalidaException ex)
        {
            ModelState.AddModelError("Foto", ex.Message);
            return null;
        }
    }

    private void CarregarCombos(int? categoriaSelecionada = null, int? fornecedorSelecionado = null)
    {
        ViewBag.Categorias = new SelectList(_context.Categorias.OrderBy(c => c.Nome), "IdCategoria", "Nome", categoriaSelecionada);
        ViewBag.Fornecedores = new SelectList(_context.Fornecedores.OrderBy(f => f.Nome), "IdFornecedor", "Nome", fornecedorSelecionado);
    }
}
