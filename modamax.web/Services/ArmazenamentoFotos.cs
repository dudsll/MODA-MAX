namespace modamax.web.Services;

public class FotoInvalidaException : Exception
{
    public FotoInvalidaException(string mensagem) : base(mensagem)
    {
    }
}

// Onde as fotos dos produtos ficam guardadas. Hoje em disco; na nuvem, a proposta e
// uma implementacao com Azure Blob Storage, sem mudar controllers nem telas.
public interface IArmazenamentoFotos
{
    // Valida e grava a imagem; devolve o endereco publico da foto.
    Task<string> SalvarAsync(Stream conteudo, CancellationToken cancelamento = default);

    Task ExcluirAsync(string? url);
}

public class ArmazenamentoFotosLocal : IArmazenamentoFotos
{
    public const long TamanhoMaximo = 2 * 1024 * 1024;
    public const string UrlBase = "/uploads/produtos";

    private readonly string _pasta;

    public ArmazenamentoFotosLocal(string pasta)
    {
        _pasta = pasta;
        Directory.CreateDirectory(_pasta);
    }

    public async Task<string> SalvarAsync(Stream conteudo, CancellationToken cancelamento = default)
    {
        // Le no maximo 2 MB + 1 byte: se passar disso, a foto e recusada sem ler o resto.
        using var memoria = new MemoryStream();
        var buffer = new byte[81920];
        int lidos;
        while ((lidos = await conteudo.ReadAsync(buffer, cancelamento)) > 0)
        {
            memoria.Write(buffer, 0, lidos);
            if (memoria.Length > TamanhoMaximo)
            {
                throw new FotoInvalidaException("A foto deve ter no máximo 2 MB.");
            }
        }

        if (memoria.Length == 0)
        {
            throw new FotoInvalidaException("O arquivo da foto está vazio.");
        }

        // O tipo e decidido pelos primeiros bytes do arquivo, e nao pela extensao do nome,
        // para impedir que um arquivo qualquer seja enviado como se fosse imagem.
        var extensao = DetectarExtensao(memoria.GetBuffer().AsSpan(0, (int)Math.Min(memoria.Length, 12)))
            ?? throw new FotoInvalidaException("Envie uma imagem JPG, PNG ou WebP.");

        // Nome aleatorio: o nome enviado pelo usuario nunca e usado no disco.
        var nome = $"{Guid.NewGuid():N}{extensao}";
        memoria.Position = 0;
        await using (var arquivo = File.Create(Path.Combine(_pasta, nome)))
        {
            await memoria.CopyToAsync(arquivo, cancelamento);
        }

        return $"{UrlBase}/{nome}";
    }

    public Task ExcluirAsync(string? url)
    {
        if (string.IsNullOrWhiteSpace(url) || !url.StartsWith(UrlBase + "/", StringComparison.Ordinal))
        {
            return Task.CompletedTask;
        }

        // GetFileName descarta qualquer "../" e impede apagar arquivos fora da pasta de fotos.
        var caminho = Path.Combine(_pasta, Path.GetFileName(url));
        if (File.Exists(caminho))
        {
            File.Delete(caminho);
        }

        return Task.CompletedTask;
    }

    public static string? DetectarExtensao(ReadOnlySpan<byte> inicio)
    {
        if (inicio.Length >= 3 && inicio[0] == 0xFF && inicio[1] == 0xD8 && inicio[2] == 0xFF)
        {
            return ".jpg";
        }

        if (inicio.Length >= 8 && inicio[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
        {
            return ".png";
        }

        if (inicio.Length >= 12 && inicio[..4].SequenceEqual("RIFF"u8) && inicio[8..12].SequenceEqual("WEBP"u8))
        {
            return ".webp";
        }

        return null;
    }
}
