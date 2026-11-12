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

    // ---------- desenho do EAN-13 para as etiquetas ---------------------------------------------
    private static readonly string[] CodigosL = { "0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011" };
    private static readonly string[] CodigosG = { "0100111", "0110011", "0011011", "0100001", "0011101", "0111001", "0000101", "0010001", "0001001", "0010111" };
    private static readonly string[] CodigosR = { "1110010", "1100110", "1101100", "1000010", "1011100", "1001110", "1010000", "1000100", "1001000", "1110100" };
    private static readonly string[] Paridade = { "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL" };

    // Sequencia de 95 modulos (1 = barra, 0 = espaco) de um EAN-13. UPC-A (12 digitos) vira EAN-13 com zero a esquerda.
    public static string? ModulosEan13(string? codigo)
    {
        if (codigo?.Length == 12) codigo = "0" + codigo;
        if (codigo?.Length != 13 || !EhValido(codigo)) return null;

        var primeiro = codigo[0] - '0';
        var modulos = new System.Text.StringBuilder("101");
        for (var i = 1; i <= 6; i++)
        {
            var digito = codigo[i] - '0';
            modulos.Append(Paridade[primeiro][i - 1] == 'L' ? CodigosL[digito] : CodigosG[digito]);
        }

        modulos.Append("01010");
        for (var i = 7; i <= 12; i++)
        {
            modulos.Append(CodigosR[codigo[i] - '0']);
        }

        return modulos.Append("101").ToString();
    }

    // SVG pronto para imprimir: barras, barras-guia mais longas e os numeros embaixo.
    public static string? SvgEan13(string? codigo)
    {
        var modulos = ModulosEan13(codigo);
        if (modulos == null) return null;
        if (codigo!.Length == 12) codigo = "0" + codigo;

        const int largura = 2, altura = 60, margem = 18;
        var guias = new HashSet<int> { 0, 1, 2, 45, 46, 47, 48, 49, 92, 93, 94 };
        var svg = new System.Text.StringBuilder();
        svg.Append($"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {95 * largura + margem * 2} {altura + 18}\" role=\"img\" aria-label=\"Código de barras {codigo}\">");
        svg.Append($"<rect width=\"100%\" height=\"100%\" fill=\"#fff\"/>");
        for (var i = 0; i < modulos.Length; i++)
        {
            if (modulos[i] != '1') continue;
            var alturaBarra = guias.Contains(i) ? altura + 8 : altura;
            svg.Append($"<rect x=\"{margem + i * largura}\" y=\"2\" width=\"{largura}\" height=\"{alturaBarra}\" fill=\"#000\"/>");
        }

        var estilo = "font-family=\"ui-monospace,Menlo,monospace\" font-size=\"13\" fill=\"#000\" text-anchor=\"middle\"";
        svg.Append($"<text x=\"{margem - 8}\" y=\"{altura + 15}\" {estilo}>{codigo[0]}</text>");
        svg.Append($"<text x=\"{margem + 24 * largura}\" y=\"{altura + 15}\" {estilo} letter-spacing=\"3\">{codigo[1..7]}</text>");
        svg.Append($"<text x=\"{margem + 71 * largura}\" y=\"{altura + 15}\" {estilo} letter-spacing=\"3\">{codigo[7..]}</text>");
        return svg.Append("</svg>").ToString();
    }
}
