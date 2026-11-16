import 'package:flutter_test/flutter_test.dart';
import 'package:modamax_mobile/busca.dart';
import 'package:modamax_mobile/catalogo.dart';
import 'package:modamax_mobile/models.dart';

void main() {
  bool acha(String consulta, List<String?> campos) => pontuarBusca(consulta, campos) != null;

  test('normaliza maiusculas, acentos e pontuacao', () {
    expect(normalizarTexto('  CALÇA  Flare-Lantejoulas! '), 'calca flare lantejoulas');
    expect(normalizarTexto('Ação Promoção'), 'acao promocao');
  });

  test('ignora maiusculas e acentos', () {
    expect(acha('calca', ['CALCA JEANS']), isTrue);
    expect(acha('CALÇA', ['Calca Jeans']), isTrue);
    expect(acha('calça skinny', ['Calca Skinny']), isTrue);
  });

  test('palavras em qualquer ordem e em campos diferentes (nome e cor)', () {
    expect(acha('skinny calca', ['Calca Skinny']), isTrue);
    expect(acha('jaqueta preta', ['Jaqueta Jeans', 'Preta']), isTrue);
    expect(acha('jaqueta vermelha', ['Jaqueta Jeans', 'Preta']), isFalse);
  });

  test('comeco da palavra e erros de digitacao', () {
    expect(acha('berm', ['Bermuda Jeans']), isTrue); // ainda digitando
    expect(acha('bremuda', ['Bermuda Jeans']), isTrue); // letras invertidas
    expect(acha('jens', ['Bermuda Jeans']), isTrue); // letra faltando
    expect(acha('jeanss', ['Bermuda Jeans']), isTrue); // letra sobrando
    expect(acha('skiny', ['Calca Skinny']), isTrue);
    expect(acha('lantejolas', ['Calca Flare de Lantejoulas']), isTrue);
    expect(acha('macaquino', ['Macaquinho Jeans']), isTrue);
    expect(acha('bremu', ['Bermuda Jeans']), isTrue); // comeco digitado com erro
  });

  test('nao inventa resultados', () {
    expect(acha('camisa', ['Calca Jeans']), isFalse);
    expect(acha('saia', ['Calca Jeans']), isFalse);
    expect(acha('pp', ['P']), isFalse); // palavras curtas exigem acerto
    expect(acha('xyz', ['Bermuda Jeans']), isFalse);
  });

  test('documento e codigo de barras com ou sem pontuacao', () {
    expect(acha('12345678909', ['Ana', '123.456.789-09']), isTrue);
    expect(acha('123.456', ['Ana', '123.456.789-09']), isTrue);
    expect(acha('4500441', ['Calca', '7891234500441']), isTrue);
  });

  test('ordena do mais parecido para o menos parecido', () {
    final nomes = ['Calca Jeans', 'Jaqueta Jeans', 'Calca Skinny', 'Bermuda Jeans'];
    expect(buscar('calca jeans', nomes, (n) => [n]).first, 'Calca Jeans');
    expect(buscar('jaq', nomes, (n) => [n]), ['Jaqueta Jeans']);
    expect(buscar('', nomes, (n) => [n]), nomes); // sem busca, lista como esta
  });

  test('catalogo: busca por cor e tamanho, mais parecido primeiro', () {
    Produto p(int id, String nome, String tamanho, String cor) => Produto(
          idProduto: id, nome: nome, tamanho: tamanho, cor: cor, preco: 100, estoque: 10,
          categoria: nome.split(' ').first,
        );
    final produtos = [
      p(1, 'Bermuda Jeans', '40', 'Azul'),
      p(2, 'Jaqueta Jeans', 'G', 'Preta'),
      p(3, 'Jaqueta Jeans', 'M', 'Azul'),
      p(4, 'Calca Jeans', '38', 'Preta'),
    ];
    const filtro = FiltroProdutos();

    final pretas = filtro.aplicar(produtos, busca: 'PRETA');
    expect(pretas.map((m) => m.nome), ['Calca Jeans', 'Jaqueta Jeans']);
    expect(pretas.last.tamanhos.single.idProduto, 2); // so o tamanho na cor buscada

    expect(filtro.aplicar(produtos, busca: 'jaqeta').single.nome, 'Jaqueta Jeans');
    expect(filtro.aplicar(produtos, busca: '38').single.nome, 'Calca Jeans');
    expect(filtro.aplicar(produtos, busca: 'bermuda jeans').first.nome, 'Bermuda Jeans');
  });
}
