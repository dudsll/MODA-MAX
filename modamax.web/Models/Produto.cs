using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("Produto")]
public class Produto
{
    [Key]
    [Display(Name = "Codigo")]
    public int IdProduto { get; set; }

    [Required(ErrorMessage = "Informe o nome do produto.")]
    [StringLength(200)]
    public string Nome { get; set; } = string.Empty;

    [Display(Name = "Descrição")]
    [StringLength(500)]
    public string? Descricao { get; set; }

    [Required(ErrorMessage = "Informe o tamanho.")]
    [StringLength(10)]
    public string Tamanho { get; set; } = string.Empty;

    [Required(ErrorMessage = "Informe a cor.")]
    [StringLength(30)]
    public string Cor { get; set; } = string.Empty;

    [Required(ErrorMessage = "Informe o preço.")]
    [Column("Preco", TypeName = "decimal(10,2)")]
    [Display(Name = "Preço")]
    public decimal Preco { get; set; }

    [Required(ErrorMessage = "Informe o estoque.")]
    public int Estoque { get; set; }

    [Display(Name = "Categoria")]
    public int IdCategoria { get; set; }

    [Display(Name = "Fornecedor")]
    public int IdFornecedor { get; set; }

    // Codigo GTIN/EAN impresso na etiqueta (8, 12, 13 ou 14 digitos), lido pelo app com a camera.
    [Display(Name = "Código de barras")]
    [StringLength(14)]
    public string? CodigoBarras { get; set; }

    // Endereco publico da foto (ex.: /uploads/produtos/abc.jpg). O arquivo fica no armazenamento de fotos.
    [StringLength(300)]
    public string? FotoUrl { get; set; }

    public Categoria? Categoria { get; set; }

    public Fornecedor? Fornecedor { get; set; }
}
