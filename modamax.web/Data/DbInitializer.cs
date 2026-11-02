using Microsoft.EntityFrameworkCore;
using modamax.web.Models;
using modamax.web.Services;

namespace ModaMax.Web.Data;

public static class DbInitializer
{
    public static void Initialize(AppDbContext context, bool usarMigrations = true)
    {
        if (usarMigrations)
        {
            // SQL Server: aplica as migrations pendentes (tabelas, procedures e triggers).
            context.Database.Migrate();
        }
        else
        {
            // Modo local/testes (SQLite): cria as tabelas direto pelo modelo.
            context.Database.EnsureCreated();
        }

        if (context.Usuarios.Any())
        {
            return;
        }

        var categorias = new List<Categoria>
        {
            new() { Nome = "Macaquinho" },
            new() { Nome = "Macacao" },
            new() { Nome = "Jaqueta" },
            new() { Nome = "Bermuda" },
            new() { Nome = "Short" },
            new() { Nome = "Colete" },
            new() { Nome = "Saia" },
            new() { Nome = "Blusa" },
            new() { Nome = "Calca" }
        };

        var fornecedores = new List<Fornecedor>
        {
            new() { Nome = "Aming Jeans", Contato = "Equipe Comercial", Telefone = "(11) 3000-1001" },
            new() { Nome = "Alianza Jeans", Contato = "Atendimento", Telefone = "(11) 3000-1002" },
            new() { Nome = "DZ Confeccoes", Contato = "Relacionamento", Telefone = "(11) 3000-1003" }
        };

        var produtos = new List<Produto>
        {
            new() { Nome = "Macaquinho Jeans", Descricao = "Peca casual em jeans claro.", Tamanho = "36", Cor = "Azul", Preco = 130.25m, Estoque = 135, IdFornecedor = 1 },
            new() { Nome = "Macacao Jeans", Descricao = "Macacao jeans azul bebe.", Tamanho = "38", Cor = "Azul bebe", Preco = 120.25m, Estoque = 90, IdFornecedor = 1 },
            new() { Nome = "Jaqueta Jeans", Descricao = "Jaqueta feminina em jeans escuro.", Tamanho = "P", Cor = "Azul escuro", Preco = 170.48m, Estoque = 60, IdFornecedor = 2 },
            new() { Nome = "Bermuda Jeans", Descricao = "Bermuda jeans de cintura media.", Tamanho = "40", Cor = "Azul", Preco = 120.85m, Estoque = 150, IdFornecedor = 2 },
            new() { Nome = "Short Jeans", Descricao = "Short jeans para colecao primavera.", Tamanho = "38", Cor = "Azul", Preco = 160.73m, Estoque = 120, IdFornecedor = 3 },
            new() { Nome = "Colete Jeans", Descricao = "Colete jeans com lavagem clara.", Tamanho = "G", Cor = "Azul claro", Preco = 120.75m, Estoque = 84, IdFornecedor = 1 },
            new() { Nome = "Saia Jeans", Descricao = "Saia jeans tradicional.", Tamanho = "36", Cor = "Azul claro", Preco = 170.00m, Estoque = 45, IdFornecedor = 3 },
            new() { Nome = "Blusa Jeans", Descricao = "Blusa jeans feminina.", Tamanho = "M", Cor = "Azul claro", Preco = 98.60m, Estoque = 150, IdFornecedor = 1 },
            new() { Nome = "Calca Jeans", Descricao = "Calca jeans reta.", Tamanho = "46", Cor = "Azul", Preco = 140.00m, Estoque = 81, IdFornecedor = 3 },
            new() { Nome = "Jaqueta Jeans Premium", Descricao = "Jaqueta premium para inverno.", Tamanho = "GG", Cor = "Azul claro", Preco = 170.97m, Estoque = 42, IdFornecedor = 2 }
        };

        var clientes = new List<Cliente>
        {
            new() { Nome = "Luara de Jesus", Tipo = "PF", Documento = "123.456.789-01", Email = "luara@email.com", Telefone = "0800-001", Endereco = "Rua das Flores, 100" },
            new() { Nome = "Dhebora Barreto", Tipo = "PF", Documento = "123.456.789-02", Email = "dhebora@email.com", Telefone = "0800-002", Endereco = "Av. Central, 200" },
            new() { Nome = "Bianca Arantes Araujo", Tipo = "PF", Documento = "123.456.789-03", Email = "bianca@email.com", Telefone = "0800-003", Endereco = "Rua A, 45" },
            new() { Nome = "Amanda da Silva", Tipo = "PF", Documento = "123.456.789-27", Email = "amanda@email.com", Telefone = "0800-027", Endereco = "Rua B, 80" },
            new() { Nome = "Larissa Alves Oliveira", Tipo = "PF", Documento = "123.456.789-45", Email = "larissa@email.com", Telefone = "0800-045", Endereco = "Rua C, 18" }
        };

        var pedidos = new List<Pedido>
        {
            new() { DataPedido = new DateTime(2026, 6, 1), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 160.73m },
            new() { DataPedido = new DateTime(2026, 6, 1), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 120.75m },
            new() { DataPedido = new DateTime(2026, 6, 2), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 170.97m },
            new() { DataPedido = new DateTime(2026, 6, 3), TiposVenda = "Varejo", Status = "Em separação", ValorTotal = 140.00m },
            new() { DataPedido = new DateTime(2026, 6, 3), TiposVenda = "Varejo", Status = "Finalizado", ValorTotal = 98.60m }
        };

        var itensPedido = new List<ItemPedido>
        {
            new() { Quantidade = 1, PrecoUnitario = 160.73m, Desconto = 0m },
            new() { Quantidade = 1, PrecoUnitario = 120.75m, Desconto = 0m },
            new() { Quantidade = 1, PrecoUnitario = 170.97m, Desconto = 0m },
            new() { Quantidade = 1, PrecoUnitario = 140.00m, Desconto = 0m },
            new() { Quantidade = 1, PrecoUnitario = 98.60m, Desconto = 0m }
        };

        var usuarios = new List<Usuario>
        {
            new() { Nome = "Diretoria ModaMax", Email = "estrategico@modamax.com", Senha = "123456", Nivel = "Estratégico" },
            new() { Nome = "Gestora Comercial", Email = "tatico@modamax.com", Senha = "123456", Nivel = "Tático" },
            new() { Nome = "Operador de Loja", Email = "operacional@modamax.com", Senha = "123456", Nivel = "Operacional" }
        };

        var movimentacoes = new List<MovimentacaoEstoque>
        {
            new() { Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 1), Observacao = "Pedido #1" },
            new() { Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 1), Observacao = "Pedido #2" },
            new() { Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 2), Observacao = "Pedido #3" },
            new() { Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 3), Observacao = "Pedido #4" },
            new() { Tipo = "Saida", Quantidade = 1, Data = new DateTime(2026, 6, 3), Observacao = "Pedido #5" }
        };

        var logs = new List<LogSistema>
        {
            new() { Acao = "Base inicial do sistema carregada.", Data = DateTime.Now.AddMinutes(-30) },
            new() { Acao = "Produtos e clientes de exemplo cadastrados.", Data = DateTime.Now.AddMinutes(-20) },
            new() { Acao = "Pedidos iniciais registrados para demonstracao.", Data = DateTime.Now.AddMinutes(-10) }
        };

        // Os relacionamentos sao feitos pelas navegacoes: no SQL Server as chaves
        // sao IDENTITY e so existem depois do INSERT.
        var categoriaDoProduto = new[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 2 };
        for (var i = 0; i < produtos.Count; i++)
        {
            produtos[i].Categoria = categorias[categoriaDoProduto[i]];
            produtos[i].Fornecedor = fornecedores[produtos[i].IdFornecedor - 1];
            produtos[i].IdFornecedor = 0;
        }

        var produtoDoPedido = new[] { 4, 5, 9, 8, 7 };
        for (var i = 0; i < pedidos.Count; i++)
        {
            pedidos[i].Cliente = clientes[i];
            itensPedido[i].Pedido = pedidos[i];
            itensPedido[i].Produto = produtos[produtoDoPedido[i]];
            movimentacoes[i].Produto = produtos[produtoDoPedido[i]];
        }

        for (var i = 0; i < logs.Count; i++)
        {
            logs[i].Usuario = usuarios[i];
        }

        foreach (var usuario in usuarios)
        {
            usuario.Senha = SenhaService.GerarHash(usuario, usuario.Senha);
        }

        context.Categorias.AddRange(categorias);
        context.Fornecedores.AddRange(fornecedores);
        context.Produtos.AddRange(produtos);
        context.Clientes.AddRange(clientes);
        context.Usuarios.AddRange(usuarios);
        context.Pedidos.AddRange(pedidos);
        context.ItensPedido.AddRange(itensPedido);
        context.MovimentacoesEstoque.AddRange(movimentacoes);
        context.LogsSistema.AddRange(logs);
        GerarVendasDemonstracao(context, clientes, produtos);
        context.SaveChanges();
    }

    // Vendas espalhadas pelos ultimos 4 meses para o dashboard e os relatorios terem dados.
    // A semente fixa do Random faz a base de demonstracao ser sempre a mesma.
    private static void GerarVendasDemonstracao(AppDbContext context, List<Cliente> clientes, List<Produto> produtos)
    {
        var aleatorio = new Random(2026);
        var hoje = DateTime.Today;

        for (var n = 0; n < 48; n++)
        {
            var data = hoje.AddDays(-aleatorio.Next(0, 120)).AddHours(aleatorio.Next(9, 19));
            var tipoVenda = aleatorio.Next(4) == 0 ? "Atacado" : "Varejo";
            var sorteio = aleatorio.Next(10);
            var status = sorteio == 0 ? PedidoService.StatusCancelado
                : data > hoje.AddDays(-7) && sorteio < 4 ? PedidoService.StatusEmSeparacao
                : PedidoService.StatusFinalizado;

            var pedido = new Pedido
            {
                Cliente = clientes[aleatorio.Next(clientes.Count)],
                DataPedido = data,
                TiposVenda = tipoVenda,
                Status = status
            };

            var qtdItens = aleatorio.Next(1, 4);
            foreach (var produto in produtos.OrderBy(_ => aleatorio.Next()).Take(qtdItens))
            {
                var quantidade = tipoVenda == "Atacado" ? aleatorio.Next(3, 7) : aleatorio.Next(1, 3);
                var consome = status != PedidoService.StatusCancelado;
                if (consome && produto.Estoque - quantidade < 5) continue;

                var preco = PedidoService.CalcularPrecoUnitario(produto.Preco, tipoVenda);
                pedido.Itens.Add(new ItemPedido { Produto = produto, Quantidade = quantidade, PrecoUnitario = preco, Desconto = 0m });
                pedido.ValorTotal += preco * quantidade;

                if (consome)
                {
                    produto.Estoque -= quantidade;
                    context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
                    {
                        Produto = produto,
                        Tipo = "Saida",
                        Quantidade = quantidade,
                        Data = data,
                        Observacao = "Venda de demonstracao"
                    });
                }
            }

            if (pedido.Itens.Count > 0)
            {
                context.Pedidos.Add(pedido);
            }
        }
    }
}
