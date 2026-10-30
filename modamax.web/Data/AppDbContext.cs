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

        // As tabelas com trigger precisam ser declaradas para o EF Core nao usar
        // OUTPUT direto no SQL Server, o que falharia nessas tabelas.
        modelBuilder.Entity<Produto>().ToTable(t =>
        {
            t.HasTrigger("trg_Produto_AuditaPreco");
            t.HasCheckConstraint("CK_Produto_Estoque", "[Estoque] >= 0");
            t.HasCheckConstraint("CK_Produto_Preco", "[Preco] >= 0");
        });

        modelBuilder.Entity<Pedido>().ToTable(t =>
        {
            t.HasTrigger("trg_Pedido_AuditaStatus");
            t.HasCheckConstraint("CK_Pedido_ValorTotal", "[ValorTotal] >= 0");
        });

        modelBuilder.Entity<ItemPedido>().ToTable(t =>
            t.HasCheckConstraint("CK_ItemPedido_Quantidade", "[Quantidade] > 0"));

        modelBuilder.Entity<Usuario>()
            .HasIndex(u => u.Email)
            .IsUnique();

        modelBuilder.Entity<Pedido>()
            .HasIndex(p => p.DataPedido);

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
