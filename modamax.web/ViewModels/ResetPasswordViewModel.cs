using System.ComponentModel.DataAnnotations;

namespace modamax.web.ViewModels;

public class ResetPasswordViewModel
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [DataType(DataType.Password)]
    [Display(Name = "Nova Senha")]
    public string NovaSenha { get; set; } = string.Empty;

    [Required]
    [DataType(DataType.Password)]
    [Compare("NovaSenha", ErrorMessage = "As senhas precisam ser iguais.")]
    [Display(Name = "Confirmar Senha")]
    public string ConfirmarSenha { get; set; } = string.Empty;
}
