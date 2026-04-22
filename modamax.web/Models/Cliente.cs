using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("Cliente")]
public class Cliente
{
    [Key]
    [Display(Name = "Codigo")]
    public int IdCliente { get; set; }

    [Required(ErrorMessage = "Informe o nome do cliente.")]
    [StringLength(100)]
    public string Nome { get; set; } = string.Empty;

    [Required(ErrorMessage = "Informe o tipo.")]
    [StringLength(10)]
    public string Tipo { get; set; } = "PF";

    [Required(ErrorMessage = "Informe o documento.")]
    [StringLength(20)]
    public string Documento { get; set; } = string.Empty;

    [Required(ErrorMessage = "Informe o email.")]
    [StringLength(100)]
    [EmailAddress(ErrorMessage = "Informe um email valido.")]
    public string Email { get; set; } = string.Empty;

    [Display(Name = "Telefone")]
    [StringLength(20)]
    public string? Telefone { get; set; }

    [Display(Name = "Endereco")]
    [StringLength(200)]
    public string? Endereco { get; set; }

    public ICollection<Pedido> Pedidos { get; set; } = new List<Pedido>();
}
