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
        return new MetaDto(p.NomeMes, p.Definida, Indicador(p.Faturamento), Indicador(p.Pedidos), Indicador(p.Pecas),
            p.ProjecaoFaturamento, p.DiasRestantes);
    }

    // GET /api/metas?ano=2026&mes=10  (tela de metas do app: qualquer mes, com detalhes)
    [HttpGet("metas")]
    public async Task<ActionResult<MetaMesDto>> MetaDoMes(int? ano, int? mes)
    {
        var hoje = DateTime.Today;
        var a = ano ?? hoje.Year;
        var m = mes ?? hoje.Month;
        if (a < 2020 || a > 2100 || m < 1 || m > 12) return BadRequest(new { mensagem = "Mes invalido." });

        var inicio = new DateTime(a, m, 1);
        var inicioAtual = new DateTime(hoje.Year, hoje.Month, 1);
        var situacao = inicio == inicioAtual ? "atual" : inicio < inicioAtual ? "encerrado" : "futuro";

        var p = await _metas.ProgressoDoMesAsync(a, m);
        var anterior = await _metas.ProgressoDoMesAsync(inicio.AddMonths(-1).Year, inicio.AddMonths(-1).Month);
        var porDia = await _metas.FaturamentoPorDiaAsync(a, m);
        var maisVendidos = await _metas.MaisVendidosDoMesAsync(a, m);
        var sugestao = await _metas.SugerirAsync(a, m);
        var ticket = p.Pedidos.Realizado <= 0 ? 0 : Math.Round(p.Faturamento.Realizado / p.Pedidos.Realizado, 2, MidpointRounding.AwayFromZero);

        return new MetaMesDto(a, m, p.NomeMes, situacao, p.Definida,
            Indicador(p.Faturamento), Indicador(p.Pedidos), Indicador(p.Pecas),
            p.ProjecaoFaturamento, p.DiasNoMes, p.DiasDecorridos, p.DiasRestantes, p.NecessarioPorDia, ticket,
            Resumo(anterior),
            porDia.Select(d => new PontoGrafico(d.Dia.ToString(), d.Valor)).ToList(),
            maisVendidos.Select(v => new MaisVendidoDto(v.Produto, v.Pecas, v.Valor)).ToList(),
            new SalvarMetaDto(sugestao.Faturamento, sugestao.Pedidos, sugestao.Pecas),
            User.IsInRole("Estrategico") && situacao != "encerrado");
    }

    // GET /api/metas/historico?meses=12  (meses encerrados, do mais antigo ao mais recente)
    [HttpGet("metas/historico")]
    public async Task<ActionResult<IEnumerable<ResumoMesDto>>> HistoricoMetas(int meses = 12)
    {
        var lista = await _metas.HistoricoAsync(Math.Clamp(meses, 1, 24));
        return lista.Select(Resumo).ToList();
    }

    // PUT /api/metas/2026/11  (so a diretoria define metas; meses encerrados nao mudam)
    [HttpPut("metas/{ano:int}/{mes:int}")]
    [Authorize(Roles = "Estrategico")]
    public async Task<IActionResult> SalvarMeta(int ano, int mes, SalvarMetaDto dto)
    {
        if (ano < 2020 || ano > 2100 || mes < 1 || mes > 12) return BadRequest(new { mensagem = "Mes invalido." });
        var hoje = DateTime.Today;
        if (new DateTime(ano, mes, 1) < new DateTime(hoje.Year, hoje.Month, 1))
            return BadRequest(new { mensagem = "Nao e possivel alterar a meta de um mes encerrado." });

        await _metas.SalvarAsync(new Models.Meta { Ano = ano, Mes = mes, Faturamento = dto.Faturamento, Pedidos = dto.Pedidos, Pecas = dto.Pecas });
        var idTexto = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        _context.LogsSistema.Add(new Models.LogSistema
        {
            IdUsuario = int.TryParse(idTexto, out var id) ? id : null,
            Acao = $"Meta de {MetaService.NomeMes(ano, mes)} definida pelo app: {dto.Faturamento.ToString("C", new System.Globalization.CultureInfo("pt-BR"))}, {dto.Pedidos} pedidos, {dto.Pecas} peças.",
            Data = DateTime.Now
        });
        await _context.SaveChangesAsync();
        return NoContent();
    }

    private static IndicadorMetaDto Indicador(IndicadorMeta i) => new(i.Meta, i.Realizado, i.Percentual);

    private static ResumoMesDto Resumo(ProgressoMeta p) => new(p.Ano, p.Mes, p.NomeMes, p.Definida, p.Faturamento.Meta,
        p.Faturamento.Realizado, (int)p.Pedidos.Realizado, (int)p.Pecas.Realizado, p.Faturamento.Percentual);

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
