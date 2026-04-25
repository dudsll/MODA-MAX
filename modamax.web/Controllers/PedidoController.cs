using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;
using modamax.web.ViewModels;

namespace modamax.web.Controllers;

[RequireUser("Estrategico", "Tatico", "Operacional")]
public class PedidoController : Controller
{
    private readonly AppDbContext _context;

    public PedidoController(AppDbContext context)
    {
        _context = context;
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
        return View(await MontarFormularioAsync(new PedidoFormViewModel()));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(PedidoFormViewModel viewModel)
    {
        var produto = await _context.Produtos.FindAsync(viewModel.IdProduto);
        if (produto == null)
        {
            ModelState.AddModelError("IdProduto", "Produto nao encontrado.");
        }
        else if (viewModel.Status != "Cancelado" && produto.Estoque < viewModel.Quantidade)
        {
            ModelState.AddModelError("Quantidade", "Estoque insuficiente para este pedido.");
        }

        if (!ModelState.IsValid || produto == null)
        {
            return View(await MontarFormularioAsync(viewModel));
        }

        var precoUnitario = CalcularPrecoUnitario(produto.Preco, viewModel.TiposVenda);
        var total = (precoUnitario * viewModel.Quantidade) - viewModel.Desconto;

        var pedido = new Pedido
        {
            IdCliente = viewModel.IdCliente,
            DataPedido = viewModel.DataPedido,
            TiposVenda = viewModel.TiposVenda,
            Status = viewModel.Status,
            ValorTotal = total,
            Itens =
            {
                new ItemPedido
                {
                    IdProduto = viewModel.IdProduto,
                    Quantidade = viewModel.Quantidade,
                    PrecoUnitario = precoUnitario,
                    Desconto = viewModel.Desconto
                }
            }
        };

        if (viewModel.Status != "Cancelado")
        {
            produto.Estoque -= viewModel.Quantidade;
            _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
            {
                IdProduto = viewModel.IdProduto,
                Tipo = "Saida",
                Quantidade = viewModel.Quantidade,
                Data = DateTime.Now,
                Observacao = "Pedido criado"
            });
        }

        _context.Pedidos.Add(pedido);
        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Pedido criado para o cliente {pedido.IdCliente}.");
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int? id)
    {
        if (id == null) return NotFound();

        var pedido = await _context.Pedidos
            .Include(p => p.Itens)
            .FirstOrDefaultAsync(p => p.IdPedido == id);

        if (pedido == null) return NotFound();

        var item = pedido.Itens.FirstOrDefault();
        var viewModel = new PedidoFormViewModel
        {
            IdPedido = pedido.IdPedido,
            IdCliente = pedido.IdCliente,
            DataPedido = pedido.DataPedido,
            TiposVenda = pedido.TiposVenda,
            Status = pedido.Status,
            IdProduto = item?.IdProduto ?? 0,
            Quantidade = item?.Quantidade ?? 1,
            Desconto = item?.Desconto ?? 0m,
            ValorTotal = pedido.ValorTotal
        };

        return View(await MontarFormularioAsync(viewModel));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, PedidoFormViewModel viewModel)
    {
        if (id != viewModel.IdPedido) return NotFound();

        var pedido = await _context.Pedidos
            .Include(p => p.Itens)
            .FirstOrDefaultAsync(p => p.IdPedido == id);

        if (pedido == null) return NotFound();

        var item = pedido.Itens.First();
        var produtoAnterior = await _context.Produtos.FindAsync(item.IdProduto);
        if (produtoAnterior != null && pedido.Status != "Cancelado")
        {
            produtoAnterior.Estoque += item.Quantidade;
            _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
            {
                IdProduto = produtoAnterior.IdProduto,
                Tipo = "Entrada",
                Quantidade = item.Quantidade,
                Data = DateTime.Now,
                Observacao = $"Ajuste do pedido #{pedido.IdPedido}"
            });
        }

