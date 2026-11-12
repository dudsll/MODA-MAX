using System.ComponentModel.DataAnnotations;

namespace modamax.web.Dtos;

// Objetos trafegados pela API REST (JSON). Separam o contrato da API das entidades do banco.

public record LoginRequest(
    [Required, EmailAddress] string Email,
    [Required] string Senha);

public record LoginResponse(string Token, DateTime ExpiraEm, int IdUsuario, string Nome, string Email, string Nivel);

public record CategoriaDto(int IdCategoria, string Nome);

public record ProdutoDto(
    int IdProduto,
    string Nome,
    string? Descricao,
    string Tamanho,
    string Cor,
    decimal Preco,
    int Estoque,
    int IdCategoria,
    string? Categoria,
    int IdFornecedor,
    string? Fornecedor,
    string? CodigoBarras,
    string? FotoUrl);

public class ProdutoSalvarDto
{
    [Required, StringLength(200)]
    public string Nome { get; set; } = string.Empty;

    [StringLength(500)]
    public string? Descricao { get; set; }

    [Required, StringLength(10)]
    public string Tamanho { get; set; } = string.Empty;

    [Required, StringLength(30)]
    public string Cor { get; set; } = string.Empty;

    [Range(0, 999999)]
    public decimal Preco { get; set; }

    [Range(0, int.MaxValue)]
    public int Estoque { get; set; }

    public int IdCategoria { get; set; }

    public int IdFornecedor { get; set; }

    [StringLength(14)]
    public string? CodigoBarras { get; set; }
}

public class EntradaEstoqueDto
{
    [Range(1, int.MaxValue, ErrorMessage = "A quantidade de entrada deve ser maior que zero.")]
    public int Quantidade { get; set; }

    [StringLength(200)]
    public string? Observacao { get; set; }
}

public record ClienteDto(int IdCliente, string Nome, string Tipo, string Documento, string Email, string? Telefone, string? Endereco);

public class ClienteSalvarDto
{
    [Required, StringLength(100)]
    public string Nome { get; set; } = string.Empty;

    [Required, StringLength(10)]
    public string Tipo { get; set; } = "PF";

    [Required, StringLength(20)]
    public string Documento { get; set; } = string.Empty;

    [Required, StringLength(100), EmailAddress]
    public string Email { get; set; } = string.Empty;

    [StringLength(20)]
    public string? Telefone { get; set; }

    [StringLength(200)]
    public string? Endereco { get; set; }
}

public record ItemPedidoDto(int IdItem, int IdProduto, string? Produto, int Quantidade, decimal PrecoUnitario, decimal Desconto, decimal Subtotal);

public record PedidoDto(
    int IdPedido,
    int IdCliente,
    string? Cliente,
    DateTime DataPedido,
    string TiposVenda,
    string Status,
    decimal ValorTotal,
    IReadOnlyList<ItemPedidoDto> Itens,
    string FormaPagamento,
    int Parcelas,
    string StatusPagamento);

public class PedidoCriarDto
{
    public int IdCliente { get; set; }

    [Required]
    [RegularExpression("Varejo|Atacado")]
    public string TiposVenda { get; set; } = "Varejo";

    [MinLength(1, ErrorMessage = "O pedido precisa ter ao menos um item.")]
    public List<PedidoItemCriarDto> Itens { get; set; } = new();

    // Pix, Credito, Debito, Boleto ou Dinheiro; parcelas de 1 a 6 apenas no credito.
    [RegularExpression("Pix|Credito|Debito|Boleto|Dinheiro", ErrorMessage = "Forma de pagamento invalida.")]
    public string FormaPagamento { get; set; } = "Pix";

    [Range(1, 6, ErrorMessage = "O numero de parcelas deve ser de 1 a 6.")]
    public int Parcelas { get; set; } = 1;
}

public record PixDto(int IdPedido, decimal Valor, string CopiaECola);

public record IndicadorMetaDto(decimal Meta, decimal Realizado, int Percentual);

public record MetaDto(
    string Mes,
    bool Definida,
    IndicadorMetaDto Faturamento,
    IndicadorMetaDto Pedidos,
    IndicadorMetaDto Pecas,
    decimal ProjecaoFaturamento,
    int DiasRestantes);

public record ReposicaoDto(
    int IdProduto,
    string Produto,
    string? Categoria,
    string? FotoUrl,
    int Estoque,
    int VendidosNoPeriodo,
    int? DiasDeCobertura,
    int QuantidadeSugerida,
    string Situacao);

public class PedidoItemCriarDto
{
    public int IdProduto { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "A quantidade deve ser maior que zero.")]
    public int Quantidade { get; set; }

    [Range(0, 999999, ErrorMessage = "O desconto não pode ser negativo.")]
    public decimal Desconto { get; set; }
}

public record DashboardDto(
    int TotalProdutos,
    int TotalClientes,
    int TotalPedidos,
    decimal FaturamentoTotal,
    int ProdutosEstoqueBaixo);

// Resultados das stored procedures (mapeados com Database.SqlQuery).
public class VendaPeriodoDto
{
    public DateTime Dia { get; set; }

    public int Pedidos { get; set; }

    public int Itens { get; set; }

    public decimal Total { get; set; }
}

public class EstoqueBaixoDto
{
    public int IdProduto { get; set; }

    public string Nome { get; set; } = string.Empty;

    public string Categoria { get; set; } = string.Empty;

    public int Estoque { get; set; }
}
