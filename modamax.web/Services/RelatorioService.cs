using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.ViewModels;

namespace modamax.web.Services;

public record ItemCurvaAbc(
    int IdProduto,
    string Produto,
    string? Categoria,
    int Quantidade,
    decimal Faturamento,
    decimal Participacao,
    decimal Acumulado,
    char Classe);

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

    // Curva ABC (principio de Pareto): ordena os produtos pelo faturamento e classifica
    // A = ate 80% do faturamento acumulado, B = ate 95%, C = o restante (inclui quem nao vendeu).
    public async Task<List<ItemCurvaAbc>> CurvaAbcAsync(DateTime? dataInicial, DateTime? dataFinal)
    {
        if (dataInicial > dataFinal)
        {
            (dataInicial, dataFinal) = (dataFinal, dataInicial);
        }

        var itens = _context.ItensPedido.AsNoTracking().Where(i => i.Pedido!.Status != PedidoService.StatusCancelado);
        if (dataInicial.HasValue)
        {
            itens = itens.Where(i => i.Pedido!.DataPedido.Date >= dataInicial.Value.Date);
        }

        if (dataFinal.HasValue)
        {
            itens = itens.Where(i => i.Pedido!.DataPedido.Date <= dataFinal.Value.Date);
        }

        var vendas = (await itens
                .Select(i => new { i.IdProduto, i.Quantidade, Valor = (i.PrecoUnitario * i.Quantidade) - i.Desconto })
                .ToListAsync())
            .GroupBy(i => i.IdProduto)
            .ToDictionary(g => g.Key, g => (Quantidade: g.Sum(i => i.Quantidade), Faturamento: g.Sum(i => i.Valor)));

        var produtos = await _context.Produtos.AsNoTracking()
            .Select(p => new { p.IdProduto, p.Nome, Categoria = p.Categoria!.Nome })
            .ToListAsync();

        var total = vendas.Values.Sum(v => v.Faturamento);
        var acumulado = 0m;
        return produtos
            .Select(p => (p, venda: vendas.GetValueOrDefault(p.IdProduto)))
            .OrderByDescending(x => x.venda.Faturamento)
            .ThenBy(x => x.p.Nome)
            .Select(x =>
            {
                var participacao = total == 0 ? 0 : Math.Round(x.venda.Faturamento / total * 100, 2, MidpointRounding.AwayFromZero);
                // A classe usa o acumulado ANTES do item: o produto que cruza os 80% ainda e A.
                var classe = total == 0 || x.venda.Faturamento == 0 ? 'C' : acumulado < 80 ? 'A' : acumulado < 95 ? 'B' : 'C';
                acumulado = Math.Min(100, acumulado + participacao);
                return new ItemCurvaAbc(x.p.IdProduto, x.p.Nome, x.p.Categoria, x.venda.Quantidade, x.venda.Faturamento,
                    participacao, acumulado, classe);
            })
            .ToList();
    }
}
