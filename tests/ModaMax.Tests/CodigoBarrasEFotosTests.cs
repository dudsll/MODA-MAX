using modamax.web.Services;

namespace ModaMax.Tests;

public class CodigoBarrasTests
{
    [Theory]
    [InlineData("4006381333931")] // EAN-13
    [InlineData("7891234500014")] // EAN-13 dos dados de demonstracao
    [InlineData("73513537")] // EAN-8
    [InlineData("036000291452")] // UPC-A
    [InlineData("17891234500011")] // GTIN-14
    public void Codigos_com_digito_verificador_correto_sao_validos(string codigo)
    {
        Assert.True(CodigoBarras.EhValido(codigo));
    }

    [Theory]
    [InlineData("4006381333932")] // digito verificador errado
    [InlineData("400638133393")] // 12 digitos que nao formam um UPC valido
    [InlineData("12345")] // tamanho invalido
    [InlineData("40063813339AB")] // letras
    [InlineData(null)]
    public void Codigos_invalidos_sao_recusados(string? codigo)
    {
        Assert.False(CodigoBarras.EhValido(codigo));
    }

    [Fact]
    public void Normalizar_remove_espacos_e_tracos()
    {
        Assert.Equal("7891234500014", CodigoBarras.Normalizar(" 789 1234-500014 "));
        Assert.Null(CodigoBarras.Normalizar("   "));
    }

    [Fact]
    public void Gerar_acrescenta_o_digito_verificador()
    {
        Assert.Equal("7891234500014", CodigoBarras.Gerar("789123450001"));
    }
}

public class ArmazenamentoFotosTests : IDisposable
{
    private static readonly byte[] CabecalhoPng = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D };
    private static readonly byte[] CabecalhoJpg = { 0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1 };

    private readonly string _pasta = Path.Combine(Path.GetTempPath(), $"modamax-fotos-{Guid.NewGuid():N}");
    private readonly ArmazenamentoFotosLocal _armazenamento;

    public ArmazenamentoFotosTests()
    {
        _armazenamento = new ArmazenamentoFotosLocal(_pasta);
    }

    public void Dispose()
    {
        if (Directory.Exists(_pasta)) Directory.Delete(_pasta, recursive: true);
    }

    [Fact]
    public async Task Imagem_valida_e_gravada_com_nome_aleatorio_e_extensao_pelo_conteudo()
    {
        var url = await _armazenamento.SalvarAsync(new MemoryStream(CabecalhoPng));

        Assert.StartsWith("/uploads/produtos/", url);
        Assert.EndsWith(".png", url);
        Assert.True(File.Exists(Path.Combine(_pasta, Path.GetFileName(url))));
    }

    [Fact]
    public async Task Arquivo_que_nao_e_imagem_e_recusado()
    {
        var falso = "<script>alert(1)</script>"u8.ToArray();

        var erro = await Assert.ThrowsAsync<FotoInvalidaException>(() => _armazenamento.SalvarAsync(new MemoryStream(falso)));
        Assert.Contains("JPG, PNG ou WebP", erro.Message);
        Assert.Empty(Directory.GetFiles(_pasta));
    }

    [Fact]
    public async Task Foto_maior_que_2_MB_e_recusada()
    {
        var grande = new byte[ArmazenamentoFotosLocal.TamanhoMaximo + 1];
        CabecalhoJpg.CopyTo(grande, 0);

        await Assert.ThrowsAsync<FotoInvalidaException>(() => _armazenamento.SalvarAsync(new MemoryStream(grande)));
        Assert.Empty(Directory.GetFiles(_pasta));
    }

    [Fact]
    public async Task Excluir_apaga_a_foto_e_ignora_caminhos_fora_da_pasta()
    {
        var url = await _armazenamento.SalvarAsync(new MemoryStream(CabecalhoJpg));
        var fora = Path.Combine(Path.GetTempPath(), $"nao-apagar-{Guid.NewGuid():N}.txt");
        await File.WriteAllTextAsync(fora, "x");

        await _armazenamento.ExcluirAsync("/uploads/produtos/../../" + Path.GetFileName(fora));
        await _armazenamento.ExcluirAsync(url);

        Assert.False(File.Exists(Path.Combine(_pasta, Path.GetFileName(url))));
        Assert.True(File.Exists(fora));
        File.Delete(fora);
    }
}
