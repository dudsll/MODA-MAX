using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Dtos;

namespace modamax.web.Controllers.Api;

// Endpoints de apoio: categorias, painel e relatorios.
[ApiController]
[Route("api")]
[Authorize]
public class GestaoApiController : ControllerBase
{
    private readonly AppDbContext _context;

    public GestaoApiController(AppDbContext context)
    {
        _context = context;
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
            await _context.Pedidos.Where(p => p.Status != "Cancelado").SumAsync(p => (decimal?)p.ValorTotal) ?? 0m,
            await _context.Produtos.CountAsync(p => p.Estoque <= 15));
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
