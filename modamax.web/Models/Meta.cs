using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

// Meta de vendas de um mes, definida pela diretoria e acompanhada nos aneis do painel.
[Table("Meta")]
public class Meta
{
    [Key]
    public int IdMeta { get; set; }

    [Range(2020, 2100)]
    public int Ano { get; set; }

    [Range(1, 12)]
    public int Mes { get; set; }

    [Display(Name = "Faturamento")]
    [Column(TypeName = "decimal(12,2)")]
    [Range(0, 99999999, ErrorMessage = "Informe um faturamento válido.")]
    public decimal Faturamento { get; set; }

    [Display(Name = "Pedidos")]
    [Range(0, 100000, ErrorMessage = "Informe uma quantidade de pedidos válida.")]
    public int Pedidos { get; set; }

    [Display(Name = "Peças vendidas")]
    [Range(0, 1000000, ErrorMessage = "Informe uma quantidade de peças válida.")]
    public int Pecas { get; set; }
}
