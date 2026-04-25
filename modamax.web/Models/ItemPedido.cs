using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("ItemPedido")]
public class ItemPedido
{
    [Key]
    public int IdItem { get; set; }

    public int IdPedido { get; set; }

    public int IdProduto { get; set; }

    public int Quantidade { get; set; }

    [Column(TypeName = "decimal(10,2)")]
    [Display(Name = "Preco Unitario")]
    public decimal PrecoUnitario { get; set; }

    [Column(TypeName = "decimal(10,2)")]
    public decimal Desconto { get; set; }

    public Pedido? Pedido { get; set; }

    public Produto? Produto { get; set; }
}
