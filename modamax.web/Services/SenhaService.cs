using Microsoft.AspNetCore.Identity;
using modamax.web.Models;

namespace modamax.web.Services;

// Centraliza o hash de senhas (PBKDF2 do ASP.NET Core Identity) usado pela Web e pela API.
public static class SenhaService
{
    private static readonly PasswordHasher<Usuario> Hasher = new();

    public static string GerarHash(Usuario usuario, string senha)
    {
        return Hasher.HashPassword(usuario, senha);
    }

    public static bool Verificar(Usuario usuario, string senhaInformada)
    {
        var resultado = Hasher.VerifyHashedPassword(usuario, usuario.Senha, senhaInformada);
        return resultado != PasswordVerificationResult.Failed;
    }
}
