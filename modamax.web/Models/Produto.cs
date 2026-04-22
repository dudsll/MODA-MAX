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

    [Display(Name = "Descricao")]
    [StringLength(500)]
    public string? Descricao { get; set; }

    [Required(ErrorMessage = "Informe o tamanho.")]
    [StringLength(10)]
    public string Tamanho { get; set; } = string.Empty;

    [Required(ErrorMessage = "Informe a cor.")]
    [StringLength(30)]
    public string Cor { get; set; } = string.Empty;

    [Required(ErrorMessage = "Informe o preco.")]
    [Column(TypeName = "decimal(10,2)")]
    [Display(Name = "Preco")]
    public decimal Preco { get; set; }

    [Required(ErrorMessage = "Informe o estoque.")]
    public int Estoque { get; set; }

    [Display(Name = "Categoria")]
    public int IdCategoria { get; set; }

    [Display(Name = "Fornecedor")]
    public int IdFornecedor { get; set; }

    public Categoria? Categoria { get; set; }

    public Fornecedor? Fornecedor { get; set; }
}
