using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Dtos;
using modamax.web.Services;

namespace modamax.web.Controllers.Api;

// Endpoints de apoio: categorias, painel e relatorios.
[ApiController]
[Route("api")]
[Authorize]
public class GestaoApiController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly DashboardService _dashboardService;

    public GestaoApiController(AppDbContext context, DashboardService dashboardService)
    {
        _context = context;
        _dashboardService = dashboardService;
    }

    // GET /api/categorias
    [HttpGet("categorias")]
    public async Task<ActionResult<IEnumerable<CategoriaDto>>> Categorias()
    {
        return await _context.Categorias
            .AsNoTracking()
            .OrderBy(c => c.Nome)
            .Select(c => new CategoriaDto(c.IdCategoria, c.Nome))
            .ToListAsync();
    }

    // GET /api/dashboard
    [HttpGet("dashboard")]
    public async Task<ActionResult<DashboardDto>> Dashboard()
    {
        return new DashboardDto(
            await _context.Produtos.CountAsync(),
            await _context.Clientes.CountAsync(),
            await _context.Pedidos.CountAsync(),
            (await _context.Pedidos.Where(p => p.Status != "Cancelado").Select(p => p.ValorTotal).ToListAsync()).Sum(),
            await _context.Produtos.CountAsync(p => p.Estoque <= 15));
    }

    // GET /api/dashboard/graficos  (mesmos dados dos graficos do painel Web)
    [HttpGet("dashboard/graficos")]
    public async Task<ActionResult<GraficosDashboard>> Graficos()
    {
        return await _dashboardService.GerarGraficosAsync();
    }

    // GET /api/relatorios/vendas?dataInicial=2026-06-01&dataFinal=2026-06-30  (procedure sp_RelatorioVendasPeriodo)
    [HttpGet("relatorios/vendas")]
    [Authorize(Roles = "Estrategico,Tatico")]
    public async Task<ActionResult<IEnumerable<VendaPeriodoDto>>> Vendas(DateTime? dataInicial, DateTime? dataFinal)
    {
        var inicio = (dataInicial ?? DateTime.Today.AddDays(-30)).Date;
        var fim = (dataFinal ?? DateTime.Today).Date;

        return await _context.Database
            .SqlQuery<VendaPeriodoDto>($"EXEC dbo.sp_RelatorioVendasPeriodo @DataInicial = {inicio}, @DataFinal = {fim}")
            .ToListAsync();
    }
}
