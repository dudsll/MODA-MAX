using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Models;

namespace modamax.web.Services;

public class ItemPedidoEntrada
{
    public int IdProduto { get; set; }

    public int Quantidade { get; set; }

    public decimal Desconto { get; set; }
}

public class ResultadoPedido
{
    public Pedido? Pedido { get; init; }

    public string? Erro { get; init; }

    public bool Sucesso => Erro == null;
}

// Regras de negocio de pedidos usadas pela API: preco de atacado,
// validacao e baixa de estoque, tudo dentro de uma transacao.
public class PedidoService
{
    private readonly AppDbContext _context;

    public PedidoService(AppDbContext context)
    {
        _context = context;
    }

    public static decimal CalcularPrecoUnitario(decimal precoBase, string tipoVenda)
    {
        return string.Equals(tipoVenda, "Atacado", StringComparison.OrdinalIgnoreCase)
            ? Math.Round(precoBase * 0.9m, 2)
            : precoBase;
    }

    public async Task<ResultadoPedido> CriarAsync(int idCliente, string tipoVenda, IReadOnlyList<ItemPedidoEntrada> itens)
    {
        if (itens.Count == 0)
        {
            return new ResultadoPedido { Erro = "O pedido precisa ter ao menos um item." };
        }

        if (!await _context.Clientes.AnyAsync(c => c.IdCliente == idCliente))
        {
            return new ResultadoPedido { Erro = "Cliente nao encontrado." };
        }

        var strategy = _context.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            await using var transacao = await _context.Database.BeginTransactionAsync();

            var pedido = new Pedido
            {
                IdCliente = idCliente,
                DataPedido = DateTime.Now,
                TiposVenda = tipoVenda,
                Status = "Em separação"
            };

            foreach (var entrada in itens)
            {
                var produto = await _context.Produtos.FindAsync(entrada.IdProduto);
                if (produto == null)
                {
                    return new ResultadoPedido { Erro = $"Produto {entrada.IdProduto} nao encontrado." };
                }

                if (entrada.Quantidade <= 0)
                {
                    return new ResultadoPedido { Erro = $"Quantidade invalida para {produto.Nome}." };
                }

                if (produto.Estoque < entrada.Quantidade)
                {
                    return new ResultadoPedido { Erro = $"Estoque insuficiente para {produto.Nome} (disponivel: {produto.Estoque})." };
                }

                var precoUnitario = CalcularPrecoUnitario(produto.Preco, tipoVenda);
                pedido.Itens.Add(new ItemPedido
                {
                    IdProduto = produto.IdProduto,
                    Quantidade = entrada.Quantidade,
                    PrecoUnitario = precoUnitario,
                    Desconto = entrada.Desconto
                });
                pedido.ValorTotal += (precoUnitario * entrada.Quantidade) - entrada.Desconto;

                produto.Estoque -= entrada.Quantidade;
                _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
                {
                    IdProduto = produto.IdProduto,
                    Tipo = "Saida",
                    Quantidade = entrada.Quantidade,
                    Data = DateTime.Now,
                    Observacao = "Pedido criado pelo app"
                });
            }

            if (pedido.ValorTotal < 0)
            {
                return new ResultadoPedido { Erro = "O desconto nao pode ser maior que o valor do pedido." };
            }

            _context.Pedidos.Add(pedido);
            await _context.SaveChangesAsync();
            await transacao.CommitAsync();

            return new ResultadoPedido { Pedido = pedido };
        });
    }

    public async Task<ResultadoPedido> CancelarAsync(int idPedido)
    {
        var pedido = await _context.Pedidos
            .Include(p => p.Itens)
            .ThenInclude(i => i.Produto)
            .FirstOrDefaultAsync(p => p.IdPedido == idPedido);

        if (pedido == null)
        {
            return new ResultadoPedido { Erro = "Pedido nao encontrado." };
        }

        if (pedido.Status == "Cancelado")
        {
            return new ResultadoPedido { Erro = "O pedido ja esta cancelado." };
        }

        foreach (var item in pedido.Itens)
        {
            if (item.Produto == null) continue;

            item.Produto.Estoque += item.Quantidade;
            _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
            {
                IdProduto = item.IdProduto,
                Tipo = "Entrada",
                Quantidade = item.Quantidade,
                Data = DateTime.Now,
                Observacao = $"Cancelamento do pedido #{pedido.IdPedido}"
            });
        }

        pedido.Status = "Cancelado";
        await _context.SaveChangesAsync();

        return new ResultadoPedido { Pedido = pedido };
    }
}
