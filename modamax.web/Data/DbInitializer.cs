using Microsoft.EntityFrameworkCore;
using modamax.web.Models;

namespace ModaMax.Web.Data;

public static class DbInitializer
{
    public static void Initialize(AppDbContext context)
    {
        context.Database.EnsureCreated();

        if (context.Usuarios.Any())
        {
            return;
        }

        var categorias = new List<Categoria>
        {
            new() { IdCategoria = 1, Nome = "Macaquinho" },
            new() { IdCategoria = 2, Nome = "Macacao" },
            new() { IdCategoria = 3, Nome = "Jaqueta" },
            new() { IdCategoria = 4, Nome = "Bermuda" },
            new() { IdCategoria = 5, Nome = "Short" },
            new() { IdCategoria = 6, Nome = "Colete" },
            new() { IdCategoria = 7, Nome = "Saia" },
            new() { IdCategoria = 8, Nome = "Blusa" },
            new() { IdCategoria = 9, Nome = "Calca" }
        };

        var fornecedores = new List<Fornecedor>
        {
            new() { IdFornecedor = 1, Nome = "Aming Jeans", Contato = "Equipe Comercial", Telefone = "(11) 3000-1001" },
            new() { IdFornecedor = 2, Nome = "Alianza Jeans", Contato = "Atendimento", Telefone = "(11) 3000-1002" },
            new() { IdFornecedor = 3, Nome = "DZ Confeccoes", Contato = "Relacionamento", Telefone = "(11) 3000-1003" }
        };

        var produtos = new List<Produto>
        {
            new() { IdProduto = 1, Nome = "Macaquinho Jeans", Descricao = "Peca casual em jeans claro.", Tamanho = "36", Cor = "Azul", Preco = 130.25m, Estoque = 45, IdCategoria = 1, IdFornecedor = 1 },
            new() { IdProduto = 2, Nome = "Macacao Jeans", Descricao = "Macacao jeans azul bebe.", Tamanho = "38", Cor = "Azul bebe", Preco = 120.25m, Estoque = 30, IdCategoria = 2, IdFornecedor = 1 },
            new() { IdProduto = 3, Nome = "Jaqueta Jeans", Descricao = "Jaqueta feminina em jeans escuro.", Tamanho = "P", Cor = "Azul escuro", Preco = 170.48m, Estoque = 20, IdCategoria = 3, IdFornecedor = 2 },
            new() { IdProduto = 4, Nome = "Bermuda Jeans", Descricao = "Bermuda jeans de cintura media.", Tamanho = "40", Cor = "Azul", Preco = 120.85m, Estoque = 50, IdCategoria = 4, IdFornecedor = 2 },
            new() { IdProduto = 5, Nome = "Short Jeans", Descricao = "Short jeans para colecao primavera.", Tamanho = "38", Cor = "Azul", Preco = 160.73m, Estoque = 40, IdCategoria = 5, IdFornecedor = 3 },
            new() { IdProduto = 6, Nome = "Colete Jeans", Descricao = "Colete jeans com lavagem clara.", Tamanho = "G", Cor = "Azul claro", Preco = 120.75m, Estoque = 28, IdCategoria = 6, IdFornecedor = 1 },
            new() { IdProduto = 7, Nome = "Saia Jeans", Descricao = "Saia jeans tradicional.", Tamanho = "36", Cor = "Azul claro", Preco = 170.00m, Estoque = 15, IdCategoria = 7, IdFornecedor = 3 },
            new() { IdProduto = 8, Nome = "Blusa Jeans", Descricao = "Blusa jeans feminina.", Tamanho = "M", Cor = "Azul claro", Preco = 98.60m, Estoque = 50, IdCategoria = 8, IdFornecedor = 1 },
            new() { IdProduto = 9, Nome = "Calca Jeans", Descricao = "Calca jeans reta.", Tamanho = "46", Cor = "Azul", Preco = 140.00m, Estoque = 27, IdCategoria = 9, IdFornecedor = 3 },
            new() { IdProduto = 10, Nome = "Jaqueta Jeans Premium", Descricao = "Jaqueta premium para inverno.", Tamanho = "GG", Cor = "Azul claro", Preco = 170.97m, Estoque = 14, IdCategoria = 3, IdFornecedor = 2 }
        };

        var clientes = new List<Cliente>
        {
            new() { IdCliente = 1, Nome = "Luara de Jesus", Tipo = "PF", Documento = "123.456.789-01", Email = "luara@email.com", Telefone = "0800-001", Endereco = "Rua das Flores, 100" },
            new() { IdCliente = 2, Nome = "Dhebora Barreto", Tipo = "PF", Documento = "123.456.789-02", Email = "dhebora@email.com", Telefone = "0800-002", Endereco = "Av. Central, 200" },
            new() { IdCliente = 3, Nome = "Bianca Arantes Araujo", Tipo = "PF", Documento = "123.456.789-03", Email = "bianca@email.com", Telefone = "0800-003", Endereco = "Rua A, 45" },
            new() { IdCliente = 4, Nome = "Amanda da Silva", Tipo = "PF", Documento = "123.456.789-27", Email = "amanda@email.com", Telefone = "0800-027", Endereco = "Rua B, 80" },
            new() { IdCliente = 5, Nome = "Larissa Alves Oliveira", Tipo = "PF", Documento = "123.456.789-45", Email = "larissa@email.com", Telefone = "0800-045", Endereco = "Rua C, 18" }
        };

        var pedidos = new List<Pedido>
        {
            new() { IdPedido = 1, IdCliente = 1, DataPedido = new DateTime(2026, 6, 1), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 160.73m },
            new() { IdPedido = 2, IdCliente = 2, DataPedido = new DateTime(2026, 6, 1), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 120.75m },
            new() { IdPedido = 3, IdCliente = 3, DataPedido = new DateTime(2026, 6, 2), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 170.97m },
            new() { IdPedido = 4, IdCliente = 4, DataPedido = new DateTime(2026, 6, 3), TiposVenda = "Varejo", Status = "Em separacao", ValorTotal = 140.00m },
            new() { IdPedido = 5, IdCliente = 5, DataPedido = new DateTime(2026, 6, 3), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 98.60m }
        };

        var itensPedido = new List<ItemPedido>
        {
            new() { IdItem = 1, IdPedido = 1, IdProduto = 5, Quantidade = 1, PrecoUnitario = 160.73m, Desconto = 0m },
            new() { IdItem = 2, IdPedido = 2, IdProduto = 6, Quantidade = 1, PrecoUnitario = 120.75m, Desconto = 0m },
            new() { IdItem = 3, IdPedido = 3, IdProduto = 10, Quantidade = 1, PrecoUnitario = 170.97m, Desconto = 0m },
            new() { IdItem = 4, IdPedido = 4, IdProduto = 9, Quantidade = 1, PrecoUnitario = 140.00m, Desconto = 0m },
            new() { IdItem = 5, IdPedido = 5, IdProduto = 8, Quantidade = 1, PrecoUnitario = 98.60m, Desconto = 0m }
        };

        var usuarios = new List<Usuario>
        {
            new() { IdUsuario = 1, Nome = "Diretoria ModaMax", Email = "estrategico@modamax.com", Senha = "123456", Nivel = "Estrategico" },
            new() { IdUsuario = 2, Nome = "Gestora Comercial", Email = "tatico@modamax.com", Senha = "123456", Nivel = "Tatico" },
            new() { IdUsuario = 3, Nome = "Operador de Loja", Email = "operacional@modamax.com", Senha = "123456", Nivel = "Operacional" }
        };

        var movimentacoes = new List<MovimentacaoEstoque>
        {
            new() { IdMovi = 1, IdProduto = 5, Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 1), Observacao = "Pedido #1" },
            new() { IdMovi = 2, IdProduto = 6, Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 1), Observacao = "Pedido #2" },
            new() { IdMovi = 3, IdProduto = 10, Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 2), Observacao = "Pedido #3" },
            new() { IdMovi = 4, IdProduto = 9, Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 3), Observacao = "Pedido #4" },
            new() { IdMovi = 5, IdProduto = 8, Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 3), Observacao = "Pedido #5" }
        };

        var logs = new List<LogSistema>
        {
            new() { IdLog = 1, IdUsuario = 1, Acao = "Base inicial do sistema carregada.", Data = DateTime.Now.AddMinutes(-30) },
            new() { IdLog = 2, IdUsuario = 2, Acao = "Produtos e clientes de exemplo cadastrados.", Data = DateTime.Now.AddMinutes(-20) },
            new() { IdLog = 3, IdUsuario = 3, Acao = "Pedidos iniciais registrados para demonstracao.", Data = DateTime.Now.AddMinutes(-10) }
        };

        context.Categorias.AddRange(categorias);
        context.Fornecedores.AddRange(fornecedores);
        context.Produtos.AddRange(produtos);
        context.Clientes.AddRange(clientes);
        context.Usuarios.AddRange(usuarios);
        context.Pedidos.AddRange(pedidos);
        context.ItensPedido.AddRange(itensPedido);
        context.MovimentacoesEstoque.AddRange(movimentacoes);
        context.LogsSistema.AddRange(logs);
        context.SaveChanges();
    }
}
