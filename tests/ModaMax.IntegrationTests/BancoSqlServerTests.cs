using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using modamax.web.Models;
using modamax.web.Services;

namespace ModaMax.IntegrationTests;

// Verifica no SQL Server real o que o SQLite dos testes unitarios nao tem:
// procedures, triggers, restricoes CHECK, indices filtrados e transacoes com retry.
[Collection(ColecaoSqlServer.Nome)]
public class BancoSqlServerTests
{
    private readonly SqlServerFixture _banco;

    public BancoSqlServerTests(SqlServerFixture banco)
    {
        _banco = banco;
    }

    private async Task<Produto> ProdutoAsync(string nome)
    {
        await using var contexto = _banco.NovoContexto();
        return await contexto.Produtos.AsNoTracking().SingleAsync(p => p.Nome == nome);
    }

    [FactSqlServer]
    public async Task Migrations_criam_as_procedures_e_os_triggers()
    {
        await using var contexto = _banco.NovoContexto();
        var objetos = await contexto.Database
            .SqlQuery<string>($"SELECT name AS Value FROM sys.objects WHERE type IN ('P', 'TR')")
            .ToListAsync();

        Assert.Contains("sp_RelatorioVendasPeriodo", objetos);
        Assert.Contains("sp_ProdutosEstoqueBaixo", objetos);
        Assert.Contains("sp_RegistrarEntradaEstoque", objetos);
        Assert.Contains("trg_Produto_AuditaPreco", objetos);
        Assert.Contains("trg_Pedido_AuditaStatus", objetos);
    }

    [FactSqlServer]
    public async Task Procedure_de_entrada_soma_o_estoque_e_registra_a_movimentacao()
    {
        var produto = await ProdutoAsync("Colete Jeans");

        await using var contexto = _banco.NovoContexto();
        var estoque = (await contexto.Database
            .SqlQuery<int>($"EXEC dbo.sp_RegistrarEntradaEstoque @IdProduto = {produto.IdProduto}, @Quantidade = {7}, @Observacao = {"Teste de integracao"}")
            .ToListAsync()).Single();

        Assert.Equal(produto.Estoque + 7, estoque);
        Assert.True(await contexto.MovimentacoesEstoque.AnyAsync(m =>
            m.IdProduto == produto.IdProduto && m.Tipo == "Entrada" && m.Quantidade == 7 && m.Observacao == "Teste de integracao"));
    }

    [FactSqlServer]
    public async Task Procedure_de_entrada_recusa_quantidade_zero()
    {
        var produto = await ProdutoAsync("Colete Jeans");

        await using var contexto = _banco.NovoContexto();
        var erro = await Assert.ThrowsAsync<SqlException>(() => contexto.Database
            .SqlQuery<int>($"EXEC dbo.sp_RegistrarEntradaEstoque @IdProduto = {produto.IdProduto}, @Quantidade = {0}")
            .ToListAsync());

        Assert.Equal(50001, erro.Number);
    }

    [FactSqlServer]
    public async Task Procedure_de_estoque_baixo_lista_so_os_produtos_abaixo_do_limite()
    {
        await using (var preparo = _banco.NovoContexto())
        {
            var saia = await preparo.Produtos.SingleAsync(p => p.Nome == "Saia Jeans");
            saia.Estoque = 3;
            await preparo.SaveChangesAsync();
        }

        await using var contexto = _banco.NovoContexto();
        var produtos = await contexto.Database
            .SqlQuery<modamax.web.Dtos.EstoqueBaixoDto>($"EXEC dbo.sp_ProdutosEstoqueBaixo @Limite = {5}")
            .ToListAsync();

        Assert.Contains(produtos, p => p.Nome == "Saia Jeans" && p.Estoque == 3);
        Assert.All(produtos, p => Assert.True(p.Estoque <= 5));
    }

    [FactSqlServer]
    public async Task Relatorio_da_procedure_bate_com_o_relatorio_da_aplicacao()
    {
        var inicio = DateTime.Today.AddDays(-120);
        var fim = DateTime.Today;

        await using var contexto = _banco.NovoContexto();
        var porDia = await contexto.Database
            .SqlQuery<modamax.web.Dtos.VendaPeriodoDto>($"EXEC dbo.sp_RelatorioVendasPeriodo @DataInicial = {inicio}, @DataFinal = {fim}")
            .ToListAsync();
        var aplicacao = await new RelatorioService(contexto).GerarAsync(inicio, fim);

        Assert.NotEmpty(porDia);
        Assert.Equal(aplicacao.Faturamento, porDia.Sum(d => d.Total));
        Assert.Equal(aplicacao.TotalPedidos, porDia.Sum(d => d.Pedidos));
    }

