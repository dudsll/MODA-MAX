using System.Globalization;
using System.Text;
using Microsoft.AspNetCore.Localization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using ModaMax.Web.Data;
using modamax.web.Infraestrutura;
using modamax.web.Services;
using Serilog;
using Serilog.Formatting.Compact;

using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

// Logs estruturados (Serilog): cada evento guarda suas propriedades (IdPedido, IdUsuario...)
// separadas do texto. Em producao saem em JSON, prontos para Application Insights ou outra ferramenta.
builder.Host.UseSerilog((contexto, servicos, logger) =>
{
    logger.ReadFrom.Configuration(contexto.Configuration)
        .ReadFrom.Services(servicos)
        .Enrich.FromLogContext()
        .Enrich.WithProperty("Aplicacao", "ModaMax");

    if (contexto.HostingEnvironment.IsProduction())
    {
        logger.WriteTo.Console(new RenderedCompactJsonFormatter());
    }
    else
    {
        logger.WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext}: {Message:lj}{NewLine}{Exception}");
    }
});

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Connection string 'DefaultConnection' nao configurada.");

// Banco oficial: SQL Server. "Database:Provider=Sqlite" liga o modo local sem Docker,
// usado em desenvolvimento rapido e nos testes automatizados (sem procedures/triggers).
var usarSqlite = string.Equals(builder.Configuration["Database:Provider"], "Sqlite", StringComparison.OrdinalIgnoreCase);
builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (usarSqlite)
    {
        options.UseSqlite(connectionString);
    }
    else
    {
        options.UseSqlServer(connectionString, sql => sql.EnableRetryOnFailure());
    }
});

var dataProtectionKeysPath = Path.Combine(builder.Environment.ContentRootPath, "App_Data", "DataProtectionKeys");
Directory.CreateDirectory(dataProtectionKeysPath);
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(dataProtectionKeysPath));

builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.IdleTimeout = TimeSpan.FromHours(8);
});
builder.Services.AddHttpContextAccessor();
builder.Services.AddControllersWithViews(options =>
{
    // Mensagens de validacao automaticas em portugues (o padrao do ASP.NET Core e ingles).
    var mensagens = options.ModelBindingMessageProvider;
    mensagens.SetValueMustBeANumberAccessor(campo => $"O campo {campo} deve ser um número.");
    mensagens.SetAttemptedValueIsInvalidAccessor((valor, campo) => $"O valor \"{valor}\" não é válido para {campo}.");
    mensagens.SetValueMustNotBeNullAccessor(campo => $"Informe o campo {campo}.");
    mensagens.SetMissingBindRequiredValueAccessor(campo => $"Informe o campo {campo}.");
    mensagens.SetNonPropertyAttemptedValueIsInvalidAccessor(valor => $"O valor \"{valor}\" não é válido.");
    mensagens.SetUnknownValueIsInvalidAccessor(campo => $"O valor informado não é válido para {campo}.");
});

// Autenticacao da API REST (usada pelo app mobile): token JWT.
// A aplicacao Web continua usando sessao + RequireUserAttribute.
var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Secao 'Jwt' nao configurada.");
builder.Services.AddSingleton(jwtOptions);
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<PedidoService>();
builder.Services.AddScoped<RecuperacaoSenhaService>();
builder.Services.AddScoped<DashboardService>();
builder.Services.AddScoped<LoginService>();
builder.Services.AddScoped<RelatorioService>();
builder.Services.AddScoped<MetaService>();
builder.Services.AddScoped<ReposicaoService>();
builder.Services.AddSingleton(builder.Configuration.GetSection("Reposicao").Get<ReposicaoOptions>() ?? new ReposicaoOptions());
builder.Services.AddSingleton(builder.Configuration.GetSection("Pix").Get<PixOptions>() ?? new PixOptions());
builder.Services.AddSingleton<PixService>();
builder.Services.AddSingleton<ExportacaoRelatorioService>();

// Fotos dos produtos: em disco (wwwroot/uploads/produtos) ou na pasta definida em "Fotos:Pasta".
builder.Services.AddSingleton<IArmazenamentoFotos>(servicos =>
{
    var ambiente = servicos.GetRequiredService<IWebHostEnvironment>();
    var pasta = builder.Configuration["Fotos:Pasta"];
    return new ArmazenamentoFotosLocal(string.IsNullOrWhiteSpace(pasta)
        ? Path.Combine(ambiente.WebRootPath, "uploads", "produtos")
        : pasta);
});

var seguranca = builder.Configuration.GetSection("Seguranca").Get<SegurancaOptions>() ?? new SegurancaOptions();
builder.Services.AddSingleton(seguranca);
builder.Services.AddLimiteRequisicoes(seguranca);
builder.Services.AddErrosPadronizados();

// E-mail: SMTP se a secao "Smtp" estiver configurada; senao, so registra no log.
var smtpOptions = builder.Configuration.GetSection("Smtp").Get<SmtpOptions>();
if (!string.IsNullOrWhiteSpace(smtpOptions?.Host))
{
    builder.Services.AddSingleton(smtpOptions);
    builder.Services.AddSingleton<IEmailService, SmtpEmailService>();
}
else
{
    builder.Services.AddSingleton<IEmailService, LogEmailService>();
}

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Key))
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("Mobile", policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks().AddDbContextCheck<AppDbContext>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    DbInitializer.Initialize(context, usarMigrations: !usarSqlite);
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
    app.UseHttpsRedirection();
}

// Na API, erros e respostas vazias (401, 403, 404) saem em Problem Details.
app.UseErrosPadronizadosNaApi();

// Uma linha de log por requisicao, com metodo, caminho, status e tempo de resposta.
app.UseSerilogRequestLogging(options =>
{
    options.EnrichDiagnosticContext = (diagnostico, http) =>
    {
        diagnostico.Set("Ip", http.Connection.RemoteIpAddress?.ToString());
        if (http.User.Identity?.IsAuthenticated == true)
        {
            diagnostico.Set("Usuario", http.User.Identity.Name);
        }
    };
});

// Cultura fixa pt-BR: moeda em R$ e datas dd/MM/yyyy tambem em servidores Linux (Docker/Azure),
// que nao tem cultura padrao configurada.
var culturaPtBr = new CultureInfo("pt-BR");
app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture(culturaPtBr),
    SupportedCultures = new[] { culturaPtBr },
    SupportedUICultures = new[] { culturaPtBr }
});

app.UseStaticFiles();

// Se as fotos estiverem fora do wwwroot (ex.: volume do Docker), elas sao servidas pelo mesmo endereco.
var pastaFotos = builder.Configuration["Fotos:Pasta"];
if (!string.IsNullOrWhiteSpace(pastaFotos))
{
    Directory.CreateDirectory(pastaFotos);
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(pastaFotos),
        RequestPath = ArmazenamentoFotosLocal.UrlBase
    });
}
app.UseRouting();
app.UseRateLimiter();
app.UseCors("Mobile");
app.UseSession();
app.UseAuthentication();
app.UseAuthorization();

// Documentacao da API: /openapi/v1.json e interface em /swagger
app.MapOpenApi();
app.UseSwaggerUI(options => options.SwaggerEndpoint("/openapi/v1.json", "ModaMax API v1"));

app.MapHealthChecks("/health");

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();

// Permite que o projeto de testes suba a aplicacao com WebApplicationFactory<Program>.
public partial class Program;
