using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Models;

namespace modamax.web.Controllers;

[RequireUser("Estrategico", "Tatico", "Operacional")]
public class ClienteController : Controller
{
    private readonly AppDbContext _context;

    public ClienteController(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IActionResult> Index()
    {
        return View(await _context.Clientes.OrderBy(c => c.Nome).ToListAsync());
    }

    public async Task<IActionResult> Details(int? id)
    {
        if (id == null)
        {
            return NotFound();
        }

        var cliente = await _context.Clientes
            .Include(c => c.Pedidos.OrderByDescending(p => p.DataPedido))
            .FirstOrDefaultAsync(m => m.IdCliente == id);

        if (cliente == null)
        {
            return NotFound();
        }

        return View(cliente);
    }

    public IActionResult Create()
    {
        return View(new Cliente());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create([Bind("IdCliente,Nome,Tipo,Documento,Email,Telefone,Endereco")] Cliente cliente)
    {
        if (!ModelState.IsValid)
        {
            return View(cliente);
        }

        _context.Add(cliente);
        await _context.SaveChangesAsync();
        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Cliente cadastrado: {cliente.Nome}.");
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(int? id)
    {
        if (id == null)
        {
            return NotFound();
        }

        var cliente = await _context.Clientes.FindAsync(id);
        if (cliente == null)
        {
            return NotFound();
        }

        return View(cliente);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, [Bind("IdCliente,Nome,Tipo,Documento,Email,Telefone,Endereco")] Cliente cliente)
    {
        if (id != cliente.IdCliente)
        {
            return NotFound();
        }

        if (!ModelState.IsValid)
        {
            return View(cliente);
        }

        try
        {
            _context.Update(cliente);
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!ClienteExists(cliente.IdCliente))
            {
                return NotFound();
            }

            throw;
        }

        await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Cliente alterado: {cliente.Nome}.");
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Delete(int? id)
    {
        if (id == null)
        {
            return NotFound();
        }

        var cliente = await _context.Clientes.FirstOrDefaultAsync(m => m.IdCliente == id);
        if (cliente == null)
        {
            return NotFound();
        }

        return View(cliente);
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        var cliente = await _context.Clientes.FindAsync(id);
        if (cliente != null)
        {
            _context.Clientes.Remove(cliente);
            await _context.SaveChangesAsync();
            await AuditoriaHelper.RegistrarAsync(_context, HttpContext, $"Cliente removido: {cliente.Nome}.");
        }

        return RedirectToAction(nameof(Index));
    }

    private bool ClienteExists(int id)
    {
        return _context.Clientes.Any(e => e.IdCliente == id);
    }
}
