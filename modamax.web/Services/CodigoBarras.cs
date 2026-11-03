namespace modamax.web.Services;

// Validacao de codigos de barras GTIN (EAN-8, UPC-A, EAN-13 e GTIN-14).
// O ultimo digito e um digito verificador calculado pelos demais (modulo 10, pesos 3 e 1),
// o que permite recusar codigos digitados ou lidos errado.
public static class CodigoBarras
{
    private static readonly int[] TamanhosValidos = { 8, 12, 13, 14 };

    // Remove espacos e tracos; devolve null quando nada foi informado.
    public static string? Normalizar(string? codigo)
    {
        if (string.IsNullOrWhiteSpace(codigo)) return null;
        var limpo = new string(codigo.Where(c => !char.IsWhiteSpace(c) && c != '-').ToArray());
        return limpo.Length == 0 ? null : limpo;
    }

    public static bool EhValido(string? codigo)
    {
        if (codigo == null || !TamanhosValidos.Contains(codigo.Length) || !codigo.All(char.IsAsciiDigit))
        {
            return false;
        }

        return CalcularDigito(codigo[..^1]) == codigo[^1] - '0';
    }

    // Digito verificador para os digitos informados (sem o verificador).
    public static int CalcularDigito(string semDigito)
    {
        var soma = 0;
        for (var i = 0; i < semDigito.Length; i++)
        {
            // Da direita para a esquerda, os pesos se alternam entre 3 e 1.
            var peso = (semDigito.Length - i) % 2 == 1 ? 3 : 1;
            soma += (semDigito[i] - '0') * peso;
        }

        return (10 - soma % 10) % 10;
    }

    public static string Gerar(string semDigito) => semDigito + CalcularDigito(semDigito);

    public const string MensagemInvalido = "Código de barras inválido. Use um EAN/GTIN com 8, 12, 13 ou 14 dígitos.";
}
