using modamax.web.Models;

namespace modamax.web.ViewModels;

public class DashboardViewModel
{
    public int TotalProdutos { get; set; }

    public int TotalClientes { get; set; }

    public int TotalPedidos { get; set; }

    public decimal FaturamentoTotal { get; set; }

    public List<Produto> ProdutosComMenorEstoque { get; set; } = new();

    public List<Pedido> PedidosRecentes { get; set; } = new();
}
