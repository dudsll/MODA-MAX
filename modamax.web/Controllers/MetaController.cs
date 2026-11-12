using Microsoft.AspNetCore.Mvc;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;
using modamax.web.Services;

namespace modamax.web.Controllers;

public class MetasViewModel
{
    public ProgressoMeta Atual { get; set; } = default!;

    public List<ProgressoMeta> Historico { get; set; } = new();

    public Meta Formulario { get; set; } = new();

    public bool PodeEditar { get; set; }
}

public class MetaController : Controller
{
    private readonly MetaService _metas;
    private readonly AppDbContext _context;

    public MetaController(MetaService metas, AppDbContext context)
    {
        _metas = metas;
        _context = context;
    }

    [RequireUser("Estrategico", "Tatico", "Operacional")]
    public async Task<IActionResult> Index(int? ano, int? mes)
    {
        var hoje = DateTime.Today;
        var alvoAno = ano ?? hoje.Year;
        var alvoMes = mes is >= 1 and <= 12 ? mes.Value : hoje.Month;

        return View(new MetasViewModel
        {
            Atual = await _metas.ProgressoAsync(),
            Historico = await _metas.HistoricoAsync(),
            Formulario = await _metas.ObterOuSugerirAsync(alvoAno, alvoMes),
            PodeEditar = NivelAtual() == "Estrategico"
        });
    }

    // Somente a diretoria define as metas.
    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico")]
    public async Task<IActionResult> Salvar([Bind("Ano,Mes,Faturamento,Pedidos,Pecas")] Meta meta)
    {
        if (!ModelState.IsValid)
        {
            TempData["Erro"] = "Confira os valores da meta.";
            return RedirectToAction(nameof(Index), new { meta.Ano, meta.Mes });
        }

        await _metas.SalvarAsync(meta);
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext,
            $"Meta de {MetaService.NomeMes(meta.Ano, meta.Mes)} definida: {meta.Faturamento:C}, {meta.Pedidos} pedidos, {meta.Pecas} peças.");
        TempData["Mensagem"] = $"Meta de {MetaService.NomeMes(meta.Ano, meta.Mes)} salva.";
        return RedirectToAction(nameof(Index));
    }

    private string NivelAtual() =>
        (HttpContext.Session.GetString("UsuarioNivel") ?? "").Replace("é", "e").Replace("á", "a");
}
