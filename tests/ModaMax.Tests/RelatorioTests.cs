using ClosedXML.Excel;
using modamax.web.Models;
using modamax.web.Services;

namespace ModaMax.Tests;

public class RelatorioTests : IDisposable
{
    private readonly BancoDeTeste _banco = new();

    public RelatorioTests()
    {
        // Tres vendas em dias de meses diferentes e uma cancelada, que nao pode entrar no relatorio.
        using var contexto = _banco.NovoContexto();
        Pedido Venda(DateTime data, decimal valor, string status = PedidoService.StatusFinalizado) => new()
        {
            IdCliente = _banco.Cliente.IdCliente,
            DataPedido = data,
            TiposVenda = "Varejo",
            Status = status,
            ValorTotal = valor,
            Itens = { new ItemPedido { IdProduto = _banco.Jaqueta.IdProduto, Quantidade = 1, PrecoUnitario = valor } }
        };
        contexto.Pedidos.AddRange(
            Venda(new DateTime(2026, 10, 2), 100m),
            Venda(new DateTime(2026, 9, 15), 200m),
            Venda(new DateTime(2026, 10, 2, 15, 0, 0), 50m),
            Venda(new DateTime(2026, 10, 3), 999m, PedidoService.StatusCancelado));
        contexto.SaveChanges();
    }

    public void Dispose() => _banco.Dispose();

    private async Task<modamax.web.ViewModels.RelatorioViewModel> GerarAsync(DateTime? inicio = null, DateTime? fim = null)
    {
        using var contexto = _banco.NovoContexto();
        return await new RelatorioService(contexto).GerarAsync(inicio, fim);
    }

    [Fact]
    public async Task Vendas_por_dia_ficam_em_ordem_de_data_e_sem_cancelados()
    {
        var relatorio = await GerarAsync();

        // Antes a ordenacao era pelo texto "dd/MM/yyyy" e 02/10 vinha antes de 15/09.
        Assert.Equal(new[] { "15/09/2026", "02/10/2026" }, relatorio.VendasPorPeriodo.Select(v => v.Periodo));
        Assert.Equal(150m, relatorio.VendasPorPeriodo[1].Total);
        Assert.Equal(3, relatorio.TotalPedidos);
        Assert.Equal(350m, relatorio.Faturamento);
        Assert.Equal(116.67m, relatorio.TicketMedio);
    }

    [Fact]
    public async Task Datas_invertidas_no_filtro_sao_trocadas()
    {
        var relatorio = await GerarAsync(new DateTime(2026, 10, 31), new DateTime(2026, 10, 1));

        Assert.Equal(new DateTime(2026, 10, 1), relatorio.DataInicial);
        Assert.Equal(2, relatorio.TotalPedidos);
        Assert.Equal("01/10/2026 a 31/10/2026", relatorio.DescricaoPeriodo);
    }

    [Fact]
    public async Task Excel_tem_resumo_e_vendas_por_dia_com_os_mesmos_numeros_da_tela()
    {
        var relatorio = await GerarAsync();
        var bytes = new ExportacaoRelatorioService().GerarExcel(relatorio, "Usuario Teste");

        using var planilha = new XLWorkbook(new MemoryStream(bytes));
        Assert.Equal(new[] { "Resumo", "Mais vendidos", "Vendas por dia" }, planilha.Worksheets.Select(w => w.Name));

        var resumo = planilha.Worksheet("Resumo");
        Assert.Equal(350m, resumo.Cell("B6").GetValue<decimal>());

        var porDia = planilha.Worksheet("Vendas por dia");
        Assert.Equal(new DateTime(2026, 9, 15), porDia.Cell("A2").GetDateTime());
        Assert.Equal(150m, porDia.Cell("D3").GetValue<decimal>());
    }

    [Fact]
    public async Task Pdf_e_gerado()
    {
        var relatorio = await GerarAsync();
        var bytes = new ExportacaoRelatorioService().GerarPdf(relatorio, "Usuario Teste");

        Assert.True(bytes.Length > 1000);
        Assert.Equal("%PDF", System.Text.Encoding.ASCII.GetString(bytes, 0, 4));
    }

    [Fact]
    public void Nome_do_arquivo_indica_o_periodo()
    {
        var comPeriodo = new modamax.web.ViewModels.RelatorioViewModel { DataInicial = new DateTime(2026, 10, 1), DataFinal = new DateTime(2026, 10, 31) };

        Assert.Equal("relatorio-vendas-2026-10-01_2026-10-31.pdf", ExportacaoRelatorioService.NomeArquivo(comPeriodo, "pdf"));
        Assert.Equal("relatorio-vendas-geral.xlsx", ExportacaoRelatorioService.NomeArquivo(new(), "xlsx"));
    }
}
