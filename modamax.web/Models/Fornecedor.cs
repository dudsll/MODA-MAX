using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("Fornecedor")]
public class Fornecedor
{
    [Key]
    public int IdFornecedor { get; set; }

    [Required]
    [StringLength(100)]
    public string Nome { get; set; } = string.Empty;

    [StringLength(20)]
    public string? CNPJ { get; set; }

    [StringLength(100)]
    public string? Contato { get; set; }

    [StringLength(20)]
    public string? Telefone { get; set; }

    public ICollection<Produto> Produtos { get; set; } = new List<Produto>();
}
