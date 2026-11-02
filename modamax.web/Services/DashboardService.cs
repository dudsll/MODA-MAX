using System.Globalization;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;

namespace modamax.web.Services;

public record PontoGrafico(string Rotulo, decimal Valor);

public class GraficosDashboard
{
    public List<PontoGrafico> VendasPorMes { get; init; } = new();

    public List<PontoGrafico> ProdutosMaisVendidos { get; init; } = new();

    public List<PontoGrafico> PedidosPorStatus { get; init; } = new();

    public List<PontoGrafico> EstoquePorCategoria { get; init; } = new();
}

// Indicadores dos graficos do painel, usados pela Web (Chart.js) e pela API (app mobile).
public class DashboardService
{
    private static readonly CultureInfo PtBr = new("pt-BR");

    private readonly AppDbContext _context;

    public DashboardService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<GraficosDashboard> GerarGraficosAsync(int meses = 6)
    {
        var inicio = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-(meses - 1));

        // Os agrupamentos sao feitos em memoria: o volume e pequeno e assim
        // o mesmo codigo funciona no SQL Server e no SQLite dos testes.
        var pedidos = await _context.Pedidos
            .AsNoTracking()
            .Where(p => p.DataPedido >= inicio)
            .Select(p => new { p.DataPedido, p.Status, p.ValorTotal })
            .ToListAsync();

        var vendasPorMes = Enumerable.Range(0, meses)
            .Select(i => inicio.AddMonths(i))
            .Select(mes => new PontoGrafico(
                $"{PtBr.TextInfo.ToTitleCase(mes.ToString("MMM", PtBr).TrimEnd('.'))}/{mes:yy}",
                pedidos
                    .Where(p => p.Status != PedidoService.StatusCancelado && p.DataPedido.Year == mes.Year && p.DataPedido.Month == mes.Month)
                    .Sum(p => p.ValorTotal)))
            .ToList();

        var itensVendidos = await _context.ItensPedido
            .AsNoTracking()
            .Where(i => i.Pedido!.Status != PedidoService.StatusCancelado)
            .Select(i => new { Produto = i.Produto!.Nome, i.Quantidade })
            .ToListAsync();

        var maisVendidos = itensVendidos
            .GroupBy(i => i.Produto)
            .Select(g => new PontoGrafico(g.Key, g.Sum(i => i.Quantidade)))
            .OrderByDescending(p => p.Valor)
            .Take(5)
            .ToList();

        var todosStatus = await _context.Pedidos.AsNoTracking().Select(p => p.Status).ToListAsync();
        var porStatus = todosStatus
            .GroupBy(s => s)
            .Select(g => new PontoGrafico(g.Key, g.Count()))
            .OrderByDescending(p => p.Valor)
            .ToList();

        var estoque = await _context.Produtos
            .AsNoTracking()
            .Select(p => new { Categoria = p.Categoria!.Nome, p.Estoque })
            .ToListAsync();

        var estoquePorCategoria = estoque
            .GroupBy(p => p.Categoria)
            .Select(g => new PontoGrafico(g.Key, g.Sum(p => p.Estoque)))
            .OrderByDescending(p => p.Valor)
            .ToList();

        return new GraficosDashboard
        {
            VendasPorMes = vendasPorMes,
            ProdutosMaisVendidos = maisVendidos,
            PedidosPorStatus = porStatus,
            EstoquePorCategoria = estoquePorCategoria
        };
    }
}
