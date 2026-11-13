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
    private readonly MetaService _metas;
    private readonly ReposicaoService _reposicao;

    public GestaoApiController(AppDbContext context, DashboardService dashboardService, MetaService metas, ReposicaoService reposicao)
    {
        _context = context;
        _dashboardService = dashboardService;
        _metas = metas;
        _reposicao = reposicao;
    }

    // GET /api/metas/atual  (aneis de meta do mes no app)
    [HttpGet("metas/atual")]
    public async Task<ActionResult<MetaDto>> MetaAtual()
    {
        var p = await _metas.ProgressoAsync();
        static IndicadorMetaDto Indicador(IndicadorMeta i) => new(i.Meta, i.Realizado, i.Percentual);
        return new MetaDto(p.NomeMes, p.Definida, Indicador(p.Faturamento), Indicador(p.Pedidos), Indicador(p.Pecas),
            p.ProjecaoFaturamento, p.DiasRestantes);
    }

    // GET /api/reposicao  (central de reposicao: criticos primeiro)
    [HttpGet("reposicao")]
    public async Task<ActionResult<IEnumerable<ReposicaoDto>>> Reposicao()
    {
        return (await _reposicao.CalcularAsync())
            .Select(s => new ReposicaoDto(s.IdProduto, s.Produto, s.Categoria, s.FotoUrl, s.Estoque, s.VendidosNoPeriodo,
                s.DiasDeCobertura, s.QuantidadeSugerida, s.Situacao.ToString()))
            .ToList();
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

    // GET /api/fornecedores  (formulario de produto do app)
    [HttpGet("fornecedores")]
    public async Task<ActionResult<IEnumerable<FornecedorDto>>> Fornecedores()
    {
        return await _context.Fornecedores
            .AsNoTracking()
            .OrderBy(f => f.Nome)
            .Select(f => new FornecedorDto(f.IdFornecedor, f.Nome))
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
            (await _reposicao.CalcularAsync()).Count(s => s.Situacao != SituacaoReposicao.Ok));
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
