using Microsoft.EntityFrameworkCore;
using modamax.web.Models;
using modamax.web.Services;

namespace ModaMax.Tests;

public class PixTests
{
    private readonly PixService _pix = new(new PixOptions { Chave = "chave-teste", NomeRecebedor = "ModaMax Distribuição Ltda de Moda", Cidade = "São Paulo" });

    [Fact]
    public void Crc16_segue_o_padrao_ccitt_exigido_pelo_banco_central()
    {
        // Valor de referencia do CRC-16/CCITT-FALSE para a sequencia "123456789".
        Assert.Equal(0x29B1, PixService.Crc16("123456789"));
    }

    [Fact]
    public void Payload_tem_os_campos_do_br_code_e_crc_valido()
    {
        var payload = _pix.GerarPayload(605.13m, "PEDIDO-55");

        Assert.StartsWith("000201", payload);
        Assert.Contains("0014br.gov.bcb.pix0111chave-teste", payload);
        Assert.Contains("5303986", payload);              // moeda: real
        Assert.Contains("5406605.13", payload);           // valor com ponto e duas casas
        Assert.Contains("5802BR", payload);
        Assert.Contains("5925MODAMAX DISTRIBUICAO LTDA", payload); // sem acentos, maiusculo, ate 25 letras
        Assert.Contains("6009SAO PAULO", payload);
        Assert.Contains("0508PEDIDO55", payload);         // identificador so com letras e numeros

        var semCrc = payload[..^4];
        Assert.EndsWith("6304", semCrc);
        Assert.Equal(PixService.Crc16(semCrc).ToString("X4"), payload[^4..]);
    }

    [Fact]
    public void Qr_code_e_gerado_em_svg()
    {
        var svg = PixService.GerarQrCodeSvg(_pix.GerarPayload(10m, "PEDIDO1"));
        Assert.StartsWith("<svg", svg.TrimStart());
    }

    [Theory]
    [InlineData("Pix", 1, null)]
    [InlineData("Credito", 6, null)]
    [InlineData("Pix", 2, "Apenas o cartao de credito pode ser parcelado.")]
    [InlineData("Credito", 7, "O numero de parcelas deve ser de 1 a 6.")]
    [InlineData("Cheque", 1, "Forma de pagamento invalida.")]
    public void Regras_de_pagamento(string forma, int parcelas, string? erro)
    {
        Assert.Equal(erro, Pagamentos.Validar(forma, parcelas));
    }
}

public class PagamentoPedidoTests : IDisposable
{
    private readonly BancoDeTeste _banco = new();

    public void Dispose() => _banco.Dispose();

    private async Task<Pedido> CriarAsync(string forma = "Pix", int parcelas = 1)
    {
        using var contexto = _banco.NovoContexto();
        var resultado = await new PedidoService(contexto).CriarAsync(new DadosPedido
        {
            IdCliente = _banco.Cliente.IdCliente,
            Status = PedidoService.StatusFinalizado,
            FormaPagamento = forma,
            Parcelas = parcelas,
            Itens = new[] { new ItemPedidoEntrada { IdProduto = _banco.Jaqueta.IdProduto, Quantidade = 1 } }
        });
        Assert.True(resultado.Sucesso, resultado.Erro);
        return resultado.Pedido!;
    }

    [Fact]
    public async Task Pedido_novo_guarda_a_forma_e_comeca_pendente()
    {
        var pedido = await CriarAsync("Credito", 3);

        Assert.Equal("Credito", pedido.FormaPagamento);
        Assert.Equal(3, pedido.Parcelas);
        Assert.Equal(Pagamentos.Pendente, pedido.StatusPagamento);
    }

    [Fact]
    public async Task Parcelas_fora_da_regra_sao_recusadas()
    {
        using var contexto = _banco.NovoContexto();
        var resultado = await new PedidoService(contexto).CriarAsync(new DadosPedido
        {
            IdCliente = _banco.Cliente.IdCliente,
            FormaPagamento = "Pix",
            Parcelas = 3,
            Itens = new[] { new ItemPedidoEntrada { IdProduto = _banco.Jaqueta.IdProduto, Quantidade = 1 } }
        });

        Assert.False(resultado.Sucesso);
        Assert.Equal(10, _banco.EstoqueAtual(_banco.Jaqueta.IdProduto));
    }

    [Fact]
    public async Task Confirmar_pagamento_marca_pago_uma_unica_vez()
    {
        var pedido = await CriarAsync();

        using (var contexto = _banco.NovoContexto())
        {
            var servico = new PedidoService(contexto);
            Assert.True((await servico.ConfirmarPagamentoAsync(pedido.IdPedido)).Sucesso);
            Assert.False((await servico.ConfirmarPagamentoAsync(pedido.IdPedido)).Sucesso);
        }

        using var verificacao = _banco.NovoContexto();
        var salvo = verificacao.Pedidos.AsNoTracking().Single(p => p.IdPedido == pedido.IdPedido);
        Assert.Equal(Pagamentos.Pago, salvo.StatusPagamento);
        Assert.NotNull(salvo.PagoEm);
    }

