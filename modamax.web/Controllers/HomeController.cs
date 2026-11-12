using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;
using modamax.web.Services;
using modamax.web.ViewModels;

namespace modamax.web.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly AppDbContext _context;
    private readonly DashboardService _dashboardService;
    private readonly MetaService _metas;
    private readonly ReposicaoService _reposicao;

    public HomeController(ILogger<HomeController> logger, AppDbContext context, DashboardService dashboardService,
        MetaService metas, ReposicaoService reposicao)
    {
        _logger = logger;
        _context = context;
        _dashboardService = dashboardService;
        _metas = metas;
        _reposicao = reposicao;
    }

    [RequireUser("Estrategico", "Tatico", "Operacional")]
    public async Task<IActionResult> Index()
    {
        var agora = DateTime.Now;
        var hoje = agora.Date;
        var inicioMes = new DateTime(hoje.Year, hoje.Month, 1);
        var inicioAnterior = inicioMes.AddMonths(-1);
        // Mesmo periodo do mes anterior (ex.: dias 1 a 11), para a comparacao ser justa.
        var fimAnterior = inicioAnterior.AddDays(Math.Min(hoje.Day, DateTime.DaysInMonth(inicioAnterior.Year, inicioAnterior.Month)));

        var vendas = await _context.Pedidos.AsNoTracking()
            .Where(p => p.Status != PedidoService.StatusCancelado && p.DataPedido >= inicioAnterior)
            .Select(p => new { p.DataPedido, p.ValorTotal })
            .ToListAsync();
        var doMes = vendas.Where(v => v.DataPedido >= inicioMes).ToList();
        var anterior = vendas.Where(v => v.DataPedido >= inicioAnterior && v.DataPedido < fimAnterior).ToList();

        var pendentes = await _context.Pedidos.AsNoTracking()
            .Where(p => p.Status != PedidoService.StatusCancelado && p.StatusPagamento == Pagamentos.Pendente)
            .Select(p => p.ValorTotal)
            .ToListAsync();

        var reposicao = await _reposicao.CalcularAsync();
        var nome = HttpContext.Session.GetString("UsuarioNome") ?? string.Empty;
        var nivel = HttpContext.Session.GetString("UsuarioNivel") ?? string.Empty;

        var viewModel = new DashboardViewModel
        {
            Saudacao = agora.Hour < 12 ? "Bom dia" : agora.Hour < 18 ? "Boa tarde" : "Boa noite",
            PrimeiroNome = nome.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? nome,
            TotalProdutos = await _context.Produtos.CountAsync(),
            TotalClientes = await _context.Clientes.CountAsync(),
            TotalPedidos = await _context.Pedidos.CountAsync(),
            TotalUsuarios = await _context.Usuarios.CountAsync(),
            FaturamentoTotal = (await _context.Pedidos.Where(p => p.Status != PedidoService.StatusCancelado).Select(p => p.ValorTotal).ToListAsync()).Sum(),
            FaturamentoMes = new IndicadorPainel(doMes.Sum(v => v.ValorTotal), anterior.Sum(v => v.ValorTotal)),
            PedidosMes = new IndicadorPainel(doMes.Count, anterior.Count),
            TicketMedioMes = new IndicadorPainel(
                doMes.Count == 0 ? 0 : Math.Round(doMes.Sum(v => v.ValorTotal) / doMes.Count, 2),
                anterior.Count == 0 ? 0 : Math.Round(anterior.Sum(v => v.ValorTotal) / anterior.Count, 2)),
            AReceber = pendentes.Sum(),
            PedidosAReceber = pendentes.Count,
            ProdutosAbaixoDoMinimo = reposicao.Count(r => r.Situacao != SituacaoReposicao.Ok),
            ParaRepor = reposicao.Where(r => r.Situacao != SituacaoReposicao.Ok).Take(4).ToList(),
            Meta = await _metas.ProgressoAsync(),
            PedidosRecentes = await _context.Pedidos
                .Include(p => p.Cliente)
                .OrderByDescending(p => p.DataPedido)
                .Take(6)
                .ToListAsync(),
            LogsRecentes = nivel == "Estrategico"
                ? await _context.LogsSistema.Include(l => l.Usuario).OrderByDescending(l => l.Data).Take(5).ToListAsync()
                : new List<LogSistema>(),
            Graficos = await _dashboardService.GerarGraficosAsync()
        };

        return View(viewModel);
    }

    [RequireUser("Estrategico", "Tatico")]
    public IActionResult Privacy()
    {
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
