using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace modamax.web.Models;

// Pedido de redefinicao de senha. So o hash do token e gravado:
// quem tiver acesso ao banco nao consegue usar o link enviado por e-mail.
[Table("RecuperacaoSenha")]
public class RecuperacaoSenha
{
    [Key]
    public int IdRecuperacao { get; set; }

    public int IdUsuario { get; set; }

    [Required]
    [StringLength(64)]
    public string TokenHash { get; set; } = string.Empty;

    public DateTime CriadoEm { get; set; }

    public DateTime ExpiraEm { get; set; }

    public DateTime? UsadoEm { get; set; }

    public Usuario? Usuario { get; set; }
}