    [FactSqlServer]
    public async Task Trigger_registra_a_mudanca_de_preco_no_log()
    {
        await using (var contexto = _banco.NovoContexto())
        {
            var blusa = await contexto.Produtos.SingleAsync(p => p.Nome == "Blusa Jeans");
            blusa.Preco += 1.50m;
            await contexto.SaveChangesAsync();
        }

        await using var verificacao = _banco.NovoContexto();
        Assert.True(await verificacao.LogsSistema.AnyAsync(l => l.Acao.Contains("preco do produto") && l.Acao.Contains("Blusa Jeans")));
    }

    [FactSqlServer]
    public async Task Cancelar_pedido_devolve_o_estoque_e_o_trigger_audita_o_status()
    {
        var bermuda = await ProdutoAsync("Bermuda Jeans");
        int idPedido;

        await using (var contexto = _banco.NovoContexto())
        {
            var servico = new PedidoService(contexto);
            var criado = await servico.CriarAsync(new DadosPedido
            {
                IdCliente = (await contexto.Clientes.FirstAsync()).IdCliente,
                TiposVenda = "Atacado",
                Status = PedidoService.StatusFinalizado,
                Itens = new[] { new ItemPedidoEntrada { IdProduto = bermuda.IdProduto, Quantidade = 3 } }
            });
            Assert.True(criado.Sucesso, criado.Erro);
            idPedido = criado.Pedido!.IdPedido;
            // Atacado: 10% de desconto com arredondamento comercial (120,85 -> 108,77).
            Assert.Equal(3 * 108.77m, criado.Pedido.ValorTotal);
        }

        Assert.Equal(bermuda.Estoque - 3, (await ProdutoAsync("Bermuda Jeans")).Estoque);

        await using (var contexto = _banco.NovoContexto())
        {
            var cancelado = await new PedidoService(contexto).CancelarAsync(idPedido);
            Assert.True(cancelado.Sucesso, cancelado.Erro);
        }

        Assert.Equal(bermuda.Estoque, (await ProdutoAsync("Bermuda Jeans")).Estoque);
        await using var verificacao = _banco.NovoContexto();
        Assert.True(await verificacao.LogsSistema.AnyAsync(l => l.Acao.Contains($"pedido #{idPedido} mudou de")));
    }

    [FactSqlServer]
    public async Task Restricao_check_impede_estoque_negativo()
    {
        await using var contexto = _banco.NovoContexto();
        var calca = await contexto.Produtos.SingleAsync(p => p.Nome == "Calca Jeans");
        calca.Estoque = -1;

        var erro = await Assert.ThrowsAsync<DbUpdateException>(() => contexto.SaveChangesAsync());
        Assert.Contains("CK_Produto_Estoque", erro.InnerException?.Message);
    }

    [FactSqlServer]
    public async Task Codigo_de_barras_e_unico_mas_varios_produtos_podem_ficar_sem_codigo()
    {
        var existente = await ProdutoAsync("Macaquinho Jeans");

        await using (var contexto = _banco.NovoContexto())
        {
            var categoria = await contexto.Categorias.FirstAsync();
            var fornecedor = await contexto.Fornecedores.FirstAsync();
            contexto.Produtos.AddRange(
                new Produto { Nome = "Sem codigo 1", Tamanho = "P", Cor = "Azul", Preco = 10, Estoque = 1, Categoria = categoria, Fornecedor = fornecedor },
                new Produto { Nome = "Sem codigo 2", Tamanho = "M", Cor = "Azul", Preco = 10, Estoque = 1, Categoria = categoria, Fornecedor = fornecedor });
            await contexto.SaveChangesAsync();
        }

        await using var duplicado = _banco.NovoContexto();
        duplicado.Produtos.Add(new Produto
        {
            Nome = "Duplicado", Tamanho = "G", Cor = "Azul", Preco = 10, Estoque = 1,
            IdCategoria = existente.IdCategoria, IdFornecedor = existente.IdFornecedor,
            CodigoBarras = existente.CodigoBarras
        });

        await Assert.ThrowsAsync<DbUpdateException>(() => duplicado.SaveChangesAsync());
    }

    [FactSqlServer]
    public async Task Bloqueio_de_login_e_gravado_no_banco()
    {
        await using (var contexto = _banco.NovoContexto())
        {
            var servico = new LoginService(contexto, new SegurancaOptions { MaxTentativasLogin = 2 });
            await servico.AutenticarAsync("operacional@modamax.com", "errada");
            var resultado = await servico.AutenticarAsync("operacional@modamax.com", "errada");
            Assert.Equal(SituacaoLogin.Bloqueado, resultado.Situacao);
        }

        await using var verificacao = _banco.NovoContexto();
        var usuario = await verificacao.Usuarios.AsNoTracking().SingleAsync(u => u.Email == "operacional@modamax.com");
        Assert.True(usuario.BloqueadoAte > DateTime.UtcNow);
    }
}
