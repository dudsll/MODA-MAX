using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Dtos;
using modamax.web.Models;

namespace modamax.web.Controllers.Api;

[ApiController]
[Route("api/produtos")]
[Authorize]
public class ProdutosApiController : ControllerBase
{
    private readonly AppDbContext _context;

    public ProdutosApiController(AppDbContext context)
    {
        _context = context;
    }

    // GET /api/produtos?busca=jeans&categoriaId=3&somenteDisponiveis=true
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ProdutoDto>>> Listar(string? busca, int? categoriaId, bool somenteDisponiveis = false)
    {
        var query = _context.Produtos
            .Include(p => p.Categoria)
            .Include(p => p.Fornecedor)
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(busca))
        {
            query = query.Where(p => p.Nome.Contains(busca));
        }

        if (categoriaId.HasValue)
        {
            query = query.Where(p => p.IdCategoria == categoriaId.Value);
        }

        if (somenteDisponiveis)
        {
            query = query.Where(p => p.Estoque > 0);
        }

        var produtos = await query.OrderBy(p => p.Nome).ToListAsync();
        return produtos.Select(ParaDto).ToList();
    }

    // GET /api/produtos/5
    [HttpGet("{id:int}")]
    public async Task<ActionResult<ProdutoDto>> Obter(int id)
    {
        var produto = await _context.Produtos
            .Include(p => p.Categoria)
            .Include(p => p.Fornecedor)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.IdProduto == id);

        return produto == null ? NotFound() : ParaDto(produto);
    }

    // GET /api/produtos/estoque-baixo?limite=15  (executa a procedure sp_ProdutosEstoqueBaixo)
    [HttpGet("estoque-baixo")]
    public async Task<ActionResult<IEnumerable<EstoqueBaixoDto>>> EstoqueBaixo(int limite = 15)
    {
        var produtos = await _context.Database
            .SqlQuery<EstoqueBaixoDto>($"EXEC dbo.sp_ProdutosEstoqueBaixo @Limite = {limite}")
            .ToListAsync();

        return produtos;
    }

    // POST /api/produtos/5/entrada-estoque  { quantidade, observacao }  (procedure sp_RegistrarEntradaEstoque)
    [HttpPost("{id:int}/entrada-estoque")]
    [Authorize(Roles = "Estrategico,Tatico")]
    public async Task<ActionResult<object>> EntradaEstoque(int id, EntradaEstoqueDto dto)
    {
        if (!await _context.Produtos.AnyAsync(p => p.IdProduto == id)) return NotFound();

        var estoqueAtual = (await _context.Database
            .SqlQuery<int>($"EXEC dbo.sp_RegistrarEntradaEstoque @IdProduto = {id}, @Quantidade = {dto.Quantidade}, @Observacao = {dto.Observacao}")
            .ToListAsync())
            .Single();

        return new { idProduto = id, estoque = estoqueAtual };
    }

    // POST /api/produtos
    [HttpPost]
    [Authorize(Roles = "Estrategico,Tatico")]
    public async Task<ActionResult<ProdutoDto>> Criar(ProdutoSalvarDto dto)
    {
        var produto = new Produto();
        Copiar(dto, produto);
        _context.Produtos.Add(produto);
        await _context.SaveChangesAsync();

        await _context.Entry(produto).Reference(p => p.Categoria).LoadAsync();
        await _context.Entry(produto).Reference(p => p.Fornecedor).LoadAsync();
        return CreatedAtAction(nameof(Obter), new { id = produto.IdProduto }, ParaDto(produto));
    }

    // PUT /api/produtos/5
    [HttpPut("{id:int}")]
    [Authorize(Roles = "Estrategico,Tatico")]
    public async Task<IActionResult> Atualizar(int id, ProdutoSalvarDto dto)
    {
        var produto = await _context.Produtos.FindAsync(id);
        if (produto == null) return NotFound();

        Copiar(dto, produto);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // DELETE /api/produtos/5
    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Estrategico")]
    public async Task<IActionResult> Excluir(int id)
    {
        var produto = await _context.Produtos.FindAsync(id);
        if (produto == null) return NotFound();

        var possuiVendas = await _context.ItensPedido.AnyAsync(i => i.IdProduto == id);
        if (possuiVendas)
        {
            return Conflict(new { mensagem = "Produto possui pedidos e nao pode ser excluido." });
        }

        _context.Produtos.Remove(produto);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    private static void Copiar(ProdutoSalvarDto dto, Produto produto)
    {
        produto.Nome = dto.Nome;
        produto.Descricao = dto.Descricao;
        produto.Tamanho = dto.Tamanho;
        produto.Cor = dto.Cor;
        produto.Preco = dto.Preco;
        produto.Estoque = dto.Estoque;
        produto.IdCategoria = dto.IdCategoria;
        produto.IdFornecedor = dto.IdFornecedor;
    }

    private static ProdutoDto ParaDto(Produto p) => new(
        p.IdProduto, p.Nome, p.Descricao, p.Tamanho, p.Cor, p.Preco, p.Estoque,
        p.IdCategoria, p.Categoria?.Nome, p.IdFornecedor, p.Fornecedor?.Nome);
}
