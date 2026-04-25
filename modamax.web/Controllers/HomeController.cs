using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;
using modamax.web.ViewModels;

namespace modamax.web.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly AppDbContext _context;

    public HomeController(ILogger<HomeController> logger, AppDbContext context)
    {
        _logger = logger;
        _context = context;
    }

    [RequireUser("Estrategico", "Tatico", "Operacional")]
    public async Task<IActionResult> Index()
    {
        var faturamentoTotal = (await _context.Pedidos
            .Select(p => p.ValorTotal)
            .ToListAsync())
            .Sum();

        var viewModel = new DashboardViewModel
        {
            TotalProdutos = await _context.Produtos.CountAsync(),
            TotalClientes = await _context.Clientes.CountAsync(),
            TotalPedidos = await _context.Pedidos.CountAsync(),
            TotalUsuarios = await _context.Usuarios.CountAsync(),
            FaturamentoTotal = faturamentoTotal,
            ProdutosAbaixoDoMinimo = await _context.Produtos.CountAsync(p => p.Estoque <= 15),
            ProdutosComMenorEstoque = await _context.Produtos
                .Include(p => p.Categoria)
                .OrderBy(p => p.Estoque)
                .Take(5)
                .ToListAsync(),
            PedidosRecentes = await _context.Pedidos
                .Include(p => p.Cliente)
                .OrderByDescending(p => p.DataPedido)
                .Take(5)
                .ToListAsync(),
            LogsRecentes = await _context.LogsSistema
                .Include(l => l.Usuario)
                .OrderByDescending(l => l.Data)
                .Take(5)
                .ToListAsync()
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