    [Fact]
    public async Task Cancelar_pedido_pago_estorna_e_pedido_cancelado_nao_pode_ser_pago()
    {
        var pago = await CriarAsync();
        var pendente = await CriarAsync();

        using (var contexto = _banco.NovoContexto())
        {
            var servico = new PedidoService(contexto);
            await servico.ConfirmarPagamentoAsync(pago.IdPedido);
            await servico.CancelarAsync(pago.IdPedido);
            await servico.CancelarAsync(pendente.IdPedido);
            Assert.False((await servico.ConfirmarPagamentoAsync(pendente.IdPedido)).Sucesso);
        }

        using var verificacao = _banco.NovoContexto();
        Assert.Equal(Pagamentos.Estornado, verificacao.Pedidos.AsNoTracking().Single(p => p.IdPedido == pago.IdPedido).StatusPagamento);
        Assert.Equal(Pagamentos.Pendente, verificacao.Pedidos.AsNoTracking().Single(p => p.IdPedido == pendente.IdPedido).StatusPagamento);
    }
}

public class EtiquetaEan13Tests
{
    [Fact]
    public void Ean13_tem_95_modulos_com_guardas_nas_posicoes_certas()
    {
        var modulos = CodigoBarras.ModulosEan13("7891234500014")!;

        Assert.Equal(95, modulos.Length);
        Assert.StartsWith("101", modulos);
        Assert.Equal("01010", modulos.Substring(45, 5));
        Assert.EndsWith("101", modulos);
    }

    [Fact]
    public void Lado_direito_e_o_complemento_do_lado_esquerdo_para_o_mesmo_digito()
    {
        // Com o primeiro digito 0, o lado esquerdo usa so o codigo L; o codigo R e o seu complemento.
        var codigo = CodigoBarras.Gerar("012345612345");
        var modulos = CodigoBarras.ModulosEan13(codigo)!;
        string Esquerda(int i) => modulos.Substring(3 + i * 7, 7);
        string Direita(int i) => modulos.Substring(50 + i * 7, 7);
        string Complemento(string s) => new(s.Select(c => c == '1' ? '0' : '1').ToArray());

        for (var i = 0; i < 5; i++)
        {
            Assert.Equal(Complemento(Esquerda(i)), Direita(i));
        }
    }

    [Fact]
    public void Codigo_g_e_o_codigo_r_espelhado()
    {
        // Primeiro digito 1 => paridade LLGLGG: o 3o digito (5) usa o codigo G.
        var codigo = CodigoBarras.Gerar("100500005000");
        var modulos = CodigoBarras.ModulosEan13(codigo)!;
        var g5 = modulos.Substring(3 + 2 * 7, 7);
        var r5 = modulos.Substring(50 + 1 * 7, 7);   // 2o digito do lado direito
        Assert.Equal(new string(r5.Reverse().ToArray()), g5);
    }

    [Fact]
    public void Codigo_invalido_nao_gera_barras()
    {
        Assert.Null(CodigoBarras.ModulosEan13("7891234500015"));
        Assert.Null(CodigoBarras.SvgEan13(null));
        Assert.Contains("aria-label=\"Código de barras 0036000291452\"", CodigoBarras.SvgEan13("036000291452"));
    }
}

public class ReposicaoTests : IDisposable
{
    private readonly BancoDeTeste _banco = new();
    private readonly ReposicaoOptions _opcoes = new() { EstoqueMinimo = 15, DiasAnalise = 30, PrazoEntregaDias = 7, DiasCobertura = 30 };

    public void Dispose() => _banco.Dispose();

    private ReposicaoService Servico(ModaMax.Web.Data.AppDbContext contexto) => new(contexto, _opcoes);

    [Fact]
    public void Calculo_de_cobertura_e_sugestao()
    {
        using var contexto = _banco.NovoContexto();
        var servico = Servico(contexto);

        // 30 vendidos em 30 dias = 1 por dia; 30 em estoque duram 30 dias.
        var atencao = servico.Calcular(1, "A", null, null, null, estoque: 20, vendidos: 30);
        Assert.Equal(1m, atencao.MediaDiaria);
        Assert.Equal(20, atencao.DiasDeCobertura);
        Assert.Equal(SituacaoReposicao.Atencao, atencao.Situacao);
        Assert.Equal(37 - 20, atencao.QuantidadeSugerida);   // 1/dia x (7 + 30 dias)

        var critico = servico.Calcular(2, "B", null, null, null, estoque: 5, vendidos: 3);
        Assert.Equal(SituacaoReposicao.Critico, critico.Situacao);
        Assert.Equal(30 - 5, critico.QuantidadeSugerida);    // nunca abaixo de 2x o minimo

        var parado = servico.Calcular(3, "C", null, null, null, estoque: 80, vendidos: 0);
        Assert.Null(parado.DiasDeCobertura);
        Assert.Equal(SituacaoReposicao.Ok, parado.Situacao);
        Assert.Equal(0, parado.QuantidadeSugerida);
    }

