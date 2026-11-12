using System.Globalization;
using ClosedXML.Excel;
using modamax.web.ViewModels;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace modamax.web.Services;

// Gera os arquivos do relatorio de vendas: Excel (ClosedXML) e PDF (QuestPDF).
public class ExportacaoRelatorioService
{
    public const string TipoExcel = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    public const string TipoPdf = "application/pdf";

    private const string FormatoMoeda = "\"R$\" #,##0.00";
    private const string CorMarca = "#8C3F2F";
    private static readonly CultureInfo PtBr = new("pt-BR");

    static ExportacaoRelatorioService()
    {
        // Licenca Community do QuestPDF: gratuita para projetos academicos e empresas pequenas.
        QuestPDF.Settings.License = LicenseType.Community;
    }

    public static string NomeArquivo(RelatorioViewModel relatorio, string extensao)
    {
        var periodo = relatorio.DataInicial.HasValue || relatorio.DataFinal.HasValue
            ? $"{relatorio.DataInicial:yyyy-MM-dd}_{relatorio.DataFinal:yyyy-MM-dd}".Trim('_')
            : "geral";
        return $"relatorio-vendas-{periodo}.{extensao}";
    }

    public byte[] GerarExcel(RelatorioViewModel relatorio, string emitidoPor)
    {
        using var planilha = new XLWorkbook();

        var resumo = planilha.Worksheets.Add("Resumo");
        resumo.Cell("A1").Value = "ModaMax – Relatório de vendas";
        resumo.Cell("A1").Style.Font.SetBold().Font.SetFontSize(14).Font.SetFontColor(XLColor.FromHtml(CorMarca));
        var linhasResumo = new (string Rotulo, XLCellValue Valor, string? Formato)[]
        {
            ("Período", relatorio.DescricaoPeriodo, null),
            ("Pedidos (sem cancelados)", relatorio.TotalPedidos, null),
            ("Peças vendidas", relatorio.TotalItens, null),
            ("Faturamento", relatorio.Faturamento, FormatoMoeda),
            ("Ticket médio", relatorio.TicketMedio, FormatoMoeda),
            ("Emitido por", emitidoPor, null),
            ("Emitido em", DateTime.Now, "dd/mm/yyyy hh:mm")
        };
        for (var i = 0; i < linhasResumo.Length; i++)
        {
            var (rotulo, valor, formato) = linhasResumo[i];
            resumo.Cell(i + 3, 1).Value = rotulo;
            resumo.Cell(i + 3, 1).Style.Font.SetBold();
            resumo.Cell(i + 3, 2).Value = valor;
            resumo.Cell(i + 3, 2).Style.Alignment.SetHorizontal(XLAlignmentHorizontalValues.Left);
            if (formato != null) resumo.Cell(i + 3, 2).Style.NumberFormat.Format = formato;
        }
        resumo.Column(1).Width = 26;
        resumo.Column(2).Width = 30;

        var maisVendidos = planilha.Worksheets.Add("Mais vendidos");
        Tabela(maisVendidos, new[] { "Produto", "Quantidade", "Faturamento" },
            relatorio.ProdutosMaisVendidos.Select(p => new XLCellValue[] { p.Produto, p.QuantidadeVendida, p.Faturamento }),
            new[] { 34.0, 14, 18 }, colunaMoeda: 3);

        var porDia = planilha.Worksheets.Add("Vendas por dia");
        Tabela(porDia, new[] { "Data", "Pedidos", "Peças", "Total" },
            relatorio.VendasPorPeriodo.Select(v => new XLCellValue[] { v.Data, v.Pedidos, v.Itens, v.Total }),
            new[] { 14.0, 12, 12, 18 }, colunaMoeda: 4);
        porDia.Column(1).Style.NumberFormat.Format = "dd/mm/yyyy";

        using var memoria = new MemoryStream();
        planilha.SaveAs(memoria);
        return memoria.ToArray();
    }

