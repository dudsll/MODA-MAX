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

    private string UsuarioAtual() => HttpContext.Session.GetString("UsuarioNome") ?? "Usuário do sistema";
}
