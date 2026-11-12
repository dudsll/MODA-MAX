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
    private readonly PixService _pix;

    public PedidosApiController(AppDbContext context, PedidoService pedidoService, PixService pix)
    {
        _context = context;
        _pedidoService = pedidoService;
        _pix = pix;
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
            FormaPagamento = dto.FormaPagamento,
            Parcelas = dto.Parcelas,
            Itens = dto.Itens
                .Select(i => new ItemPedidoEntrada { IdProduto = i.IdProduto, Quantidade = i.Quantidade, Desconto = i.Desconto })
                .ToList()
        });
        if (!resultado.Sucesso)
        {
            return Problem(detail: resultado.Erro, statusCode: StatusCodes.Status400BadRequest);
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
            return Problem(detail: resultado.Erro,
                statusCode: resultado.NaoEncontrado ? StatusCodes.Status404NotFound : StatusCodes.Status400BadRequest);
        }

        return NoContent();
    }

    // PUT /api/pedidos/5/pagamento  (confirma o recebimento)
    [HttpPut("{id:int}/pagamento")]
    public async Task<IActionResult> ConfirmarPagamento(int id)
    {
        var resultado = await _pedidoService.ConfirmarPagamentoAsync(id);
        if (!resultado.Sucesso)
        {
            return Problem(detail: resultado.Erro,
                statusCode: resultado.NaoEncontrado ? StatusCodes.Status404NotFound : StatusCodes.Status400BadRequest);
        }

        return NoContent();
    }

    // GET /api/pedidos/5/pix  ("PIX copia e cola" do pedido, para o app mostrar ao cliente)
    [HttpGet("{id:int}/pix")]
    public async Task<ActionResult<PixDto>> Pix(int id)
    {
        var pedido = await _context.Pedidos.AsNoTracking().FirstOrDefaultAsync(p => p.IdPedido == id);
        if (pedido == null) return NotFound();
        if (pedido.Status == PedidoService.StatusCancelado || pedido.StatusPagamento != Pagamentos.Pendente)
        {
            return Problem(detail: "Este pedido nao tem pagamento pendente.", statusCode: StatusCodes.Status409Conflict);
        }

        return new PixDto(pedido.IdPedido, pedido.ValorTotal, _pix.GerarPayload(pedido.ValorTotal, $"PEDIDO{pedido.IdPedido}"));
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
            (i.PrecoUnitario * i.Quantidade) - i.Desconto)).ToList(),
        p.FormaPagamento,
        p.Parcelas,
        p.StatusPagamento);
}
