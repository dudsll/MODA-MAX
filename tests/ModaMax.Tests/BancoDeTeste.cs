using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Models;
using modamax.web.Services;

namespace ModaMax.Tests;

// Banco SQLite em memoria com dados pequenos e conhecidos para os testes de regra de negocio.
// A conexao fica aberta durante o teste: quando ela fecha, o banco em memoria some.
public sealed class BancoDeTeste : IDisposable
{
    private readonly SqliteConnection _conexao;

    public BancoDeTeste()
    {
        _conexao = new SqliteConnection("Data Source=:memory:");
        _conexao.Open();

        using var contexto = NovoContexto();
        contexto.Database.EnsureCreated();

        var categoria = new Categoria { Nome = "Jaqueta" };
        var fornecedor = new Fornecedor { Nome = "Fornecedor Teste" };
        Jaqueta = new Produto { Nome = "Jaqueta Jeans", Tamanho = "M", Cor = "Azul", Preco = 100m, Estoque = 10, Categoria = categoria, Fornecedor = fornecedor };
        Bermuda = new Produto { Nome = "Bermuda Jeans", Tamanho = "40", Cor = "Azul", Preco = 120.85m, Estoque = 5, Categoria = categoria, Fornecedor = fornecedor };
        Cliente = new Cliente { Nome = "Cliente Teste", Tipo = "PF", Documento = "000.000.000-00", Email = "cliente@teste.com" };
        Usuario = new Usuario { Nome = "Usuario Teste", Email = "usuario@teste.com", Nivel = "Operacional" };
        Usuario.Senha = SenhaService.GerarHash(Usuario, "senha-antiga");

        contexto.AddRange(Jaqueta, Bermuda, Cliente, Usuario);
        contexto.SaveChanges();
    }

    public Produto Jaqueta { get; }

    public Produto Bermuda { get; }

    public Cliente Cliente { get; }

    public Usuario Usuario { get; }

    public AppDbContext NovoContexto() =>
        new(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_conexao).Options);

    public int EstoqueAtual(int idProduto)
    {
        using var contexto = NovoContexto();
        return contexto.Produtos.AsNoTracking().Single(p => p.IdProduto == idProduto).Estoque;
    }

    public void Dispose() => _conexao.Dispose();
}
