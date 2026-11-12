using System.Globalization;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Models;

namespace modamax.web.Services;

public record IndicadorMeta(decimal Meta, decimal Realizado)
{
    // Percentual atingido (pode passar de 100%).
    public int Percentual => Meta <= 0 ? 0 : (int)Math.Round(Realizado / Meta * 100, MidpointRounding.AwayFromZero);
}

public record ProgressoMeta(
    int Ano,
    int Mes,
    string NomeMes,
    bool Definida,
    IndicadorMeta Faturamento,
    IndicadorMeta Pedidos,
    IndicadorMeta Pecas,
    int DiasNoMes,
    int DiasDecorridos,
    decimal ProjecaoFaturamento)
{
    public int DiasRestantes => DiasNoMes - DiasDecorridos;

    // Ritmo necessario por dia para bater a meta de faturamento no tempo que resta.
    public decimal NecessarioPorDia => DiasRestantes <= 0 || Faturamento.Realizado >= Faturamento.Meta
        ? 0
        : Math.Round((Faturamento.Meta - Faturamento.Realizado) / DiasRestantes, 2, MidpointRounding.AwayFromZero);
}

// Metas mensais de vendas e o progresso em relacao a elas (aneis do painel).
public class MetaService
{
    private static readonly CultureInfo PtBr = new("pt-BR");
    private readonly AppDbContext _context;

    public MetaService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ProgressoMeta> ProgressoAsync(DateTime? referencia = null)
    {
        var hoje = (referencia ?? DateTime.Today).Date;
        var inicio = new DateTime(hoje.Year, hoje.Month, 1);
        var diasNoMes = DateTime.DaysInMonth(hoje.Year, hoje.Month);
        var diasDecorridos = hoje.Day;

        var realizado = await RealizadoAsync(inicio, inicio.AddMonths(1));
        var meta = await _context.Metas.AsNoTracking().FirstOrDefaultAsync(m => m.Ano == hoje.Year && m.Mes == hoje.Month)
                   ?? await SugerirAsync(hoje.Year, hoje.Month);

        var projecao = diasDecorridos == 0 ? 0 : Math.Round(realizado.Faturamento / diasDecorridos * diasNoMes, 2, MidpointRounding.AwayFromZero);

        return new ProgressoMeta(
            hoje.Year, hoje.Month, NomeMes(hoje.Year, hoje.Month), meta.IdMeta > 0,
            new IndicadorMeta(meta.Faturamento, realizado.Faturamento),
            new IndicadorMeta(meta.Pedidos, realizado.Pedidos),
            new IndicadorMeta(meta.Pecas, realizado.Pecas),
            diasNoMes, diasDecorridos, projecao);
    }

    // Ultimos meses fechados, para o historico de metas.
    public async Task<List<ProgressoMeta>> HistoricoAsync(int meses = 6, DateTime? referencia = null)
    {
        var hoje = (referencia ?? DateTime.Today).Date;
        var lista = new List<ProgressoMeta>();
        for (var i = meses; i >= 1; i--)
        {
            var mes = new DateTime(hoje.Year, hoje.Month, 1).AddMonths(-i);
            lista.Add(await ProgressoAsync(mes.AddMonths(1).AddDays(-1)));
        }

        return lista;
    }

    public async Task<Meta> ObterOuSugerirAsync(int ano, int mes) =>
        await _context.Metas.AsNoTracking().FirstOrDefaultAsync(m => m.Ano == ano && m.Mes == mes) ?? await SugerirAsync(ano, mes);

    public async Task SalvarAsync(Meta dados)
    {
        var meta = await _context.Metas.FirstOrDefaultAsync(m => m.Ano == dados.Ano && m.Mes == dados.Mes);
        if (meta == null)
        {
            meta = new Meta { Ano = dados.Ano, Mes = dados.Mes };
            _context.Metas.Add(meta);
        }

        meta.Faturamento = dados.Faturamento;
        meta.Pedidos = dados.Pedidos;
        meta.Pecas = dados.Pecas;
        await _context.SaveChangesAsync();
    }

    // Sem meta cadastrada, sugere a media dos tres meses anteriores com 10% de crescimento.
    public async Task<Meta> SugerirAsync(int ano, int mes)
    {
        var inicio = new DateTime(ano, mes, 1);
        var anteriores = await RealizadoAsync(inicio.AddMonths(-3), inicio);
        return new Meta
        {
            Ano = ano,
            Mes = mes,
            Faturamento = Math.Round(anteriores.Faturamento / 3 * 1.1m / 100, MidpointRounding.AwayFromZero) * 100,
            Pedidos = (int)Math.Ceiling(anteriores.Pedidos / 3m * 1.1m),
            Pecas = (int)Math.Ceiling(anteriores.Pecas / 3m * 1.1m)
        };
    }

    public static string NomeMes(int ano, int mes)
    {
        var nome = PtBr.DateTimeFormat.GetMonthName(mes);
        return $"{char.ToUpper(nome[0])}{nome[1..]} de {ano}";
    }

    private async Task<(decimal Faturamento, int Pedidos, int Pecas)> RealizadoAsync(DateTime inicio, DateTime fimExclusivo)
    {
        var pedidos = await _context.Pedidos
            .AsNoTracking()
            .Where(p => p.Status != PedidoService.StatusCancelado && p.DataPedido >= inicio && p.DataPedido < fimExclusivo)
            .Select(p => new { p.ValorTotal, Pecas = p.Itens.Sum(i => i.Quantidade) })
            .ToListAsync();

        return (pedidos.Sum(p => p.ValorTotal), pedidos.Count, pedidos.Sum(p => p.Pecas));
    }
}
