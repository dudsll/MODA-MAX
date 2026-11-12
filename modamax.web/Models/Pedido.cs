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

    // Pagamento: forma (Pix, Credito, Debito, Boleto, Dinheiro), parcelas (so no credito) e situacao.
    [Display(Name = "Forma de pagamento")]
    [StringLength(20)]
    public string FormaPagamento { get; set; } = "Pix";

    [Range(1, 6)]
    public int Parcelas { get; set; } = 1;

    [Display(Name = "Pagamento")]
    [StringLength(20)]
    public string StatusPagamento { get; set; } = "Pendente";

    public DateTime? PagoEm { get; set; }

    public Cliente? Cliente { get; set; }

    public ICollection<ItemPedido> Itens { get; set; } = new List<ItemPedido>();
}
