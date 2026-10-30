import 'package:flutter_test/flutter_test.dart';
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
}
