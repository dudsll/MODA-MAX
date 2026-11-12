using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using Testcontainers.MsSql;

namespace ModaMax.IntegrationTests;

// Sobe um SQL Server 2022 de verdade em um container Docker, aplica as migrations
// (tabelas, procedures e triggers) e os dados de demonstracao, uma vez para todos os testes.
public sealed class SqlServerFixture : IAsyncLifetime
{
    private MsSqlContainer? _container;

    public string ConnectionString { get; private set; } = string.Empty;

    public async Task InitializeAsync()
    {
        if (!FactSqlServerAttribute.DeveExecutar) return;

        _container = new MsSqlBuilder("mcr.microsoft.com/mssql/server:2022-latest").Build();
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();

        await using var contexto = NovoContexto();
        DbInitializer.Initialize(contexto, usarMigrations: true);
    }

    public async Task DisposeAsync()
    {
        if (_container != null) await _container.DisposeAsync();
    }

    public AppDbContext NovoContexto() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseSqlServer(ConnectionString, sql => sql.EnableRetryOnFailure())
        .Options);
}

[CollectionDefinition(Nome)]
public class ColecaoSqlServer : ICollectionFixture<SqlServerFixture>
{
    public const string Nome = "SQL Server";
}

// Os testes precisam de Docker. Sem Docker na maquina eles aparecem como "ignorados";
// no CI a variavel MODAMAX_TESTES_SQLSERVER=1 obriga a execucao (e falha se o Docker faltar).
public sealed class FactSqlServerAttribute : FactAttribute
{
    public static bool DeveExecutar =>
        Environment.GetEnvironmentVariable("MODAMAX_TESTES_SQLSERVER") == "1" || DockerDisponivel();

    public FactSqlServerAttribute()
    {
        if (!DeveExecutar)
        {
            Skip = "Docker nao encontrado. Rode com Docker ativo ou defina MODAMAX_TESTES_SQLSERVER=1.";
        }
    }

    private static bool DockerDisponivel()
    {
        if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("DOCKER_HOST"))) return true;
        if (OperatingSystem.IsWindows()) return File.Exists(@"\\.\pipe\docker_engine");

        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        return File.Exists("/var/run/docker.sock") || File.Exists(Path.Combine(home, ".docker", "run", "docker.sock"));
    }
}
