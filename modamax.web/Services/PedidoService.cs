using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using ModaMax.Web.Data;
using modamax.web.Models;

namespace modamax.web.Services;

public class ItemPedidoEntrada
{
    public int IdProduto { get; set; }

    public int Quantidade { get; set; }

    public decimal Desconto { get; set; }
}

public class DadosPedido
{
    public int IdCliente { get; set; }

    public DateTime DataPedido { get; set; } = DateTime.Now;

    public string TiposVenda { get; set; } = "Varejo";

    public string Status { get; set; } = PedidoService.StatusEmSeparacao;

    public IReadOnlyList<ItemPedidoEntrada> Itens { get; set; } = Array.Empty<ItemPedidoEntrada>();
}

public class ResultadoPedido
{
    public Pedido? Pedido { get; init; }

    public string? Erro { get; init; }

    public bool NaoEncontrado { get; init; }

    public bool Sucesso => Erro == null;
}

// Regras de negocio de pedidos, usadas pela aplicacao Web e pela API:
// preco de atacado, validacao e movimentacao de estoque, sempre em transacao.
// Um pedido "consome" estoque enquanto o status for diferente de Cancelado.
public class PedidoService
{
    public const string StatusFinalizado = "Finalizado";
    public const string StatusEmSeparacao = "Em separação";
    public const string StatusCancelado = "Cancelado";

    public static readonly string[] StatusValidos = { StatusFinalizado, StatusEmSeparacao, StatusCancelado };

    private readonly AppDbContext _context;
    private readonly ILogger<PedidoService> _logger;

    public PedidoService(AppDbContext context, ILogger<PedidoService>? logger = null)
    {
        _context = context;
        _logger = logger ?? NullLogger<PedidoService>.Instance;
    }

    public static decimal CalcularPrecoUnitario(decimal precoBase, string tipoVenda)
    {
        return string.Equals(tipoVenda, "Atacado", StringComparison.OrdinalIgnoreCase)
            // Arredondamento comercial (0,5 sobe). O padrao do Math.Round arredondaria 108,765 para 108,76.
            ? Math.Round(precoBase * 0.9m, 2, MidpointRounding.AwayFromZero)
            : precoBase;
    }

    private static bool ConsomeEstoque(string status) => status != StatusCancelado;

    public Task<ResultadoPedido> CriarAsync(DadosPedido dados)
    {
        return EmTransacaoAsync(async () =>
        {
            var erro = await ValidarCabecalhoAsync(dados);
            if (erro != null) return Falha(erro);

            var pedido = new Pedido();
            erro = await AplicarDadosAsync(pedido, dados, "Pedido criado");
            if (erro != null) return Falha(erro);

            _context.Pedidos.Add(pedido);
            await _context.SaveChangesAsync();
            _logger.LogInformation("Pedido {IdPedido} criado: {TipoVenda}, {QuantidadeItens} item(ns), total {ValorTotal}",
                pedido.IdPedido, pedido.TiposVenda, pedido.Itens.Count, pedido.ValorTotal);
            return new ResultadoPedido { Pedido = pedido };
        });
    }

    public Task<ResultadoPedido> AtualizarAsync(int idPedido, DadosPedido dados)
    {
        return EmTransacaoAsync(async () =>
        {
            var pedido = await CarregarAsync(idPedido);
            if (pedido == null) return NaoEncontrado();

            var erro = await ValidarCabecalhoAsync(dados);
            if (erro != null) return Falha(erro);

            DevolverEstoque(pedido, $"Ajuste do pedido #{pedido.IdPedido}");
            _context.ItensPedido.RemoveRange(pedido.Itens);
            pedido.Itens.Clear();

            erro = await AplicarDadosAsync(pedido, dados, $"Pedido #{pedido.IdPedido} atualizado");
            if (erro != null) return Falha(erro);

            await _context.SaveChangesAsync();
            return new ResultadoPedido { Pedido = pedido };
        });
    }

    public Task<ResultadoPedido> CancelarAsync(int idPedido)
    {
        return EmTransacaoAsync(async () =>
        {
            var pedido = await CarregarAsync(idPedido);
            if (pedido == null) return NaoEncontrado();
            if (pedido.Status == StatusCancelado) return Falha("O pedido ja esta cancelado.");

            DevolverEstoque(pedido, $"Cancelamento do pedido #{pedido.IdPedido}");
            pedido.Status = StatusCancelado;

            await _context.SaveChangesAsync();
            _logger.LogInformation("Pedido {IdPedido} cancelado; estoque devolvido", pedido.IdPedido);
            return new ResultadoPedido { Pedido = pedido };
        });
    }

