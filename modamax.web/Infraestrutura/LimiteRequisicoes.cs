using System.Net;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using modamax.web.Services;

namespace modamax.web.Infraestrutura;

// Limita quantas vezes o mesmo endereco IP pode tentar login (Web e API) e
// pedir recuperacao de senha por minuto. Complementa o bloqueio por conta do LoginService.
public static class LimiteRequisicoes
{
    public const string Login = "login";

    public static IServiceCollection AddLimiteRequisicoes(this IServiceCollection services, SegurancaOptions opcoes)
    {
        return services.AddRateLimiter(options =>
        {
            options.AddPolicy(Login, contexto => RateLimitPartition.GetFixedWindowLimiter(
                contexto.Connection.RemoteIpAddress?.ToString() ?? "desconhecido",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = opcoes.LimiteRequisicoesPorMinuto,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0
                }));

            options.OnRejected = async (contexto, cancelamento) =>
            {
                var http = contexto.HttpContext;
                http.Response.StatusCode = StatusCodes.Status429TooManyRequests;
                http.Response.Headers.RetryAfter = "60";
                http.RequestServices.GetRequiredService<ILoggerFactory>()
                    .CreateLogger(typeof(LimiteRequisicoes))
                    .LogWarning("Limite de tentativas atingido para {Caminho} pelo IP {Ip}",
                        http.Request.Path.Value, http.Connection.RemoteIpAddress?.ToString());

                const string mensagem = "Muitas tentativas em pouco tempo. Aguarde um minuto e tente novamente.";
                if (http.Request.Path.StartsWithSegments("/api"))
                {
                    await http.RequestServices.GetRequiredService<IProblemDetailsService>().WriteAsync(new ProblemDetailsContext
                    {
                        HttpContext = http,
                        ProblemDetails = new ProblemDetails
                        {
                            Status = StatusCodes.Status429TooManyRequests,
                            Title = "Muitas requisicoes.",
                            Detail = mensagem
                        }
                    });
                    return;
                }

                http.Response.ContentType = "text/html; charset=utf-8";
                await http.Response.WriteAsync(
                    $"""
                    <!DOCTYPE html>
                    <html lang="pt-BR"><head><meta charset="utf-8"><title>ModaMax</title></head>
                    <body style="font-family: sans-serif; padding: 2rem">
                    <h1>ModaMax</h1>
                    <p>{WebUtility.HtmlEncode(mensagem)}</p>
                    <p><a href="/Account/Login">Voltar ao login</a></p>
                    </body></html>
                    """, cancelamento);
            };
        });
    }
}
