using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("Usuario")]
public class Usuario
{
    [Key]
    public int IdUsuario { get; set; }

    [Required]
    [StringLength(100)]
    public string Nome { get; set; } = string.Empty;

    [Required]
    [StringLength(100)]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [StringLength(100)]
    public string Senha { get; set; } = string.Empty;

    [Required]
    [StringLength(30)]
    public string Nivel { get; set; } = "Operacional";

    public ICollection<LogSistema> Logs { get; set; } = new List<LogSistema>();
}
