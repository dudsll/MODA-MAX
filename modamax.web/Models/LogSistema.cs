using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

[Table("LogSistema")]
public class LogSistema
{
    [Key]
    public int IdLog { get; set; }

    public int? IdUsuario { get; set; }

    [Required]
    public string Acao { get; set; } = string.Empty;

    public DateTime Data { get; set; }

    public Usuario? Usuario { get; set; }
}
