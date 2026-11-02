using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.ViewModels;

public class DashboardViewModel
{
    public int TotalProdutos { get; set; }

    public int TotalClientes { get; set; }

    public int TotalPedidos { get; set; }

    public int TotalUsuarios { get; set; }

    public decimal FaturamentoTotal { get; set; }

    public int ProdutosAbaixoDoMinimo { get; set; }

    public List<Produto> ProdutosComMenorEstoque { get; set; } = new();

    public List<Pedido> PedidosRecentes { get; set; } = new();

    public List<LogSistema> LogsRecentes { get; set; } = new();

    public GraficosDashboard Graficos { get; set; } = new();
}
