using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.ViewModels;

namespace modamax.web.Services;

// Relatorio de vendas por periodo, usado pela tela e pelas exportacoes em PDF e Excel.
// Pedidos cancelados nao entram nos numeros.
public class RelatorioService
{
    private readonly AppDbContext _context;

    public RelatorioService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<RelatorioViewModel> GerarAsync(DateTime? dataInicial, DateTime? dataFinal)
    {
        // Datas invertidas no filtro sao trocadas em vez de devolver um relatorio vazio.
        if (dataInicial > dataFinal)
        {
            (dataInicial, dataFinal) = (dataFinal, dataInicial);
        }

        var pedidos = _context.Pedidos
            .AsNoTracking()
            .Include(p => p.Itens)
            .ThenInclude(i => i.Produto)
            .Where(p => p.Status != PedidoService.StatusCancelado);

        if (dataInicial.HasValue)
        {
            pedidos = pedidos.Where(p => p.DataPedido.Date >= dataInicial.Value.Date);
        }

        if (dataFinal.HasValue)
        {
            pedidos = pedidos.Where(p => p.DataPedido.Date <= dataFinal.Value.Date);
        }

        var lista = await pedidos.ToListAsync();

        return new RelatorioViewModel
        {
            DataInicial = dataInicial,
            DataFinal = dataFinal,
            TotalPedidos = lista.Count,
            TotalItens = lista.Sum(p => p.Itens.Sum(i => i.Quantidade)),
            Faturamento = lista.Sum(p => p.ValorTotal),
            ProdutosMaisVendidos = lista
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
            // Ordenado pela data em si; antes a ordenacao era pelo texto "dd/MM/yyyy" e misturava os meses.
            VendasPorPeriodo = lista
                .GroupBy(p => p.DataPedido.Date)
                .OrderBy(g => g.Key)
                .Select(g => new VendaPorPeriodoViewModel
                {
                    Data = g.Key,
                    Pedidos = g.Count(),
                    Itens = g.Sum(p => p.Itens.Sum(i => i.Quantidade)),
                    Total = g.Sum(p => p.ValorTotal)
                })
                .ToList()
        };
    }
}
