using System.Net;
using System.Net.Mail;

namespace modamax.web.Services;

public interface IEmailService
{
    // Indica se o e-mail sai de verdade (SMTP) ou so vai para o log (desenvolvimento).
    bool EnviaDeVerdade { get; }

    Task EnviarAsync(string destinatario, string assunto, string corpoHtml);
}

public class SmtpOptions
{
    public string Host { get; set; } = string.Empty;

    public int Porta { get; set; } = 587;

    public string Usuario { get; set; } = string.Empty;

    public string Senha { get; set; } = string.Empty;

    public string Remetente { get; set; } = string.Empty;
}

// Envio real por SMTP (ex.: Gmail com senha de app, Outlook, SendGrid).
public class SmtpEmailService : IEmailService
{
    private readonly SmtpOptions _options;

    public SmtpEmailService(SmtpOptions options)
    {
        _options = options;
    }

    public bool EnviaDeVerdade => true;

    public async Task EnviarAsync(string destinatario, string assunto, string corpoHtml)
    {
        using var mensagem = new MailMessage(_options.Remetente, destinatario, assunto, corpoHtml) { IsBodyHtml = true };
        using var cliente = new SmtpClient(_options.Host, _options.Porta)
        {
            EnableSsl = true,
            Credentials = new NetworkCredential(_options.Usuario, _options.Senha)
        };

        await cliente.SendMailAsync(mensagem);
    }
}

// Sem SMTP configurado: escreve o e-mail no log do servidor.
public class LogEmailService : IEmailService
{
    private readonly ILogger<LogEmailService> _logger;

    public LogEmailService(ILogger<LogEmailService> logger)
    {
        _logger = logger;
    }

    public bool EnviaDeVerdade => false;

    public Task EnviarAsync(string destinatario, string assunto, string corpoHtml)
    {
        _logger.LogWarning("SMTP nao configurado. E-mail para {Destinatario} | {Assunto}\n{Corpo}", destinatario, assunto, corpoHtml);
        return Task.CompletedTask;
    }
}