    // Pedido de compra sugerido pela central de reposicao, uma aba por fornecedor.
    public byte[] GerarExcelPedidoCompra(IReadOnlyList<SugestaoReposicao> itens)
    {
        using var planilha = new XLWorkbook();
        var resumo = planilha.Worksheets.Add("Resumo");
        resumo.Cell("A1").Value = "ModaMax – Pedido de compra sugerido";
        resumo.Cell("A1").Style.Font.SetBold().Font.SetFontSize(14).Font.SetFontColor(XLColor.FromHtml(CorMarca));
        resumo.Cell("A2").Value = $"Gerado em {DateTime.Now:dd/MM/yyyy HH:mm} pela central de reposição";
        Tabela(resumo, new[] { "Fornecedor", "Produtos", "Peças" },
            itens.GroupBy(i => i.Fornecedor ?? "Sem fornecedor")
                .Select(g => new XLCellValue[] { g.Key, g.Count(), g.Sum(i => i.QuantidadeSugerida) }),
            new[] { 30.0, 12, 12 }, colunaMoeda: 0, linhaInicial: 4);

        foreach (var fornecedor in itens.GroupBy(i => i.Fornecedor ?? "Sem fornecedor"))
        {
            var nomeAba = new string(fornecedor.Key.Where(c => !"[]*?/\\:".Contains(c)).Take(31).ToArray());
            var aba = planilha.Worksheets.Add(nomeAba);
            Tabela(aba, new[] { "Produto", "Categoria", "Estoque", "Vendidos no período", "Dias de cobertura", "Comprar" },
                fornecedor.Select(i => new XLCellValue[]
                {
                    i.Produto, i.Categoria ?? "", i.Estoque, i.VendidosNoPeriodo,
                    i.DiasDeCobertura.HasValue ? (XLCellValue)i.DiasDeCobertura.Value : "sem giro", i.QuantidadeSugerida
                }),
                new[] { 30.0, 16, 10, 20, 18, 12 }, colunaMoeda: 0);
        }

        using var memoria = new MemoryStream();
        planilha.SaveAs(memoria);
        return memoria.ToArray();
    }

    // Curva ABC em planilha, com participacao e acumulado em percentual.
    public byte[] GerarExcelCurvaAbc(IReadOnlyList<ItemCurvaAbc> itens, string periodo)
    {
        using var planilha = new XLWorkbook();
        var aba = planilha.Worksheets.Add("Curva ABC");
        Tabela(aba, new[] { "Classe", "Produto", "Categoria", "Peças", "Faturamento", "Participação (%)", "Acumulado (%)" },
            itens.Select(i => new XLCellValue[] { i.Classe.ToString(), i.Produto, i.Categoria ?? "", i.Quantidade, i.Faturamento, i.Participacao, i.Acumulado }),
            new[] { 9.0, 30, 16, 10, 16, 16, 16 }, colunaMoeda: 5);
        aba.Column(6).Style.NumberFormat.Format = "0.00";
        aba.Column(7).Style.NumberFormat.Format = "0.00";
        var info = planilha.Worksheets.Add("Sobre");
        info.Cell("A1").Value = $"Curva ABC de produtos – {periodo}";
        info.Cell("A2").Value = "A: produtos que somam até 80% do faturamento; B: até 95%; C: o restante.";
        info.Column(1).Width = 80;

        using var memoria = new MemoryStream();
        planilha.SaveAs(memoria);
        return memoria.ToArray();
    }

    // Cria uma tabela do Excel (com filtro e linhas zebradas) a partir das linhas informadas.
    // colunaMoeda = 0 quando a tabela nao tem coluna de valores em reais.
    private static void Tabela(IXLWorksheet aba, string[] cabecalho, IEnumerable<XLCellValue[]> linhas, double[] larguras, int colunaMoeda, int linhaInicial = 1)
    {
        for (var c = 0; c < cabecalho.Length; c++)
        {
            aba.Cell(linhaInicial, c + 1).Value = cabecalho[c];
            aba.Column(c + 1).Width = larguras[c];
        }

        var linha = linhaInicial + 1;
        foreach (var valores in linhas)
        {
            for (var c = 0; c < valores.Length; c++)
            {
                aba.Cell(linha, c + 1).Value = valores[c];
            }
            linha++;
        }

        // Uma tabela do Excel precisa de ao menos uma linha de dados.
        var ultimaLinha = Math.Max(linha - 1, linhaInicial + 1);
        var intervalo = aba.Range(linhaInicial, 1, ultimaLinha, cabecalho.Length);
        intervalo.CreateTable().Theme = XLTableTheme.TableStyleMedium3;
        if (colunaMoeda > 0)
        {
            aba.Column(colunaMoeda).Style.NumberFormat.Format = FormatoMoeda;
        }
        aba.SheetView.FreezeRows(linhaInicial);
    }