    [Fact]
    public async Task Entrada_de_estoque_funciona_tambem_no_modo_sqlite()
    {
        using (var contexto = _banco.NovoContexto())
        {
            Assert.Equal(17, await Servico(contexto).RegistrarEntradaAsync(_banco.Bermuda.IdProduto, 12, "Teste"));
            Assert.Null(await Servico(contexto).RegistrarEntradaAsync(9999, 1, null));
        }

        using var verificacao = _banco.NovoContexto();
        Assert.Contains(verificacao.MovimentacoesEstoque, m => m.IdProduto == _banco.Bermuda.IdProduto && m.Tipo == "Entrada" && m.Quantidade == 12);
    }

    [Fact]
    public async Task Produtos_com_estoque_baixo_aparecem_primeiro()
    {
        using var contexto = _banco.NovoContexto();
        var lista = await Servico(contexto).CalcularAsync();

        Assert.Equal("Bermuda Jeans", lista[0].Produto);   // 5 em estoque: critico
        Assert.Equal(2, await Servico(contexto).ContarParaReporAsync());   // os dois produtos estao abaixo do minimo
    }
}

public class MetaECurvaAbcTests : IDisposable
{
    private readonly BancoDeTeste _banco = new();
    private static readonly DateTime Hoje = new(2026, 11, 10);

    public void Dispose() => _banco.Dispose();

    private void Vender(DateTime data, decimal valor, int pecas, int? idProduto = null, string status = PedidoService.StatusFinalizado)
    {
        using var contexto = _banco.NovoContexto();
        contexto.Pedidos.Add(new Pedido
        {
            IdCliente = _banco.Cliente.IdCliente,
            DataPedido = data,
            TiposVenda = "Varejo",
            Status = status,
            ValorTotal = valor,
            Itens = { new ItemPedido { IdProduto = idProduto ?? _banco.Jaqueta.IdProduto, Quantidade = pecas, PrecoUnitario = valor / pecas } }
        });
        contexto.SaveChanges();
    }

    [Fact]
    public async Task Progresso_compara_o_realizado_com_a_meta_e_projeta_o_mes()
    {
        using (var contexto = _banco.NovoContexto())
        {
            await new MetaService(contexto).SalvarAsync(new Meta { Ano = 2026, Mes = 11, Faturamento = 1000, Pedidos = 4, Pecas = 10 });
        }

        Vender(new DateTime(2026, 11, 2), 300, 3);
        Vender(new DateTime(2026, 11, 5), 200, 2);
        Vender(new DateTime(2026, 11, 6), 999, 9, status: PedidoService.StatusCancelado);   // nao conta

        using var leitura = _banco.NovoContexto();
        var progresso = await new MetaService(leitura).ProgressoAsync(Hoje);

        Assert.True(progresso.Definida);
        Assert.Equal(50, progresso.Faturamento.Percentual);
        Assert.Equal(50, progresso.Pedidos.Percentual);
        Assert.Equal(50, progresso.Pecas.Percentual);
        Assert.Equal(1500m, progresso.ProjecaoFaturamento);   // 500 em 10 dias -> 30 dias
        Assert.Equal(25m, progresso.NecessarioPorDia);         // faltam 500 em 20 dias
        Assert.Equal("Novembro de 2026", progresso.NomeMes);
    }

    [Fact]
    public async Task Sem_meta_cadastrada_sugere_a_media_dos_tres_meses_anteriores_mais_10_por_cento()
    {
        Vender(new DateTime(2026, 8, 10), 1000, 10);
        Vender(new DateTime(2026, 9, 10), 2000, 10);
        Vender(new DateTime(2026, 10, 10), 3000, 10);

        using var contexto = _banco.NovoContexto();
        var sugerida = await new MetaService(contexto).SugerirAsync(2026, 11);

        Assert.Equal(2200m, sugerida.Faturamento);   // media 2000 + 10%
        Assert.Equal(2, sugerida.Pedidos);           // 1,1 arredondado para cima
        Assert.Equal(11, sugerida.Pecas);
    }

    [Fact]
    public async Task Curva_abc_classifica_pelo_faturamento_acumulado()
    {
        Vender(Hoje, 850, 5, _banco.Jaqueta.IdProduto);
        Vender(Hoje, 150, 1, _banco.Bermuda.IdProduto);

        using var contexto = _banco.NovoContexto();
        var curva = await new RelatorioService(contexto).CurvaAbcAsync(null, null);

        Assert.Equal('A', curva[0].Classe);        // 85% do faturamento (cruza os 80%, continua A)
        Assert.Equal(85m, curva[0].Participacao);
        Assert.Equal('B', curva[1].Classe);        // comeca depois dos 80%
        Assert.Equal(100m, curva[1].Acumulado);
    }
}
