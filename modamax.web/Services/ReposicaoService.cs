using Microsoft.EntityFrameworkCore;
using ModaMax.Web.Data;
using modamax.web.Models;

namespace modamax.web.Services;

public class ReposicaoOptions
{
    // Abaixo deste estoque o produto e sempre critico.
    public int EstoqueMinimo { get; set; } = 15;

    // Quantos dias de vendas entram no calculo do ritmo de saida.
    public int DiasAnalise { get; set; } = 30;

    // Prazo medio de entrega dos fornecedores.
    public int PrazoEntregaDias { get; set; } = 7;

    // Para quantos dias de vendas a reposicao deve deixar estoque.
    public int DiasCobertura { get; set; } = 30;
}

public enum SituacaoReposicao
{
    Critico,
    Atencao,
    Ok
}

public record SugestaoReposicao(
    int IdProduto,
    string Produto,
    string? Categoria,
    string? Fornecedor,
    string? FotoUrl,
    int Estoque,
    int VendidosNoPeriodo,
    decimal MediaDiaria,
    int? DiasDeCobertura,
    int QuantidadeSugerida,
    SituacaoReposicao Situacao);

// Central de reposicao: estima o ritmo de vendas de cada produto (media movel dos ultimos dias)
// e calcula quantos dias o estoque ainda dura e quanto comprar do fornecedor.
public class ReposicaoService
{
    private readonly AppDbContext _context;
    private readonly ReposicaoOptions _opcoes;

    public ReposicaoService(AppDbContext context, ReposicaoOptions opcoes)
    {
        _context = context;
        _opcoes = opcoes;
    }

    public ReposicaoOptions Opcoes => _opcoes;

    public async Task<List<SugestaoReposicao>> CalcularAsync(DateTime? hoje = null)
    {
        var inicio = (hoje ?? DateTime.Today).Date.AddDays(-_opcoes.DiasAnalise + 1);

        var vendidos = (await _context.ItensPedido
                .AsNoTracking()
                .Where(i => i.Pedido!.Status != PedidoService.StatusCancelado && i.Pedido.DataPedido >= inicio)
                .Select(i => new { i.IdProduto, i.Quantidade })
                .ToListAsync())
            .GroupBy(i => i.IdProduto)
            .ToDictionary(g => g.Key, g => g.Sum(i => i.Quantidade));

        var produtos = await _context.Produtos
            .AsNoTracking()
            .Select(p => new { p.IdProduto, p.Nome, Categoria = p.Categoria!.Nome, Fornecedor = p.Fornecedor!.Nome, p.FotoUrl, p.Estoque })
            .ToListAsync();

        return produtos
            .Select(p => Calcular(p.IdProduto, p.Nome, p.Categoria, p.Fornecedor, p.FotoUrl, p.Estoque, vendidos.GetValueOrDefault(p.IdProduto)))
            .OrderBy(s => s.Situacao)
            .ThenBy(s => s.DiasDeCobertura ?? int.MaxValue)
            .ThenBy(s => s.Estoque)
            .ToList();
    }

    public SugestaoReposicao Calcular(int id, string nome, string? categoria, string? fornecedor, string? foto, int estoque, int vendidos)
    {
        var media = Math.Round((decimal)vendidos / _opcoes.DiasAnalise, 2, MidpointRounding.AwayFromZero);
        int? cobertura = media > 0 ? (int)Math.Floor(estoque / media) : null;

        // Estoque-alvo: o que se vende durante a entrega + o periodo de cobertura, nunca abaixo do minimo.
        var alvo = Math.Max((int)Math.Ceiling(media * (_opcoes.PrazoEntregaDias + _opcoes.DiasCobertura)), _opcoes.EstoqueMinimo * 2);
        var sugestao = Math.Max(0, alvo - estoque);

        var situacao =
            estoque <= _opcoes.EstoqueMinimo || cobertura <= _opcoes.PrazoEntregaDias ? SituacaoReposicao.Critico
            : cobertura <= _opcoes.PrazoEntregaDias + _opcoes.DiasCobertura / 2 ? SituacaoReposicao.Atencao
            : SituacaoReposicao.Ok;

        return new SugestaoReposicao(id, nome, categoria, fornecedor, foto, estoque, vendidos, media, cobertura,
            situacao == SituacaoReposicao.Ok ? 0 : sugestao, situacao);
    }

    // Numero mostrado no menu lateral: produtos criticos ou em atencao.
    public async Task<int> ContarParaReporAsync()
    {
        return (await CalcularAsync()).Count(s => s.Situacao != SituacaoReposicao.Ok);
    }

    // Entrada de mercadoria. No SQL Server usa a procedure sp_RegistrarEntradaEstoque; no modo
    // SQLite de demonstracao (sem procedures) faz a mesma operacao em uma transacao.
    // Devolve o novo estoque, ou null se o produto nao existir.
    public async Task<int?> RegistrarEntradaAsync(int idProduto, int quantidade, string? observacao)
    {
        if (quantidade <= 0) throw new ArgumentOutOfRangeException(nameof(quantidade), "A quantidade de entrada deve ser maior que zero.");
        if (!await _context.Produtos.AnyAsync(p => p.IdProduto == idProduto)) return null;

        if (_context.Database.IsSqlServer())
        {
            return (await _context.Database
                    .SqlQuery<int>($"EXEC dbo.sp_RegistrarEntradaEstoque @IdProduto = {idProduto}, @Quantidade = {quantidade}, @Observacao = {observacao}")
                    .ToListAsync())
                .Single();
        }

        await using var transacao = await _context.Database.BeginTransactionAsync();
        var produto = await _context.Produtos.SingleAsync(p => p.IdProduto == idProduto);
        produto.Estoque += quantidade;
        _context.MovimentacoesEstoque.Add(new MovimentacaoEstoque
        {
            IdProduto = idProduto,
            Tipo = "Entrada",
            Quantidade = quantidade,
            Data = DateTime.Now,
            Observacao = observacao ?? "Entrada de mercadoria"
        });
        await _context.SaveChangesAsync();
        await transacao.CommitAsync();
        return produto.Estoque;
    }
}
