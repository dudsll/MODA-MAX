using Microsoft.AspNetCore.Mvc;
using modamax.web.Filters;
using modamax.web.Services;
using ModaMax.Web.Data;

namespace modamax.web.Controllers;

[RequireUser("Estrategico", "Tatico")]
public class RelatorioController : Controller
{
    private readonly AppDbContext _context;
    private readonly RelatorioService _relatorios;
    private readonly ExportacaoRelatorioService _exportacao;

    public RelatorioController(AppDbContext context, RelatorioService relatorios, ExportacaoRelatorioService exportacao)
    {
        _context = context;
        _relatorios = relatorios;
        _exportacao = exportacao;
    }

    public async Task<IActionResult> Index(DateTime? dataInicial, DateTime? dataFinal)
    {
        return View(await _relatorios.GerarAsync(dataInicial, dataFinal));
    }

    // Mesmo filtro da tela, baixado como planilha .xlsx
    public async Task<IActionResult> ExportarExcel(DateTime? dataInicial, DateTime? dataFinal)
    {
        var relatorio = await _relatorios.GerarAsync(dataInicial, dataFinal);
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Relatório de vendas exportado em Excel ({relatorio.DescricaoPeriodo}).");
        return File(_exportacao.GerarExcel(relatorio, UsuarioAtual()), ExportacaoRelatorioService.TipoExcel,
            ExportacaoRelatorioService.NomeArquivo(relatorio, "xlsx"));
    }

    public async Task<IActionResult> ExportarPdf(DateTime? dataInicial, DateTime? dataFinal)
    {
        var relatorio = await _relatorios.GerarAsync(dataInicial, dataFinal);
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Relatório de vendas exportado em PDF ({relatorio.DescricaoPeriodo}).");
        return File(_exportacao.GerarPdf(relatorio, UsuarioAtual()), ExportacaoRelatorioService.TipoPdf,
            ExportacaoRelatorioService.NomeArquivo(relatorio, "pdf"));
    }

    public async Task<IActionResult> CurvaAbc(DateTime? dataInicial, DateTime? dataFinal)
    {
        var relatorio = new modamax.web.ViewModels.RelatorioViewModel { DataInicial = dataInicial, DataFinal = dataFinal };
        ViewBag.Periodo = relatorio.DescricaoPeriodo;
        ViewBag.DataInicial = dataInicial;
        ViewBag.DataFinal = dataFinal;
        return View(await _relatorios.CurvaAbcAsync(dataInicial, dataFinal));
    }

    public async Task<IActionResult> ExportarCurvaAbc(DateTime? dataInicial, DateTime? dataFinal)
    {
        var periodo = new modamax.web.ViewModels.RelatorioViewModel { DataInicial = dataInicial, DataFinal = dataFinal }.DescricaoPeriodo;
        var itens = await _relatorios.CurvaAbcAsync(dataInicial, dataFinal);
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Curva ABC exportada em Excel ({periodo}).");
        return File(_exportacao.GerarExcelCurvaAbc(itens, periodo), ExportacaoRelatorioService.TipoExcel, "curva-abc.xlsx");
    }

    private string UsuarioAtual() => HttpContext.Session.GetString("UsuarioNome") ?? "Usuário do sistema";
}
