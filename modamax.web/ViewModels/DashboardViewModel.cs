using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.ViewModels;

// Indicador com comparacao ao mesmo periodo do mes anterior.
public record IndicadorPainel(decimal Atual, decimal Anterior)
{
    public int? Variacao => Anterior == 0 ? null : (int)Math.Round((Atual / Anterior - 1) * 100, MidpointRounding.AwayFromZero);
}

public class DashboardViewModel
{
    public string Saudacao { get; set; } = "Olá";

    public string PrimeiroNome { get; set; } = string.Empty;

    public int TotalProdutos { get; set; }

    public int TotalClientes { get; set; }

    public int TotalPedidos { get; set; }

    public int TotalUsuarios { get; set; }

    public decimal FaturamentoTotal { get; set; }

    public int ProdutosAbaixoDoMinimo { get; set; }

    public IndicadorPainel FaturamentoMes { get; set; } = new(0, 0);

    public IndicadorPainel PedidosMes { get; set; } = new(0, 0);

    public IndicadorPainel TicketMedioMes { get; set; } = new(0, 0);

    public decimal AReceber { get; set; }

    public int PedidosAReceber { get; set; }

    public ProgressoMeta? Meta { get; set; }

    public List<SugestaoReposicao> ParaRepor { get; set; } = new();

    public List<Produto> ProdutosComMenorEstoque { get; set; } = new();

    public List<Pedido> PedidosRecentes { get; set; } = new();

    public List<LogSistema> LogsRecentes { get; set; } = new();

    public GraficosDashboard Graficos { get; set; } = new();
}
