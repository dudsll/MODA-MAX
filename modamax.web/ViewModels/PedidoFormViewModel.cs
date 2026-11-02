using System.ComponentModel.DataAnnotations;
using modamax.web.Models;

namespace modamax.web.ViewModels;

public class PedidoFormViewModel
{
    public int? IdPedido { get; set; }

    [Required]
    [Display(Name = "Cliente")]
    public int IdCliente { get; set; }

    [Required]
    [Display(Name = "Data do Pedido")]
    public DateTime DataPedido { get; set; } = DateTime.Today;

    [Required]
    [Display(Name = "Tipo de Venda")]
    public string TiposVenda { get; set; } = "Varejo";

    [Required]
    public string Status { get; set; } = "Finalizado";

    public List<PedidoItemFormViewModel> Itens { get; set; } = new();

    public decimal ValorTotal { get; set; }

    public List<Cliente> Clientes { get; set; } = new();

    public List<Produto> Produtos { get; set; } = new();
}

public class PedidoItemFormViewModel
{
    [Display(Name = "Produto")]
    public int IdProduto { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "A quantidade deve ser maior que zero.")]
    public int Quantidade { get; set; } = 1;

    [Range(0, 999999, ErrorMessage = "Desconto invalido.")]
    public decimal Desconto { get; set; }
}
