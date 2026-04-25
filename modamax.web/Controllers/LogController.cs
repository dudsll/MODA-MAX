using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;

namespace modamax.web.Controllers;

[RequireUser("Estrategico")]
public class LogController : Controller
{
    private readonly AppDbContext _context;

    public LogController(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IActionResult> Index()
    {
        var logs = await _context.LogsSistema
            .Include(l => l.Usuario)
            .OrderByDescending(l => l.Data)
            .ToListAsync();

        return View(logs);
    }
}