    public byte[] GerarPdf(RelatorioViewModel relatorio, string emitidoPor)
    {
        var emitidoEm = DateTime.Now;

        return Document.Create(documento =>
        {
            documento.Page(pagina =>
            {
                pagina.Size(PageSizes.A4);
                pagina.Margin(1.8f, Unit.Centimetre);
                pagina.DefaultTextStyle(t => t.FontSize(10));

                pagina.Header().PaddingBottom(12).Row(linha =>
                {
                    linha.RelativeItem().Column(coluna =>
                    {
                        coluna.Item().Text("ModaMax").FontSize(20).Bold().FontColor(CorMarca);
                        coluna.Item().Text("Relatório de vendas").FontSize(13).SemiBold();
                        coluna.Item().Text($"Período: {relatorio.DescricaoPeriodo}").FontColor(Colors.Grey.Darken2);
                    });
                    linha.ConstantItem(170).AlignRight().Column(coluna =>
                    {
                        coluna.Item().AlignRight().Text($"Emitido em {emitidoEm:dd/MM/yyyy HH:mm}").FontSize(9);
                        coluna.Item().AlignRight().Text($"por {emitidoPor}").FontSize(9);
                    });
                });

                pagina.Content().Column(coluna =>
                {
                    coluna.Spacing(14);

                    coluna.Item().Row(linha =>
                    {
                        linha.Spacing(8);
                        Indicador(linha.RelativeItem(), "Pedidos", relatorio.TotalPedidos.ToString("N0", PtBr));
                        Indicador(linha.RelativeItem(), "Peças vendidas", relatorio.TotalItens.ToString("N0", PtBr));
                        Indicador(linha.RelativeItem(), "Faturamento", relatorio.Faturamento.ToString("C", PtBr));
                        Indicador(linha.RelativeItem(), "Ticket médio", relatorio.TicketMedio.ToString("C", PtBr));
                    });

                    coluna.Item().Text("Produtos mais vendidos").FontSize(12).Bold();
                    coluna.Item().Table(tabela =>
                    {
                        tabela.ColumnsDefinition(c =>
                        {
                            c.RelativeColumn(4);
                            c.RelativeColumn(2);
                            c.RelativeColumn(2);
                        });
                        Cabecalho(tabela, "Produto", "Quantidade", "Faturamento");
                        foreach (var item in relatorio.ProdutosMaisVendidos)
                        {
                            Celula(tabela, item.Produto);
                            Celula(tabela, item.QuantidadeVendida.ToString("N0", PtBr), direita: true);
                            Celula(tabela, item.Faturamento.ToString("C", PtBr), direita: true);
                        }
                    });

                    coluna.Item().Text("Vendas por dia").FontSize(12).Bold();
                    coluna.Item().Table(tabela =>
                    {
                        tabela.ColumnsDefinition(c =>
                        {
                            c.RelativeColumn(2);
                            c.RelativeColumn(2);
                            c.RelativeColumn(2);
                            c.RelativeColumn(2);
                        });
                        Cabecalho(tabela, "Data", "Pedidos", "Peças", "Total");
                        foreach (var dia in relatorio.VendasPorPeriodo)
                        {
                            Celula(tabela, dia.Periodo);
                            Celula(tabela, dia.Pedidos.ToString("N0", PtBr), direita: true);
                            Celula(tabela, dia.Itens.ToString("N0", PtBr), direita: true);
                            Celula(tabela, dia.Total.ToString("C", PtBr), direita: true);
                        }
                    });

                    if (relatorio.TotalPedidos == 0)
                    {
                        coluna.Item().Text("Nenhuma venda no período selecionado.").Italic().FontColor(Colors.Grey.Darken1);
                    }
                });

                pagina.Footer().AlignCenter().Text(texto =>
                {
                    texto.DefaultTextStyle(t => t.FontSize(8).FontColor(Colors.Grey.Darken1));
                    texto.Span("ModaMax · pedidos cancelados não entram no relatório · página ");
                    texto.CurrentPageNumber();
                    texto.Span(" de ");
                    texto.TotalPages();
                });
            });
        }).GeneratePdf();
    }

    private static void Indicador(IContainer container, string rotulo, string valor)
    {
        container.Border(1).BorderColor(Colors.Grey.Lighten2).Background(Colors.Grey.Lighten5).Padding(8).Column(c =>
        {
            c.Item().Text(rotulo).FontSize(8).FontColor(Colors.Grey.Darken2);
            c.Item().Text(valor).FontSize(13).Bold();
        });
    }

    private static void Cabecalho(TableDescriptor tabela, params string[] titulos)
    {
        tabela.Header(cabecalho =>
        {
            for (var i = 0; i < titulos.Length; i++)
            {
                var celula = cabecalho.Cell().Background(CorMarca).Padding(5);
                (i == 0 ? celula : celula.AlignRight()).Text(titulos[i]).FontColor(Colors.White).SemiBold();
            }
        });
    }

    private static void Celula(TableDescriptor tabela, string texto, bool direita = false)
    {
        var celula = tabela.Cell().BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingVertical(4).PaddingHorizontal(5);
        (direita ? celula.AlignRight() : celula).Text(texto);
    }
}
