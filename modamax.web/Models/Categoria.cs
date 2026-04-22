using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("Categoria")]
public class Categoria
{
    [Key]
    public int IdCategoria { get; set; }

    [Required]
    [StringLength(50)]
    public string Nome { get; set; } = string.Empty;

    public ICollection<Produto> Produtos { get; set; } = new List<Produto>();
}
