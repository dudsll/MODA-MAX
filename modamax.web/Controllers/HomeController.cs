using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
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
            FaturamentoTotal = faturamentoTotal,
            ProdutosComMenorEstoque = await _context.Produtos
                .Include(p => p.Categoria)
                .OrderBy(p => p.Estoque)
                .Take(5)
                .ToListAsync(),
            PedidosRecentes = await _context.Pedidos
                .Include(p => p.Cliente)
                .OrderByDescending(p => p.DataPedido)
                .Take(5)
                .ToListAsync()
        };

        return View(viewModel);
    }

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
