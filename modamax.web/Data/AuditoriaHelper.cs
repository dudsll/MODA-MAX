using Microsoft.AspNetCore.Http;

namespace ModaMax.Web.Data;

public static class AuditoriaHelper
{
    public static async Task RegistrarAsync(AppDbContext context, HttpContext httpContext, string acao)
    {
        var usuarioId = httpContext.Session.GetInt32("UsuarioId");

        context.LogsSistema.Add(new modamax.web.Models.LogSistema
        {
            IdUsuario = usuarioId,
            Acao = acao,
            Data = DateTime.Now
        });

        await context.SaveChangesAsync();
    }
}
