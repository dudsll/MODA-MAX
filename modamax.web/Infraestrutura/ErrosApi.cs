using Microsoft.AspNetCore.Mvc;

namespace modamax.web.Infraestrutura;

// Padroniza as respostas de erro da API no formato Problem Details (RFC 9457):
// { "type", "title", "status", "detail", "traceId" }, com content-type application/problem+json.
// O aplicativo mostra o campo "detail" ao usuario.
public static class ErrosApi
{
    public static IServiceCollection AddErrosPadronizados(this IServiceCollection services)
    {
        services.AddProblemDetails();

        services.Configure<ApiBehaviorOptions>(options =>
        {
            var titulos = new Dictionary<int, string>
            {
                [400] = "Requisicao invalida.",
                [401] = "Autenticacao necessaria.",
                [403] = "Acesso negado.",
                [404] = "Recurso nao encontrado.",
                [409] = "Conflito com o estado atual.",
                [423] = "Conta bloqueada.",
                [500] = "Erro interno no servidor."
            };
            foreach (var (status, titulo) in titulos)
            {
                options.ClientErrorMapping[status] = new ClientErrorData
                {
                    Title = titulo,
                    Link = $"https://httpstatuses.io/{status}"
                };
            }

            // Erros de validacao (ex.: quantidade 0, e-mail invalido): a primeira mensagem vai em "detail".
            options.InvalidModelStateResponseFactory = contexto =>
            {
                var problema = new ValidationProblemDetails(contexto.ModelState)
                {
                    Status = StatusCodes.Status400BadRequest,
                    Title = "Dados invalidos.",
                    Detail = contexto.ModelState.Values
                        .SelectMany(v => v.Errors)
                        .Select(e => e.ErrorMessage)
                        .FirstOrDefault(m => !string.IsNullOrWhiteSpace(m)) ?? "Verifique os dados enviados."
                };
                return new BadRequestObjectResult(problema) { ContentTypes = { "application/problem+json" } };
            };
        });

        return services;
    }

    // Erros nao tratados e respostas vazias (401, 403, 404 do roteamento) da API tambem viram Problem Details.
    public static IApplicationBuilder UseErrosPadronizadosNaApi(this IApplicationBuilder app)
    {
        return app.UseWhen(
            contexto => contexto.Request.Path.StartsWithSegments("/api"),
            api =>
            {
                api.UseExceptionHandler();
                api.UseStatusCodePages();
            });
    }
}
