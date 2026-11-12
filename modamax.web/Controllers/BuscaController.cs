using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Filters;
using modamax.web.Services;

namespace modamax.web.Controllers;

public record ResultadoBusca(string Titulo, string Subtitulo, string Url, string Icone, string? Foto = null);

public record GrupoBusca(string Titulo, IReadOnlyList<ResultadoBusca> Itens);

// Busca global (Cmd/Ctrl + K): produtos, clientes e pedidos em uma so consulta.
[RequireUser("Estrategico", "Tatico", "Operacional")]
public class BuscaController : Controller
{
    private const int Limite = 5;
    private readonly AppDbContext _context;

    public BuscaController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("/Busca")]
    public async Task<IActionResult> Index(string? q)
    {
        var termo = (q ?? string.Empty).Trim();
        if (termo.Length < 2)
        {
            return Json(new { grupos = Array.Empty<GrupoBusca>() });
        }

        var codigo = CodigoBarras.Normalizar(termo);
        // LIKE ignora maiusculas/minusculas no SQL Server e no SQLite ("jaq" encontra "Jaqueta").
        var padrao = $"%{termo.Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]")}%";
        if (!_context.Database.IsSqlServer())
        {
            // O SQLite nao entende colchetes no LIKE: ali os curingas sao apenas removidos.
            padrao = $"%{termo.Replace("%", "").Replace("_", "")}%";
        }
        var numero = int.TryParse(termo.TrimStart('#'), out var n) ? n : (int?)null;

        var produtos = (await _context.Produtos.AsNoTracking()
                .Where(p => EF.Functions.Like(p.Nome, padrao) || p.CodigoBarras == codigo || EF.Functions.Like(p.Categoria!.Nome, padrao))
                .OrderBy(p => p.Nome)
                .Take(Limite)
                .Select(p => new { p.IdProduto, p.Nome, p.Tamanho, p.Estoque, p.Preco, p.FotoUrl })
                .ToListAsync())
            .Select(p => new ResultadoBusca(p.Nome, $"Tam. {p.Tamanho} · {p.Preco:C} · {p.Estoque} em estoque",
                Url.Action("Details", "Produto", new { id = p.IdProduto })!, "i-shirt", p.FotoUrl))
            .ToList();

        var clientes = (await _context.Clientes.AsNoTracking()
                .Where(c => EF.Functions.Like(c.Nome, padrao) || EF.Functions.Like(c.Documento, padrao) || EF.Functions.Like(c.Email, padrao))
                .OrderBy(c => c.Nome)
                .Take(Limite)
                .Select(c => new { c.IdCliente, c.Nome, c.Tipo, c.Email })
                .ToListAsync())
            .Select(c => new ResultadoBusca(c.Nome, $"{(c.Tipo == "PJ" ? "Atacado (PJ)" : "Varejo (PF)")} · {c.Email}",
                Url.Action("Details", "Cliente", new { id = c.IdCliente })!, "i-users"))
            .ToList();

        var pedidos = (await _context.Pedidos.AsNoTracking()
                .Where(p => p.IdPedido == numero || EF.Functions.Like(p.Cliente!.Nome, padrao))
                .OrderByDescending(p => p.DataPedido)
                .Take(Limite)
                .Select(p => new { p.IdPedido, Cliente = p.Cliente!.Nome, p.DataPedido, p.ValorTotal, p.Status })
                .ToListAsync())
            .Select(p => new ResultadoBusca($"Pedido #{p.IdPedido} · {p.Cliente}", $"{p.DataPedido:dd/MM/yyyy} · {p.ValorTotal:C} · {p.Status}",
                Url.Action("Details", "Pedido", new { id = p.IdPedido })!, "i-receipt"))
            .ToList();

        return Json(new
        {
            grupos = new[]
            {
                new GrupoBusca("Pedidos", pedidos),
                new GrupoBusca("Produtos", produtos),
                new GrupoBusca("Clientes", clientes)
            }
        });
    }
}