    public Task<ResultadoPedido> ExcluirAsync(int idPedido)
    {
        return EmTransacaoAsync(async () =>
        {
            var pedido = await CarregarAsync(idPedido);
            if (pedido == null) return NaoEncontrado();

            DevolverEstoque(pedido, $"Exclusao do pedido #{pedido.IdPedido}");
            _context.Pedidos.Remove(pedido);

            await _context.SaveChangesAsync();
            _logger.LogInformation("Pedido {IdPedido} excluido; estoque devolvido", pedido.IdPedido);
            return new ResultadoPedido { Pedido = pedido };
        });
    }

    private Task<Pedido?> CarregarAsync(int idPedido) => _context.Pedidos
        .Include(p => p.Itens)
        .ThenInclude(i => i.Produto)
        .FirstOrDefaultAsync(p => p.IdPedido == idPedido);

    private async Task<string?> ValidarCabecalhoAsync(DadosPedido dados)
    {
        if (dados.Itens.Count == 0) return "O pedido precisa ter ao menos um item.";
        if (!StatusValidos.Contains(dados.Status)) return "Status de pedido invalido.";
        if (dados.TiposVenda != "Varejo" && dados.TiposVenda != "Atacado") return "Tipo de venda invalido.";
        if (!await _context.Clientes.AnyAsync(c => c.IdCliente == dados.IdCliente)) return "Cliente nao encontrado.";
        return null;
    }

    // Preenche o pedido com os itens informados, calculando precos e baixando o estoque.
    private async Task<string?> AplicarDadosAsync(Pedido pedido, DadosPedido dados, string observacao)
    {
        pedido.IdCliente = dados.IdCliente;
        pedido.DataPedido = dados.DataPedido;
        pedido.TiposVenda = dados.TiposVenda;
        pedido.Status = dados.Status;
        pedido.ValorTotal = 0m;

        foreach (var entrada in dados.Itens)
        {
            var produto = await _context.Produtos.FindAsync(entrada.IdProduto);
            if (produto == null) return $"Produto {entrada.IdProduto} nao encontrado.";
            if (entrada.Quantidade <= 0) return $"Quantidade invalida para {produto.Nome}.";
            if (entrada.Desconto < 0) return $"Desconto invalido para {produto.Nome}.";

            // A checagem e feita item a item sobre o estoque ja baixado,
            // entao o mesmo produto repetido em duas linhas tambem e validado.
            if (ConsomeEstoque(dados.Status) && produto.Estoque < entrada.Quantidade)
            {
                return $"Estoque insuficiente para {produto.Nome} (disponivel: {produto.Estoque}).";
            }

            var precoUnitario = CalcularPrecoUnitario(produto.Preco, dados.TiposVenda);
            var subtotal = (precoUnitario * entrada.Quantidade) - entrada.Desconto;
            if (subtotal < 0) return $"O desconto de {produto.Nome} e maior que o valor do item.";

            pedido.Itens.Add(new ItemPedido
            {
                IdProduto = produto.IdProduto,
                Produto = produto,
                Quantidade = entrada.Quantidade,
                PrecoUnitario = precoUnitario,
                Desconto = entrada.Desconto
            });
            pedido.ValorTotal += subtotal;

            if (ConsomeEstoque(dados.Status))
            {
                produto.Estoque -= entrada.Quantidade;
                RegistrarMovimentacao(produto.IdProduto, "Saida", entrada.Quantidade, observacao);
            }
        }

        return null;
    }

    private void DevolverEstoque(Pedido pedido, string observacao)
    {
        if (!ConsomeEstoque(pedido.Status)) return;

        foreach (var item in pedido.Itens)
        {
            if (item.Produto == null) continue;
            item.Produto.Estoque += item.Quantidade;
            RegistrarMovimentacao(item.IdProduto, "Entrada", item.Quantidade, observacao);
        }
    }

    private void RegistrarMovimentacao(int idProduto, string tipo, int quantidade, string observacao)
    {
        _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
        {
            IdProduto = idProduto,
            Tipo = tipo,
            Quantidade = quantidade,
            Data = DateTime.Now,
            Observacao = observacao
        });
    }

    private async Task<ResultadoPedido> EmTransacaoAsync(Func<Task<ResultadoPedido>> operacao)
    {
        var strategy = _context.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            await using var transacao = await _context.Database.BeginTransactionAsync();
            var resultado = await operacao();
            if (resultado.Sucesso)
            {
                await transacao.CommitAsync();
            }

            return resultado;
        });
    }

    // Descarta as alteracoes em memoria (estoque baixado, itens removidos) para que
    // a tela que vai exibir o erro nao mostre valores que nao foram gravados.
    private ResultadoPedido Falha(string erro)
    {
        _logger.LogWarning("Operacao de pedido recusada: {Motivo}", erro);
        _context.ChangeTracker.Clear();
        return new ResultadoPedido { Erro = erro };
    }

    private ResultadoPedido NaoEncontrado()
    {
        _context.ChangeTracker.Clear();
        return new ResultadoPedido { Erro = "Pedido nao encontrado.", NaoEncontrado = true };
    }
}
