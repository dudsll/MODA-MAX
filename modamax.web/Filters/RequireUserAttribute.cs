using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using System.Globalization;
using System.Text;

namespace modamax.web.Filters;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class RequireUserAttribute : Attribute, IAsyncActionFilter
{
    private readonly string[] _niveis;

    public RequireUserAttribute(params string[] niveis)
    {
        _niveis = niveis;
    }

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var usuarioId = context.HttpContext.Session.GetInt32("UsuarioId");
        if (!usuarioId.HasValue)
        {
            context.Result = new RedirectToActionResult("Login", "Account", null);
            return;
        }

        if (_niveis.Length > 0)
        {
            var nivelAtual = context.HttpContext.Session.GetString("UsuarioNivel");
            var nivelAtualNormalizado = NormalizeText(nivelAtual);
            var permitido = _niveis.Any(n => string.Equals(NormalizeText(n), nivelAtualNormalizado, StringComparison.OrdinalIgnoreCase));

            if (!permitido)
            {
                context.Result = new RedirectToActionResult("AcessoNegado", "Account", null);
                return;
            }
        }

        await next();
    }

    private static string NormalizeText(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var normalized = value.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(normalized.Length);

        foreach (var c in normalized)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            {
                sb.Append(c);
            }
        }

        return sb.ToString().Normalize(NormalizationForm.FormC);
    }
}