        var produtoNovo = await _context.Produtos.FindAsync(viewModel.IdProduto);
        if (produtoNovo == null)
        {
            ModelState.AddModelError("IdProduto", "Produto nao encontrado.");
        }
        else if (viewModel.Status != "Cancelado" && produtoNovo.Estoque < viewModel.Quantidade)
        {
            ModelState.AddModelError("Quantidade", "Estoque insuficiente para atualizar o pedido.");
        }

        if (!ModelState.IsValid || produtoNovo == null)
        {
            return View(await MontarFormularioAsync(viewModel));
        }

        var precoUnitario = CalcularPrecoUnitario(produtoNovo.Preco, viewModel.TiposVenda);
        var total = (precoUnitario * viewModel.Quantidade) - viewModel.Desconto;

        pedido.IdCliente = viewModel.IdCliente;
        pedido.DataPedido = viewModel.DataPedido;
        pedido.TiposVenda = viewModel.TiposVenda;
        pedido.Status = viewModel.Status;
        pedido.ValorTotal = total;

        item.IdProduto = viewModel.IdProduto;
        item.Quantidade = viewModel.Quantidade;
        item.PrecoUnitario = precoUnitario;
        item.Desconto = viewModel.Desconto;

        if (viewModel.Status != "Cancelado")
        {
            produtoNovo.Estoque -= viewModel.Quantidade;
            _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
            {
                IdProduto = produtoNovo.IdProduto,
                Tipo = "Saida",
                Quantidade = viewModel.Quantidade,
                Data = DateTime.Now,
                Observacao = $"Pedido #{pedido.IdPedido} atualizado"
            });
        }

        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Pedido atualizado: #{pedido.IdPedido}.");
        return RedirectToAction(nameof(Index));
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
        var pedido = await _context.Pedidos
            .Include(p => p.Itens)
            .FirstOrDefaultAsync(p => p.IdPedido == id);

        if (pedido != null)
        {
            var item = pedido.Itens.FirstOrDefault();
            if (item != null && pedido.Status != "Cancelado")
            {
                var produto = await _context.Produtos.FindAsync(item.IdProduto);
                if (produto != null)
                {
                    produto.Estoque += item.Quantidade;
                    _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
                    {
                        IdProduto = produto.IdProduto,
                        Tipo = "Entrada",
                        Quantidade = item.Quantidade,
                        Data = DateTime.Now,
                        Observacao = $"Exclusao do pedido #{pedido.IdPedido}"
                    });
                }
            }

            _context.Pedidos.Remove(pedido);
            await _context.SaveChangesAsync();
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Pedido excluido: #{pedido.IdPedido}.");
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> Cancelar(int id)
    {
        var pedido = await _context.Pedidos.Include(p => p.Itens).FirstOrDefaultAsync(p => p.IdPedido == id);
        if (pedido == null) return NotFound();

        if (pedido.Status != "Cancelado")
        {
            var item = pedido.Itens.FirstOrDefault();
            if (item != null)
            {
                var produto = await _context.Produtos.FindAsync(item.IdProduto);
                if (produto != null)
                {
                    produto.Estoque += item.Quantidade;
                    _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
                    {
                        IdProduto = produto.IdProduto,
                        Tipo = "Entrada",
                        Quantidade = item.Quantidade,
                        Data = DateTime.Now,
                        Observacao = $"Cancelamento do pedido #{pedido.IdPedido}"
                    });
                }
            }

            pedido.Status = "Cancelado";
            await _context.SaveChangesAsync();
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Pedido cancelado: #{pedido.IdPedido}.");
        }

        return RedirectToAction(nameof(Index));
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
        viewModel.Clientes = await _context.Clientes.OrderBy(c => c.Nome).ToListAsync();
        viewModel.Produtos = await _context.Produtos.OrderBy(p => p.Nome).ToListAsync();
        return viewModel;
    }

    private static decimal CalcularPrecoUnitario(decimal precoBase, string tipoVenda)
    {
        return string.Equals(tipoVenda, "Atacado", StringComparison.OrdinalIgnoreCase)
            ? Math.Round(precoBase * 0.9m, 2)
            : precoBase;
    }
}
