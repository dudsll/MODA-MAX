using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Models;

namespace modamax.web.Services;

// Fluxo de "esqueci minha senha" com token de uso unico e prazo de validade.
public class RecuperacaoSenhaService
{
    public static readonly TimeSpan Validade = TimeSpan.FromMinutes(30);

    private readonly AppDbContext _context;

    public RecuperacaoSenhaService(AppDbContext context)
    {
        _context = context;
    }

    // Retorna o token (para montar o link) ou null se o e-mail nao existir.
    public async Task<(Usuario Usuario, string Token)?> GerarAsync(string email)
    {
        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Email == email);
        if (usuario == null) return null;

        // Um novo pedido invalida os links anteriores ainda nao usados.
        var pendentes = await _context.RecuperacoesSenha
            .Where(r => r.IdUsuario == usuario.IdUsuario && r.UsadoEm == null)
            .ToListAsync();
        foreach (var pendente in pendentes)
        {
            pendente.UsadoEm = DateTime.UtcNow;
        }

        var token = Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
        _context.RecuperacoesSenha.Add(new RecuperacaoSenha
        {
            IdUsuario = usuario.IdUsuario,
            TokenHash = Hash(token),
            CriadoEm = DateTime.UtcNow,
            ExpiraEm = DateTime.UtcNow.Add(Validade)
        });
        await _context.SaveChangesAsync();

        return (usuario, token);
    }

    public async Task<bool> TokenValidoAsync(string? token)
    {
        return await BuscarValidoAsync(token) != null;
    }

    // Troca a senha e marca o token como usado. Retorna o usuario, ou null se o token for invalido.
    public async Task<Usuario?> RedefinirAsync(string? token, string novaSenha)
    {
        var recuperacao = await BuscarValidoAsync(token);
        if (recuperacao?.Usuario == null) return null;

        recuperacao.Usuario.Senha = SenhaService.GerarHash(recuperacao.Usuario, novaSenha);
        recuperacao.UsadoEm = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return recuperacao.Usuario;
    }

    private async Task<RecuperacaoSenha?> BuscarValidoAsync(string? token)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;

        var hash = Hash(token);
        var agora = DateTime.UtcNow;
        return await _context.RecuperacoesSenha
            .Include(r => r.Usuario)
            .FirstOrDefaultAsync(r => r.TokenHash == hash && r.UsadoEm == null && r.ExpiraEm > agora);
    }

    private static string Hash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private static string Base64UrlEncode(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
