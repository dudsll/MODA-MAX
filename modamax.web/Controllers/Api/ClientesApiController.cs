using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Dtos;
using modamax.web.Models;

namespace modamax.web.Controllers.Api;

[ApiController]
[Route("api/clientes")]
[Authorize]
public class ClientesApiController : ControllerBase
{
    private readonly AppDbContext _context;

    public ClientesApiController(AppDbContext context)
    {
        _context = context;
    }

    // GET /api/clientes?busca=ana
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ClienteDto>>> Listar(string? busca)
    {
        var query = _context.Clientes.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(busca))
        {
            query = query.Where(c => c.Nome.Contains(busca) || c.Documento.Contains(busca));
        }

        var clientes = await query.OrderBy(c => c.Nome).ToListAsync();
        return clientes.Select(ParaDto).ToList();
    }

    // GET /api/clientes/5
    [HttpGet("{id:int}")]
    public async Task<ActionResult<ClienteDto>> Obter(int id)
    {
        var cliente = await _context.Clientes.AsNoTracking().FirstOrDefaultAsync(c => c.IdCliente == id);
        return cliente == null ? NotFound() : ParaDto(cliente);
    }

    // POST /api/clientes
    [HttpPost]
    public async Task<ActionResult<ClienteDto>> Criar(ClienteSalvarDto dto)
    {
        var cliente = new Cliente();
        Copiar(dto, cliente);
        _context.Clientes.Add(cliente);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(Obter), new { id = cliente.IdCliente }, ParaDto(cliente));
    }

    // PUT /api/clientes/5
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Atualizar(int id, ClienteSalvarDto dto)
    {
        var cliente = await _context.Clientes.FindAsync(id);
        if (cliente == null) return NotFound();

        Copiar(dto, cliente);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // DELETE /api/clientes/5
    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Estrategico,Tatico")]
    public async Task<IActionResult> Excluir(int id)
    {
        var cliente = await _context.Clientes.FindAsync(id);
        if (cliente == null) return NotFound();

        if (await _context.Pedidos.AnyAsync(p => p.IdCliente == id))
        {
            return Problem(detail: "Cliente possui pedidos e nao pode ser excluido.", statusCode: StatusCodes.Status409Conflict);
        }

        _context.Clientes.Remove(cliente);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    private static void Copiar(ClienteSalvarDto dto, Cliente cliente)
    {
        cliente.Nome = dto.Nome;
        cliente.Tipo = dto.Tipo;
        cliente.Documento = dto.Documento;
        cliente.Email = dto.Email;
        cliente.Telefone = dto.Telefone;
        cliente.Endereco = dto.Endereco;
    }

    private static ClienteDto ParaDto(Cliente c) =>
        new(c.IdCliente, c.Nome, c.Tipo, c.Documento, c.Email, c.Telefone, c.Endereco);
}
