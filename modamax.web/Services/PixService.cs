using System.Globalization;
using System.Text;
using QRCoder;

namespace modamax.web.Services;

// Formas e situacoes de pagamento aceitas nos pedidos.
public static class Pagamentos
{
    public const string Pendente = "Pendente";
    public const string Pago = "Pago";
    public const string Estornado = "Estornado";
    public const int MaxParcelas = 6;

    public static readonly IReadOnlyDictionary<string, string> Formas = new Dictionary<string, string>
    {
        ["Pix"] = "PIX",
        ["Credito"] = "Cartão de crédito",
        ["Debito"] = "Cartão de débito",
        ["Boleto"] = "Boleto",
        ["Dinheiro"] = "Dinheiro"
    };

    public static string Nome(string? forma) => forma != null && Formas.TryGetValue(forma, out var nome) ? nome : forma ?? "-";

    // Parcelamento so existe no cartao de credito, de 1 a 6 vezes.
    public static string? Validar(string forma, int parcelas)
    {
        if (!Formas.ContainsKey(forma)) return "Forma de pagamento invalida.";
        if (parcelas < 1 || parcelas > MaxParcelas) return $"O numero de parcelas deve ser de 1 a {MaxParcelas}.";
        if (forma != "Credito" && parcelas != 1) return "Apenas o cartao de credito pode ser parcelado.";
        return null;
    }
}

public class PixOptions
{
    // Chave aleatoria (EVP) de demonstracao: a ModaMax e uma empresa ficticia.
    public string Chave { get; set; } = "7d9f0335-8dcc-4054-9bf9-0dbd61d36906";

    public string NomeRecebedor { get; set; } = "MODAMAX DISTRIBUIDORA";

    public string Cidade { get; set; } = "SAO PAULO";
}

// Gera o "PIX copia e cola" (BR Code do Banco Central, padrao EMV) e o QR Code correspondente.
public class PixService
{
    private readonly PixOptions _opcoes;

    public PixService(PixOptions opcoes)
    {
        _opcoes = opcoes;
    }

    public string GerarPayload(decimal valor, string identificador)
    {
        var contaPix = Campo("00", "br.gov.bcb.pix") + Campo("01", _opcoes.Chave);
        var txid = new string(SemAcentos(identificador).Where(char.IsAsciiLetterOrDigit).Take(25).ToArray());

        var payload = new StringBuilder()
            .Append(Campo("00", "01"))                                   // versao do payload
            .Append(Campo("26", contaPix))                               // conta PIX do recebedor
            .Append(Campo("52", "0000"))                                 // categoria do comerciante
            .Append(Campo("53", "986"))                                  // moeda: real
            .Append(Campo("54", valor.ToString("0.00", CultureInfo.InvariantCulture)))
            .Append(Campo("58", "BR"))
            .Append(Campo("59", Limitar(SemAcentos(_opcoes.NomeRecebedor).ToUpperInvariant(), 25)))
            .Append(Campo("60", Limitar(SemAcentos(_opcoes.Cidade).ToUpperInvariant(), 15)))
            .Append(Campo("62", Campo("05", txid.Length > 0 ? txid : "***")))
            .Append("6304")                                              // CRC16 calculado sobre tudo, inclusive "6304"
            .ToString();

        return payload + Crc16(payload).ToString("X4");
    }

    public static string GerarQrCodeSvg(string conteudo)
    {
        using var gerador = new QRCodeGenerator();
        using var dados = gerador.CreateQrCode(conteudo, QRCodeGenerator.ECCLevel.M);
        return new SvgQRCode(dados).GetGraphic(6, "#000000", "#ffffff", drawQuietZones: true);
    }

    // CRC16-CCITT (polinomio 0x1021, valor inicial 0xFFFF), exigido pelo BR Code.
    public static ushort Crc16(string texto)
    {
        ushort crc = 0xFFFF;
        foreach (var b in Encoding.UTF8.GetBytes(texto))
        {
            crc ^= (ushort)(b << 8);
            for (var i = 0; i < 8; i++)
            {
                crc = (crc & 0x8000) != 0 ? (ushort)((crc << 1) ^ 0x1021) : (ushort)(crc << 1);
            }
        }

        return crc;
    }

    private static string Campo(string id, string valor) => $"{id}{valor.Length:00}{valor}";

    private static string Limitar(string texto, int maximo) => texto.Length <= maximo ? texto : texto[..maximo];

    private static string SemAcentos(string texto)
    {
        var decomposto = texto.Normalize(NormalizationForm.FormD);
        return new string(decomposto.Where(c => CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark).ToArray());
    }
}
