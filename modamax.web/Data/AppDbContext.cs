using Microsoft.EntityFrameworkCore;
using modamax.web.Models;

namespace ModaMax.Web.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public DbSet<Produto> Produtos => Set<Produto>();

    public DbSet<Cliente> Clientes => Set<Cliente>();

    public DbSet<Categoria> Categorias => Set<Categoria>();

    public DbSet<Fornecedor> Fornecedores => Set<Fornecedor>();

    public DbSet<Pedido> Pedidos => Set<Pedido>();

    public DbSet<Usuario> Usuarios => Set<Usuario>();

    public DbSet<ItemPedido> ItensPedido => Set<ItemPedido>();

    public DbSet<MovimentacaoEstoque> MovimentacoesEstoque => Set<MovimentacaoEstoque>();

    public DbSet<LogSistema> LogsSistema => Set<LogSistema>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Produto>()
            .HasOne(p => p.Categoria)
            .WithMany(c => c.Produtos)
            .HasForeignKey(p => p.IdCategoria)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Produto>()
            .HasOne(p => p.Fornecedor)
            .WithMany(f => f.Produtos)
            .HasForeignKey(p => p.IdFornecedor)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Pedido>()
            .HasOne(p => p.Cliente)
            .WithMany(c => c.Pedidos)
            .HasForeignKey(p => p.IdCliente)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<ItemPedido>()
            .HasOne(i => i.Pedido)
            .WithMany(p => p.Itens)
            .HasForeignKey(i => i.IdPedido)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<ItemPedido>()
            .HasOne(i => i.Produto)
            .WithMany()
            .HasForeignKey(i => i.IdProduto)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<MovimentacaoEstoque>()
            .HasOne(m => m.Produto)
            .WithMany()
            .HasForeignKey(m => m.IdProduto)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<LogSistema>()
            .HasOne(l => l.Usuario)
            .WithMany(u => u.Logs)
            .HasForeignKey(l => l.IdUsuario)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
