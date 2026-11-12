using Microsoft.AspNetCore.Mvc;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Services;

namespace modamax.web.Controllers;

public class ReposicaoController : Controller
{
    private readonly ReposicaoService _reposicao;
    private readonly ExportacaoRelatorioService _exportacao;
    private readonly AppDbContext _context;

    public ReposicaoController(ReposicaoService reposicao, ExportacaoRelatorioService exportacao, AppDbContext context)
    {
        _reposicao = reposicao;
        _exportacao = exportacao;
        _context = context;
    }

    [RequireUser("Estrategico", "Tatico", "Operacional")]
    public async Task<IActionResult> Index()
    {
        ViewBag.Opcoes = _reposicao.Opcoes;
        ViewBag.PodeRegistrar = (HttpContext.Session.GetString("UsuarioNivel") ?? "") != "Operacional";
        return View(await _reposicao.CalcularAsync());
    }

    // Entrada de mercadoria direto da central (gerencia e diretoria).
    [HttpPost]
    [ValidateAntiForgeryToken]
    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> Entrada(int idProduto, int quantidade)
    {
        if (quantidade <= 0)
        {
            TempData["Erro"] = "Informe uma quantidade maior que zero.";
            return RedirectToAction(nameof(Index));
        }

        var estoque = await _reposicao.RegistrarEntradaAsync(idProduto, quantidade, "Reposição pela central de reposição");
        if (estoque == null) return NotFound();

        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Entrada de {quantidade} peças no produto #{idProduto} pela central de reposição.");
        TempData["Mensagem"] = $"Entrada registrada. Estoque atual: {estoque} peças.";
        return RedirectToAction(nameof(Index));
    }

    // Pedido de compra sugerido, agrupado por fornecedor, em Excel.
    [RequireUser("Estrategico", "Tatico")]
    public async Task<IActionResult> ExportarPedidoCompra()
    {
        var itens = (await _reposicao.CalcularAsync()).Where(s => s.QuantidadeSugerida > 0).ToList();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, "Pedido de compra sugerido exportado em Excel.");
        return File(_exportacao.GerarExcelPedidoCompra(itens), ExportacaoRelatorioService.TipoExcel,
            $"pedido-de-compra-{DateTime.Today:yyyy-MM-dd}.xlsx");
    }
}
