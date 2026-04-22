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
    }
}
