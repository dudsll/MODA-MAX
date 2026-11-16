namespace modamax.web.Services;

/// <summary>
/// Monta o padrao de LIKE para buscas "contem", sem diferenca de maiusculas no SQLite e no
/// SQL Server (Contains do EF vira instr() no SQLite, que diferencia "calca" de "Calca").
/// Os caracteres especiais do LIKE digitados pelo usuario (%, _ e [) valem como texto comum.
/// </summary>
public static class BuscaSql
{
    public const string Escape = "\\";

    public static string Contem(string termo) =>
        "%" + termo
            .Replace("\\", "\\\\")
            .Replace("%", "\\%")
            .Replace("_", "\\_")
            .Replace("[", "\\[") + "%";
}
