using System.Globalization;
using System.Text;
using Microsoft.AspNetCore.Localization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using ModaMax.Web.Data;
using modamax.web.Services;

using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

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
builder.Services.AddControllersWithViews();

// Autenticacao da API REST (usada pelo app mobile): token JWT.
// A aplicacao Web continua usando sessao + RequireUserAttribute.
var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Secao 'Jwt' nao configurada.");
builder.Services.AddSingleton(jwtOptions);
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<PedidoService>();
builder.Services.AddScoped<RecuperacaoSenhaService>();
builder.Services.AddScoped<DashboardService>();

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
app.UseRouting();
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
