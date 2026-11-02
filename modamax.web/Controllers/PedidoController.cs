using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Services;
using modamax.web.ViewModels;

namespace modamax.web.Controllers;

[RequireUser("Estrategico", "Tatico", "Operacional")]
public class PedidoController : Controller
{
    private readonly AppDbContext _context;
    private readonly PedidoService _pedidoService;

    public PedidoController(AppDbContext context, PedidoService pedidoService)
    {
        _context = context;
        _pedidoService = pedidoService;
    }

    public async Task<IActionResult> Index()
    {
        var pedidos = await _context.Pedidos
            .Include(p => p.Cliente)
            .Include(p => p.Itens)
            .ThenInclude(i => i.Produto)
            .OrderByDescending(p => p.DataPedido)
            .ToListAsync();

        return View(pedidos);
    }

    public async Task<IActionResult> Details(int? id)
    {
        if (id == null) return NotFound();

        var pedido = await _context.Pedidos
            .Include(p => p.Cliente)
            .Include(p => p.Itens)
            .ThenInclude(i => i.Produto)
            .FirstOrDefaultAsync(p => p.IdPedido == id);

        return pedido == null ? NotFound() : View(pedido);
    }

    public async Task<IActionResult> Create()
    {
        var viewModel = new PedidoFormViewModel { Itens = { new PedidoItemFormViewModel() } };
        return View(await MontarFormularioAsync(viewModel));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(PedidoFormViewModel viewModel)
    {
        if (!ModelState.IsValid)
        {
            return View(await MontarFormularioAsync(viewModel));
        }

        var resultado = await _pedidoService.CriarAsync(ParaDados(viewModel));
        if (!resultado.Sucesso)
        {
            ModelState.AddModelError(string.Empty, resultado.Erro!);
            return View(await MontarFormularioAsync(viewModel));
        }

        await AuditoriaHelper.RegistrarAsync(_context, HttpContext,
            $"Pedido #{resultado.Pedido!.IdPedido} criado para o cliente {resultado.Pedido.IdCliente} ({resultado.Pedido.Itens.Count} itens).");
        TempData["Mensagem"] = $"Pedido #{resultado.Pedido.IdPedido} registrado.";
        return RedirectToAction(nameof(Details), new { id = resultado.Pedido.IdPedido });
    }

    public async Task<IActionResult> Edit(int? id)
    {
        if (id == null) return NotFound();

        var pedido = await _context.Pedidos
            .Include(p => p.Itens)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.IdPedido == id);

        if (pedido == null) return NotFound();

        var viewModel = new PedidoFormViewModel
        {
            IdPedido = pedido.IdPedido,
            IdCliente = pedido.IdCliente,
            DataPedido = pedido.DataPedido,
            TiposVenda = pedido.TiposVenda,
            Status = pedido.Status,
            ValorTotal = pedido.ValorTotal,
            Itens = pedido.Itens
                .Select(i => new PedidoItemFormViewModel { IdProduto = i.IdProduto, Quantidade = i.Quantidade, Desconto = i.Desconto })
                .ToList()
        };

        return View(await MontarFormularioAsync(viewModel));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, PedidoFormViewModel viewModel)
    {
        if (id != viewModel.IdPedido) return NotFound();

        if (!ModelState.IsValid)
        {
            return View(await MontarFormularioAsync(viewModel));
        }

        var resultado = await _pedidoService.AtualizarAsync(id, ParaDados(viewModel));
        if (resultado.NaoEncontrado) return NotFound();
        if (!resultado.Sucesso)
        {
            ModelState.AddModelError(string.Empty, resultado.Erro!);
            return View(await MontarFormularioAsync(viewModel));
        }

        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Pedido atualizado: #{id}.");
        TempData["Mensagem"] = $"Pedido #{id} atualizado.";
        return RedirectToAction(nameof(Details), new { id });
    }

    public async Task<IActionResult> Delete(int? id)
    {
        if (id == null) return NotFound();

        var pedido = await _context.Pedidos
            .Include(p => p.Cliente)
            .Include(p => p.Itens)
            .ThenInclude(i => i.Produto)
            .FirstOrDefaultAsync(p => p.IdPedido == id);

        return pedido == null ? NotFound() : View(pedido);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var resultado = await _pedidoService.ExcluirAsync(id);
        if (resultado.Sucesso)
        {
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Pedido excluido: #{id}.");
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> Cancelar(int id)
    {
        var resultado = await _pedidoService.CancelarAsync(id);
        if (resultado.NaoEncontrado) return NotFound();

        if (resultado.Sucesso)
        {
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Pedido cancelado: #{id}.");
            TempData["Mensagem"] = $"Pedido #{id} cancelado e itens devolvidos ao estoque.";
        }

        return RedirectToAction(nameof(Details), new { id });
    }

    public async Task<IActionResult> Historico(int? clienteId)
    {
        var query = _context.Pedidos
            .Include(p => p.Cliente)
            .Include(p => p.Itens)
            .ThenInclude(i => i.Produto)
            .AsQueryable();

        if (clienteId.HasValue)
        {
            query = query.Where(p => p.IdCliente == clienteId.Value);
        }

        ViewBag.Clientes = await _context.Clientes.OrderBy(c => c.Nome).ToListAsync();
        ViewBag.ClienteId = clienteId;
        return View(await query.OrderByDescending(p => p.DataPedido).ToListAsync());
    }

    private async Task<PedidoFormViewModel> MontarFormularioAsync(PedidoFormViewModel viewModel)
    {
        viewModel.Clientes = await _context.Clientes.AsNoTracking().OrderBy(c => c.Nome).ToListAsync();
        viewModel.Produtos = await _context.Produtos.AsNoTracking().OrderBy(p => p.Nome).ToListAsync();
        if (viewModel.Itens.Count == 0)
        {
            viewModel.Itens.Add(new PedidoItemFormViewModel());
        }

        return viewModel;
    }

    private static DadosPedido ParaDados(PedidoFormViewModel viewModel) => new()
    {
        IdCliente = viewModel.IdCliente,
        DataPedido = viewModel.DataPedido,
        TiposVenda = viewModel.TiposVenda,
        Status = viewModel.Status,
        Itens = viewModel.Itens
            .Select(i => new ItemPedidoEntrada { IdProduto = i.IdProduto, Quantidade = i.Quantidade, Desconto = i.Desconto })
            .ToList()
    };
}
