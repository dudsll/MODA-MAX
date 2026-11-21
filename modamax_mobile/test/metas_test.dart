import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modamax_mobile/models.dart';
import 'package:modamax_mobile/screens/metas_screen.dart';

Map<String, dynamic> _indicador(num meta, num realizado, int percentual) =>
    {'meta': meta, 'realizado': realizado, 'percentual': percentual};

Map<String, dynamic> _json({String situacao = 'encerrado', bool definida = true, bool podeEditar = false}) => {
      'ano': 2026,
      'mes': 10,
      'nomeMes': 'Outubro de 2026',
      'situacao': situacao,
      'definida': definida,
      'faturamento': _indicador(20000, 21500.5, 108),
      'pedidos': _indicador(80, 85, 106),
      'pecas': _indicador(200, 190, 95),
      'projecaoFaturamento': 21500.5,
      'diasNoMes': 31,
      'diasDecorridos': 31,
      'diasRestantes': 0,
      'necessarioPorDia': 0,
      'ticketMedio': 252.95,
      'mesAnterior': {
        'ano': 2026, 'mes': 9, 'nomeMes': 'Setembro de 2026', 'definida': false, 'metaFaturamento': 18000,
        'faturamento': 17000, 'pedidos': 70, 'pecas': 160, 'percentual': 94,
      },
      'faturamentoPorDia': [for (var d = 1; d <= 31; d++) {'rotulo': '$d', 'valor': d == 5 ? 1500 : 600}],
      'maisVendidos': [
        {'produto': 'Calça Skinny', 'pecas': 30, 'valor': 4497},
      ],
      'sugestao': {'faturamento': 19800, 'pedidos': 77, 'pecas': 176},
      'podeEditar': podeEditar,
    };

void main() {
  test('le os detalhes do mes vindos da API', () {
    final m = MetaMes.fromJson(_json());
    expect(m.encerrado, isTrue);
    expect(m.faturamento.percentualExibido, 107);   // 21500,5 / 20000 = 107,5% -> mostra 107
    expect(m.faturamentoPorDia, hasLength(31));
    expect(m.mesAnterior.ticketMedio, closeTo(242.86, 0.01));
    expect(m.mesAnterior.percentualExibido, 94);
    expect(m.sugestao.pedidos, 77);
    expect(m.valores.pecas, 200);
    expect(m.comoMetaAtual.mes, 'Outubro de 2026');
  });

  test('le valores em reais escritos de varios jeitos', () {
    expect(EditarMetaScreenLeitor.ler('12.500,00'), 12500);
    expect(EditarMetaScreenLeitor.ler('R\$ 12.500,50'), 12500.5);
    expect(EditarMetaScreenLeitor.ler('12500'), 12500);
    expect(EditarMetaScreenLeitor.ler('12.500'), 12500);
    expect(EditarMetaScreenLeitor.ler('12500.75'), 12500.75);
    expect(EditarMetaScreenLeitor.ler('abc'), isNull);
  });

  for (final plataforma in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('formulario de edicao usa a sugestao (${plataforma.name})', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: plataforma),
        home: EditarMetaScreen(meta: MetaMes.fromJson(_json(situacao: 'futuro'))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Meta de outubro'), findsOneWidget);
      expect(find.text('20.000,00'), findsOneWidget);

      await tester.ensureVisible(find.text('Usar a sugestão'));
      await tester.tap(find.text('Usar a sugestão'));
      await tester.pumpAndSettle();
      expect(find.text('19.800,00'), findsOneWidget);
      expect(find.text('20.000,00'), findsNothing);
    });
  }
}
