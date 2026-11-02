using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Dtos;
using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.Controllers.Api;

[ApiController]
[Route("api/pedidos")]
[Authorize]
public class PedidosApiController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly PedidoService _pedidoService;

    public PedidosApiController(AppDbContext context, PedidoService pedidoService)
    {
        _context = context;
        _pedidoService = pedidoService;
    }

    // GET /api/pedidos?clienteId=1&status=Finalizado
    [HttpGet]
    public async Task<ActionResult<IEnumerable<PedidoDto>>> Listar(int? clienteId, string? status)
    {
        var query = ConsultaCompleta();

        if (clienteId.HasValue)
        {
            query = query.Where(p => p.IdCliente == clienteId.Value);
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            query = query.Where(p => p.Status == status);
        }

        var pedidos = await query.OrderByDescending(p => p.DataPedido).ToListAsync();
        return pedidos.Select(ParaDto).ToList();
    }

    // GET /api/pedidos/5
    [HttpGet("{id:int}")]
    public async Task<ActionResult<PedidoDto>> Obter(int id)
    {
        var pedido = await ConsultaCompleta().FirstOrDefaultAsync(p => p.IdPedido == id);
        return pedido == null ? NotFound() : ParaDto(pedido);
    }

    // POST /api/pedidos  { idCliente, tiposVenda, itens: [{ idProduto, quantidade, desconto }] }
    [HttpPost]
    public async Task<ActionResult<PedidoDto>> Criar(PedidoCriarDto dto)
    {
        var resultado = await _pedidoService.CriarAsync(new DadosPedido
        {
            IdCliente = dto.IdCliente,
            TiposVenda = dto.TiposVenda,
            Itens = dto.Itens
                .Select(i => new ItemPedidoEntrada { IdProduto = i.IdProduto, Quantidade = i.Quantidade, Desconto = i.Desconto })
                .ToList()
        });
        if (!resultado.Sucesso)
        {
            return BadRequest(new { mensagem = resultado.Erro });
        }

        var pedido = await ConsultaCompleta().FirstAsync(p => p.IdPedido == resultado.Pedido!.IdPedido);
        return CreatedAtAction(nameof(Obter), new { id = pedido.IdPedido }, ParaDto(pedido));
    }

    // PUT /api/pedidos/5/cancelar
    // Mesma regra da Web: so os niveis Estrategico e Tatico cancelam pedidos.
    [HttpPut("{id:int}/cancelar")]
    [Authorize(Roles = "Estrategico,Tatico")]
    public async Task<IActionResult> Cancelar(int id)
    {
        var resultado = await _pedidoService.CancelarAsync(id);
        if (!resultado.Sucesso)
        {
            return resultado.NaoEncontrado ? NotFound() : BadRequest(new { mensagem = resultado.Erro });
        }

        return NoContent();
    }

    private IQueryable<Pedido> ConsultaCompleta() => _context.Pedidos
        .Include(p => p.Cliente)
        .Include(p => p.Itens)
        .ThenInclude(i => i.Produto)
        .AsNoTracking();

    private static PedidoDto ParaDto(Pedido p) => new(
        p.IdPedido,
        p.IdCliente,
        p.Cliente?.Nome,
        p.DataPedido,
        p.TiposVenda,
        p.Status,
        p.ValorTotal,
        p.Itens.Select(i => new ItemPedidoDto(
            i.IdItem, i.IdProduto, i.Produto?.Nome, i.Quantidade, i.PrecoUnitario, i.Desconto,
            (i.PrecoUnitario * i.Quantidade) - i.Desconto)).ToList());
}
