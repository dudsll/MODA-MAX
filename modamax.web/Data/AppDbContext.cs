using Microsoft.EntityFrameworkCore;
using modamax.web.Models;

namespace ModaMax.Web.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options)
        {
        }
        public DbSet<modamax.web.Models.Produto> Produto { get; set; } = default!;
        //aqui mapeia as tabelas do banco
        public DbSet<Produto> Produtos { get; set; }
        //public DbSet<Cliente> Clientes { get; set; }
    }
}