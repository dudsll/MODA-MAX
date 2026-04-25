using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("Pedido")]
public class Pedido
{
    [Key]
    public int IdPedido { get; set; }

    public int IdCliente { get; set; }

    [Display(Name = "Data do Pedido")]
    public DateTime DataPedido { get; set; }

    [Display(Name = "Tipo de Venda")]
    [StringLength(10)]
    public string TiposVenda { get; set; } = string.Empty;

    [StringLength(50)]
    public string Status { get; set; } = string.Empty;

    [Display(Name = "Valor Total")]
    [Column(TypeName = "decimal(10,2)")]
    public decimal ValorTotal { get; set; }

    public Cliente? Cliente { get; set; }

    public ICollection<ItemPedido> Itens { get; set; } = new List<ItemPedido>();
}
