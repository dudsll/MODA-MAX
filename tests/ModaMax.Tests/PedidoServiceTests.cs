using Microsoft.EntityFrameworkCore;
using modamax.web.Services;

namespace ModaMax.Tests;

public class PedidoServiceTests : IDisposable
{
    private readonly BancoDeTeste _banco = new();

    public void Dispose() => _banco.Dispose();

    private DadosPedido Pedido(string status = "Finalizado", string tipo = "Varejo", params (int Produto, int Qtd, decimal Desconto)[] itens) => new()
    {
        IdCliente = _banco.Cliente.IdCliente,
        Status = status,
        TiposVenda = tipo,
        Itens = itens.Select(i => new ItemPedidoEntrada { IdProduto = i.Produto, Quantidade = i.Qtd, Desconto = i.Desconto }).ToList()
    };

    [Fact]
    public async Task Criar_pedido_com_varios_itens_baixa_estoque_e_registra_movimentacoes()
    {
        using var contexto = _banco.NovoContexto();
        var servico = new PedidoService(contexto);

        var resultado = await servico.CriarAsync(Pedido(itens: new[] { (_banco.Jaqueta.IdProduto, 3, 0m), (_banco.Bermuda.IdProduto, 2, 10m) }));

        Assert.True(resultado.Sucesso, resultado.Erro);
        Assert.Equal(3 * 100m + 2 * 120.85m - 10m, resultado.Pedido!.ValorTotal);
        Assert.Equal(7, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));
        Assert.Equal(3, _banco.EstoqueAtual(_banco.Bermuda.IdProduto));

