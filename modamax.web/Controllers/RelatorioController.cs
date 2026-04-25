using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using modamax.web.Filters;
using modamax.web.ViewModels;
using ModaMax.Web.Data;

namespace modamax.web.Controllers;

[RequireUser("Estrategico", "Tatico")]
public class RelatorioController : Controller
{
    private readonly AppDbContext _context;

    public RelatorioController(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IActionResult> Index(DateTime? dataInicial, DateTime? dataFinal)
    {
        var pedidos = _context.Pedidos
            .Include(p => p.Itens)
            .ThenInclude(i => i.Produto)
            .Where(p => p.Status != "Cancelado")
            .AsQueryable();

        if (dataInicial.HasValue)
        {
            pedidos = pedidos.Where(p => p.DataPedido.Date >= dataInicial.Value.Date);
        }

        if (dataFinal.HasValue)
        {
            pedidos = pedidos.Where(p => p.DataPedido.Date <= dataFinal.Value.Date);
        }

        var listaPedidos = await pedidos.ToListAsync();

        var viewModel = new RelatorioViewModel
        {
            DataInicial = dataInicial,
            DataFinal = dataFinal,
            ProdutosMaisVendidos = listaPedidos
                .SelectMany(p => p.Itens)
                .GroupBy(i => i.Produto?.Nome ?? "Sem produto")
                .Select(g => new ProdutoMaisVendidoViewModel
                {
                    Produto = g.Key,
                    QuantidadeVendida = g.Sum(i => i.Quantidade),
                    Faturamento = g.Sum(i => (i.PrecoUnitario * i.Quantidade) - i.Desconto)
                })
                .OrderByDescending(x => x.QuantidadeVendida)
                .Take(10)
                .ToList(),
            VendasPorPeriodo = listaPedidos
                .GroupBy(p => p.DataPedido.Date)
                .Select(g => new VendaPorPeriodoViewModel
                {
                    Periodo = g.Key.ToString("dd/MM/yyyy"),
                    Pedidos = g.Count(),
                    Total = g.Sum(p => p.ValorTotal)
                })
                .OrderBy(x => x.Periodo)
                .ToList()
        };

        return View(viewModel);
    }
}
