using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Dtos;
using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.Controllers.Api;

[ApiController]
[Route("api/produtos")]
[Authorize]
public class ProdutosApiController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IArmazenamentoFotos _fotos;

    public ProdutosApiController(AppDbContext context, IArmazenamentoFotos fotos)
    {
        _context = context;
        _fotos = fotos;
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
            var codigo = busca.Trim();
            query = query.Where(p => p.Nome.Contains(busca) || p.CodigoBarras == codigo);
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

    // GET /api/produtos/codigo/7891234500014  (leitor de codigo de barras do app)
    [HttpGet("codigo/{codigo}")]
    public async Task<ActionResult<ProdutoDto>> ObterPorCodigo(string codigo)
    {
        var normalizado = CodigoBarras.Normalizar(codigo);
        if (!CodigoBarras.EhValido(normalizado))
        {
            return Problem(detail: CodigoBarras.MensagemInvalido, statusCode: StatusCodes.Status400BadRequest);
        }

        var produto = await _context.Produtos
            .Include(p => p.Categoria)
            .Include(p => p.Fornecedor)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.CodigoBarras == normalizado);

        return produto == null
            ? Problem(detail: $"Nenhum produto cadastrado com o código {normalizado}.", statusCode: StatusCodes.Status404NotFound)
            : ParaDto(produto);
    }

    // POST /api/produtos/5/foto  (multipart/form-data, campo "foto")
    [HttpPost("{id:int}/foto")]
    [Authorize(Roles = "Estrategico,Tatico")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(3 * 1024 * 1024)]
    public async Task<ActionResult<ProdutoDto>> EnviarFoto(int id, IFormFile foto)
    {
        var produto = await _context.Produtos.Include(p => p.Categoria).Include(p => p.Fornecedor)
            .FirstOrDefaultAsync(p => p.IdProduto == id);
        if (produto == null) return NotFound();

        string url;
        try
        {
            await using var conteudo = foto.OpenReadStream();
            url = await _fotos.SalvarAsync(conteudo, HttpContext.RequestAborted);
        }
        catch (FotoInvalidaException ex)
        {
            return Problem(detail: ex.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        var fotoAntiga = produto.FotoUrl;
        produto.FotoUrl = url;
        await _context.SaveChangesAsync();
        await _fotos.ExcluirAsync(fotoAntiga);
        return ParaDto(produto);
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
        var erro = await ValidarCodigoBarrasAsync(dto, idProduto: 0);
        if (erro != null) return erro;

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

        var erro = await ValidarCodigoBarrasAsync(dto, id);
        if (erro != null) return erro;

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
            return Problem(detail: "Produto possui pedidos e nao pode ser excluido.", statusCode: StatusCodes.Status409Conflict);
        }

        _context.Produtos.Remove(produto);
        await _context.SaveChangesAsync();
        await _fotos.ExcluirAsync(produto.FotoUrl);
        return NoContent();
    }

    private async Task<ObjectResult?> ValidarCodigoBarrasAsync(ProdutoSalvarDto dto, int idProduto)
    {
        dto.CodigoBarras = CodigoBarras.Normalizar(dto.CodigoBarras);
        if (dto.CodigoBarras == null) return null;

        if (!CodigoBarras.EhValido(dto.CodigoBarras))
        {
            return Problem(detail: CodigoBarras.MensagemInvalido, statusCode: StatusCodes.Status400BadRequest);
        }

        var duplicado = await _context.Produtos.AnyAsync(p => p.CodigoBarras == dto.CodigoBarras && p.IdProduto != idProduto);
        return duplicado
            ? Problem(detail: "Já existe outro produto com este código de barras.", statusCode: StatusCodes.Status409Conflict)
            : null;
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
        produto.CodigoBarras = dto.CodigoBarras;
    }

    private static ProdutoDto ParaDto(Produto p) => new(
        p.IdProduto, p.Nome, p.Descricao, p.Tamanho, p.Cor, p.Preco, p.Estoque,
        p.IdCategoria, p.Categoria?.Nome, p.IdFornecedor, p.Fornecedor?.Nome, p.CodigoBarras, p.FotoUrl);
}
