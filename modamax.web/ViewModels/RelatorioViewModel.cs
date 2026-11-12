namespace modamax.web.ViewModels;

public class RelatorioViewModel
{
    public DateTime? DataInicial { get; set; }

    public DateTime? DataFinal { get; set; }

    public int TotalPedidos { get; set; }

    public int TotalItens { get; set; }

    public decimal Faturamento { get; set; }

    public decimal TicketMedio => TotalPedidos == 0 ? 0 : Math.Round(Faturamento / TotalPedidos, 2, MidpointRounding.AwayFromZero);

    public string DescricaoPeriodo => (DataInicial, DataFinal) switch
    {
        (null, null) => "Todo o período",
        ({ } inicio, null) => $"A partir de {inicio:dd/MM/yyyy}",
        (null, { } fim) => $"Até {fim:dd/MM/yyyy}",
        ({ } inicio, { } fim) => $"{inicio:dd/MM/yyyy} a {fim:dd/MM/yyyy}"
    };

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
    public DateTime Data { get; set; }

    public string Periodo => Data.ToString("dd/MM/yyyy");

    public int Pedidos { get; set; }

    public int Itens { get; set; }

    public decimal Total { get; set; }
}