        using var leitura = _banco.NovoContexto();
        Assert.Equal(2, await leitura.MovimentacoesEstoque.CountAsync(m => m.Tipo == "Saida"));
    }

    [Theory]
    [InlineData(100, 90)]
    [InlineData(120.85, 108.77)] // 108,765 arredonda para cima (arredondamento comercial)
    public void Atacado_tem_10_por_cento_de_desconto_com_arredondamento_comercial(decimal precoBase, decimal esperado)
    {
        Assert.Equal(esperado, PedidoService.CalcularPrecoUnitario(precoBase, "Atacado"));
        Assert.Equal(precoBase, PedidoService.CalcularPrecoUnitario(precoBase, "Varejo"));
    }

    [Fact]
    public async Task Estoque_insuficiente_retorna_erro_e_nao_altera_nada()
    {
        using var contexto = _banco.NovoContexto();
        var servico = new PedidoService(contexto);

        var resultado = await servico.CriarAsync(Pedido(itens: new[] { (_banco.Jaqueta.IdProduto, 2, 0m), (_banco.Bermuda.IdProduto, 6, 0m) }));

        Assert.False(resultado.Sucesso);
        Assert.Contains("Estoque insuficiente", resultado.Erro);
        Assert.Equal(10, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));
        Assert.Equal(5, _banco.EstoqueAtual(_banco.Bermuda.IdProduto));

        using var leitura = _banco.NovoContexto();
        Assert.Equal(0, await leitura.Pedidos.CountAsync());
    }

    [Fact]
    public async Task Mesmo_produto_em_duas_linhas_soma_a_quantidade_na_validacao()
    {
        using var contexto = _banco.NovoContexto();
        var servico = new PedidoService(contexto);

        // 3 + 3 = 6 unidades, mas a bermuda so tem 5.
        var resultado = await servico.CriarAsync(Pedido(itens: new[] { (_banco.Bermuda.IdProduto, 3, 0m), (_banco.Bermuda.IdProduto, 3, 0m) }));

        Assert.False(resultado.Sucesso);
        Assert.Equal(5, _banco.EstoqueAtual(_banco.Bermuda.IdProduto));
    }

    [Fact]
    public async Task Pedido_criado_ja_cancelado_nao_mexe_no_estoque()
    {
        using var contexto = _banco.NovoContexto();
        var resultado = await new PedidoService(contexto).CriarAsync(Pedido("Cancelado", itens: new[] { (_banco.Bermuda.IdProduto, 50, 0m) }));

        Assert.True(resultado.Sucesso, resultado.Erro);
        Assert.Equal(5, _banco.EstoqueAtual(_banco.Bermuda.IdProduto));
    }

    [Fact]
    public async Task Desconto_maior_que_o_item_e_rejeitado()
    {
        using var contexto = _banco.NovoContexto();
        var resultado = await new PedidoService(contexto).CriarAsync(Pedido(itens: new[] { (_banco.Jaqueta.IdProduto, 1, 150m) }));

        Assert.False(resultado.Sucesso);
        Assert.Equal(10, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));
    }

    [Fact]
    public async Task Cancelar_devolve_estoque_e_nao_pode_cancelar_duas_vezes()
    {
        int idPedido;
        using (var contexto = _banco.NovoContexto())
        {
            idPedido = (await new PedidoService(contexto).CriarAsync(Pedido(itens: new[] { (_banco.Jaqueta.IdProduto, 4, 0m) }))).Pedido!.IdPedido;
        }

        Assert.Equal(6, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));

        using (var contexto = _banco.NovoContexto())
        {
            var servico = new PedidoService(contexto);
            Assert.True((await servico.CancelarAsync(idPedido)).Sucesso);
        }

        Assert.Equal(10, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));

        using (var contexto = _banco.NovoContexto())
        {
            var segunda = await new PedidoService(contexto).CancelarAsync(idPedido);
            Assert.False(segunda.Sucesso);
        }

        Assert.Equal(10, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));
    }

    [Fact]
    public async Task Atualizar_troca_os_itens_e_ajusta_o_estoque_dos_dois_produtos()
    {
        int idPedido;
        using (var contexto = _banco.NovoContexto())
        {
            idPedido = (await new PedidoService(contexto).CriarAsync(Pedido(itens: new[] { (_banco.Jaqueta.IdProduto, 4, 0m) }))).Pedido!.IdPedido;
        }

        using (var contexto = _banco.NovoContexto())
        {
            var resultado = await new PedidoService(contexto).AtualizarAsync(idPedido,
                Pedido(itens: new[] { (_banco.Jaqueta.IdProduto, 1, 0m), (_banco.Bermuda.IdProduto, 2, 0m) }));
            Assert.True(resultado.Sucesso, resultado.Erro);
        }

        Assert.Equal(9, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));
        Assert.Equal(3, _banco.EstoqueAtual(_banco.Bermuda.IdProduto));

        using var leitura = _banco.NovoContexto();
        Assert.Equal(2, await leitura.ItensPedido.CountAsync(i => i.IdPedido == idPedido));
    }

    [Fact]
    public async Task Atualizar_pode_usar_o_estoque_que_o_proprio_pedido_reservava()
    {
        int idPedido;
        using (var contexto = _banco.NovoContexto())
        {
            // Reserva as 5 bermudas disponiveis.
            idPedido = (await new PedidoService(contexto).CriarAsync(Pedido(itens: new[] { (_banco.Bermuda.IdProduto, 5, 0m) }))).Pedido!.IdPedido;
        }

        using (var contexto = _banco.NovoContexto())
        {
            var resultado = await new PedidoService(contexto).AtualizarAsync(idPedido, Pedido(itens: new[] { (_banco.Bermuda.IdProduto, 5, 0m) }));
            Assert.True(resultado.Sucesso, resultado.Erro);
        }

        Assert.Equal(0, _banco.EstoqueAtual(_banco.Bermuda.IdProduto));
    }

    [Fact]
    public async Task Excluir_devolve_o_estoque()
    {
        int idPedido;
        using (var contexto = _banco.NovoContexto())
        {
            idPedido = (await new PedidoService(contexto).CriarAsync(Pedido(itens: new[] { (_banco.Jaqueta.IdProduto, 2, 0m) }))).Pedido!.IdPedido;
        }

        using (var contexto = _banco.NovoContexto())
        {
            Assert.True((await new PedidoService(contexto).ExcluirAsync(idPedido)).Sucesso);
        }

        Assert.Equal(10, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));
    }

    [Fact]
    public async Task Pedido_inexistente_retorna_nao_encontrado()
    {
        using var contexto = _banco.NovoContexto();
        var resultado = await new PedidoService(contexto).CancelarAsync(9999);

        Assert.True(resultado.NaoEncontrado);
    }
}
