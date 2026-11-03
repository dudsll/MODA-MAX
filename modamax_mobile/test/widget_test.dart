import 'package:flutter_test/flutter_test.dart';
import 'package:modamax_mobile/codigo_barras.dart';
import 'package:modamax_mobile/models.dart';

void main() {
  test('formata valores em reais', () {
    expect(formatarMoeda(1234.5), 'R\$ 1.234,50');
    expect(formatarMoeda(98.6), 'R\$ 98,60');
  });

  test('converte pedido vindo da API', () {
    final pedido = Pedido.fromJson({
      'idPedido': 1,
      'idCliente': 2,
      'cliente': 'Luara de Jesus',
      'dataPedido': '2026-06-01T00:00:00',
      'tiposVenda': 'Varejo',
      'status': 'Finalizado',
      'valorTotal': 160.73,
      'itens': [
        {
          'idItem': 1,
          'idProduto': 5,
          'produto': 'Short Jeans',
          'quantidade': 1,
          'precoUnitario': 160.73,
          'desconto': 0,
          'subtotal': 160.73,
        },
      ],
    });

    expect(pedido.itens.single.produto, 'Short Jeans');
    expect(formatarData(pedido.dataPedido), '01/06/2026');
  });

  test('valida codigos de barras EAN/GTIN pelo digito verificador', () {
    expect(codigoBarrasValido('4006381333931'), isTrue); // EAN-13
    expect(codigoBarrasValido('73513537'), isTrue); // EAN-8
    expect(codigoBarrasValido('036000291452'), isTrue); // UPC-A
    expect(codigoBarrasValido('4006381333932'), isFalse); // digito errado
    expect(codigoBarrasValido('40063813339'), isFalse); // tamanho invalido
    expect(normalizarCodigoBarras(' 7891234-500014 '), '7891234500014');
    expect(digitoVerificador('789123450001'), 4);
  });

  test('converte produto com codigo de barras e foto', () {
    final produto = Produto.fromJson({
      'idProduto': 4,
      'nome': 'Bermuda Jeans',
      'tamanho': '40',
      'cor': 'Azul',
      'preco': 120.85,
      'estoque': 150,
      'codigoBarras': '7891234500045',
      'fotoUrl': '/uploads/produtos/abc.jpg',
    });

    expect(produto.codigoBarras, '7891234500045');
    expect(produto.enderecoFoto('http://10.0.2.2:5248'), 'http://10.0.2.2:5248/uploads/produtos/abc.jpg');
    final semFoto = Produto.fromJson({'idProduto': 1, 'nome': 'Saia', 'tamanho': '36', 'cor': 'Azul', 'preco': 170, 'estoque': 45});
    expect(semFoto.enderecoFoto('http://10.0.2.2:5248'), isNull);
  });
}
