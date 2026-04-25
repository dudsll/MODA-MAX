namespace modamax.web.ViewModels;

public class RelatorioViewModel
{
    public DateTime? DataInicial { get; set; }

    public DateTime? DataFinal { get; set; }

    public List<ProdutoMaisVendidoViewModel> ProdutosMaisVendidos { get; set; } = new();

    public List<VendaPorPeriodoViewModel> VendasPorPeriodo { get; set; } = new();
}

public class ProdutoMaisVendidoViewModel
{
    public string Produto { get; set; } = string.Empty;

    public int QuantidadeVendida { get; set; }

    public decimal Faturamento { get; set; }
}

public class VendaPorPeriodoViewModel
{
    public string Periodo { get; set; } = string.Empty;

    public int Pedidos { get; set; }

    public decimal Total { get; set; }
}
