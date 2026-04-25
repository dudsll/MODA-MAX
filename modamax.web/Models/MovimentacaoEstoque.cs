using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("MovimentacaoEstoque")]
public class MovimentacaoEstoque
{
    [Key]
    public int IdMovi { get; set; }

    public int IdProduto { get; set; }

    [Required]
    [StringLength(20)]
    public string Tipo { get; set; } = string.Empty;

    public int Quantidade { get; set; }

    public DateTime Data { get; set; }

    [StringLength(200)]
    public string? Observacao { get; set; }

    public Produto? Produto { get; set; }
}
