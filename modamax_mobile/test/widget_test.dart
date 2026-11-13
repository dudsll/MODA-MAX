import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modamax_mobile/catalogo.dart';
import 'package:modamax_mobile/codigo_barras.dart';
import 'package:modamax_mobile/models.dart';
import 'package:modamax_mobile/screens/clientes_screen.dart';
import 'package:modamax_mobile/screens/login_screen.dart';
import 'package:modamax_mobile/screens/produto_form_screen.dart';
import 'package:modamax_mobile/services/api_service.dart';
import 'package:modamax_mobile/widgets/adaptativo.dart';
import 'package:modamax_mobile/widgets/aneis.dart';

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

  test('pedido traz o pagamento e aceita cache antigo sem esses campos', () {
    final base = {
      'idPedido': 7,
      'idCliente': 1,
      'dataPedido': '2026-11-10T10:00:00',
      'tiposVenda': 'Varejo',
      'status': 'Em separação',
      'valorTotal': 600,
      'itens': <dynamic>[],
    };
    final pago = Pedido.fromJson({...base, 'formaPagamento': 'Credito', 'parcelas': 3, 'statusPagamento': 'Pago'});
    final antigo = Pedido.fromJson(base);

    expect(nomePagamento(pago.formaPagamento), 'Cartão de crédito');
    expect(pago.parcelas, 3);
    expect(pago.pagamentoPendente, isFalse);
    expect(antigo.formaPagamento, 'Pix');
    expect(antigo.pagamentoPendente, isTrue);
  });

  MetaAtual metaDeExemplo() => MetaAtual.fromJson({
        'mes': 'Novembro de 2026',
        'definida': true,
        'faturamento': {'meta': 8100, 'realizado': 5441, 'percentual': 67},
        'pedidos': {'meta': 14, 'realizado': 9, 'percentual': 64},
        'pecas': {'meta': 61, 'realizado': 42, 'percentual': 69},
        'projecaoFaturamento': 14840,
        'diasRestantes': 19,
      });

  test('converte metas e itens de reposicao', () {
    final meta = metaDeExemplo();
    expect(meta.faturamento.percentual, 67);
    expect(meta.diasRestantes, 19);

    final item = ItemReposicao.fromJson({
      'idProduto': 7,
      'produto': 'Saia Jeans',
      'estoque': 8,
      'vendidosNoPeriodo': 17,
      'diasDeCobertura': 14,
      'quantidadeSugerida': 22,
      'situacao': 'Critico',
    });
    expect(item.critico, isTrue);
    expect(item.quantidadeSugerida, 22);
  });

  testWidgets('aneis de meta mostram os percentuais', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AneisMeta(meta: metaDeExemplo()))));

    expect(find.text('67%'), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
    expect(find.text('69%'), findsOneWidget);
    expect(find.text('Peças'), findsOneWidget);
  });

  test('preco do formulario de produto aceita virgula e ponto', () {
    expect(lerPreco('129,90'), 129.90);
    expect(lerPreco('1.299,90'), 1299.90);
    expect(lerPreco('129.90'), 129.90);
    expect(lerPreco('R\$ 59,00'), 59.0);
    expect(lerPreco('abc'), isNull);
  });

  test('produto le categoria e fornecedor da API', () {
    final p = Produto.fromJson({
      'idProduto': 1, 'nome': 'Calca', 'tamanho': '40', 'cor': 'Azul', 'preco': 99.9, 'estoque': 3,
      'idCategoria': 2, 'categoria': 'Calca', 'idFornecedor': 5, 'fornecedor': 'DZ',
    });
    expect(p.idCategoria, 2);
    expect(p.idFornecedor, 5);
  });

  test('iniciais do avatar do cliente seguem o app Contatos', () {
    expect(iniciais('Gabriel Mancini'), 'GM');
    expect(iniciais('Amanda da Silva'), 'AS');
    expect(iniciais('loja'), 'L');
    expect(iniciais('  '), '?');
  });

  group('catalogo agrupado por modelo', () {
    Produto p(int id, String nome, String tamanho, int estoque,
            {String cor = 'Azul', double preco = 100, String categoria = 'Calca', String fornecedor = 'DZ'}) =>
        Produto(
          idProduto: id, nome: nome, tamanho: tamanho, cor: cor, preco: preco, estoque: estoque,
          categoria: categoria, fornecedor: fornecedor,
        );

    final produtos = [
      p(1, 'Calca Flare de Lantejoulas', '40', 5, preco: 200),
      p(2, 'Calca Flare de Lantejoulas', '36', 0, preco: 200),
      p(3, 'calca flare de lantejoulas ', '38', 20, preco: 210),
      p(4, 'Jaqueta Jeans', 'GG', 3, categoria: 'Jaqueta', fornecedor: 'Alianza'),
      p(5, 'Jaqueta Jeans', 'P', 30, categoria: 'Jaqueta', fornecedor: 'Alianza'),
      p(6, 'Bermuda', '42', 50, preco: 80, categoria: 'Bermuda'),
    ];

    test('junta os tamanhos do mesmo modelo, em ordem de grade', () {
      final modelos = agruparPorModelo(produtos);
      expect(modelos.map((m) => m.nome), ['Bermuda', 'Calca Flare de Lantejoulas', 'Jaqueta Jeans']);
      final calca = modelos[1];
      expect(calca.tamanhos.map((t) => t.tamanho), ['36', '38', '40']);
      expect(calca.estoqueTotal, 25);
      expect(calca.menorPreco, 200);
      expect(calca.maiorPreco, 210);
      expect(modelos[2].tamanhos.map((t) => t.tamanho), ['P', 'GG']);
    });

    test('filtra por tipo, fornecedor, tamanho e disponibilidade', () {
      expect(const FiltroProdutos(categorias: {'Jaqueta'}).aplicar(produtos).single.nome, 'Jaqueta Jeans');
      expect(const FiltroProdutos(fornecedores: {'DZ'}).aplicar(produtos).length, 2);
      expect(const FiltroProdutos(tamanhos: {'38'}).aplicar(produtos).single.tamanhos.single.idProduto, 3);
      expect(const FiltroProdutos(disponibilidade: Disponibilidade.esgotado).aplicar(produtos).single.nome,
          'Calca Flare de Lantejoulas');
      final baixo = const FiltroProdutos(disponibilidade: Disponibilidade.estoqueBaixo).aplicar(produtos);
      expect(baixo.map((m) => m.nome), ['Calca Flare de Lantejoulas', 'Jaqueta Jeans']);
      expect(const FiltroProdutos(precoMaximo: 90).aplicar(produtos).single.nome, 'Bermuda');
      expect(const FiltroProdutos(categorias: {'Jaqueta'}, tamanhos: {'G'}).aplicar(produtos), isEmpty);
    });

    test('ordena e conta os filtros ativos', () {
      final porPreco = const FiltroProdutos(ordenacao: Ordenacao.menorPreco).aplicar(produtos);
      expect(porPreco.first.nome, 'Bermuda');
      final porEstoque = const FiltroProdutos(ordenacao: Ordenacao.maiorEstoque).aplicar(produtos);
      expect(porEstoque.first.nome, 'Bermuda');
      expect(const FiltroProdutos(categorias: {'A', 'B'}, disponibilidade: Disponibilidade.emEstoque).quantidade, 3);
      expect(const FiltroProdutos(ordenacao: Ordenacao.maiorPreco).vazio, isTrue);
    });

    test('opcoes do filtro saem dos produtos carregados', () {
      final opcoes = OpcoesFiltro.de(produtos);
      expect(opcoes.categorias, ['Bermuda', 'Calca', 'Jaqueta']);
      expect(opcoes.tamanhos, ['P', 'GG', '36', '38', '40', '42']);
      expect(opcoes.menorPreco, 80);
      expect(opcoes.maiorPreco, 210);
    });
  });

  test('nivel de acesso e comparado sem acento', () {
    expect(nivelSemAcento('Estratégico'), 'estrategico');
    expect(nivelSemAcento('Tático'), 'tatico');
    expect(nivelSemAcento(null), '');
  });

  test('sigla do produto usa as duas primeiras palavras, sem as de ligacao', () {
    expect(siglaProduto('Calca Flare de Lantejoulas'), 'CF');
    expect(siglaProduto('Jaqueta Jeans Premium'), 'JJ');
    expect(siglaProduto('Calca de Sarja'), 'CS');
    expect(siglaProduto('Bermuda'), 'B');
    expect(siglaProduto('  '), '?');
  });

  group('visual adaptativo', () {
    Widget app(TargetPlatform plataforma, Widget tela) =>
        MaterialApp(theme: ThemeData(platform: plataforma), home: tela);

    testWidgets('login usa componentes da Apple no iPhone e do Material no Android', (tester) async {
      await tester.pumpWidget(app(TargetPlatform.iOS, const LoginScreen()));
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoTextField), findsNWidgets(2));
      expect(find.widgetWithText(CupertinoButton, 'Entrar'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.pumpWidget(app(TargetPlatform.android, const LoginScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPageScaffold), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    });

    testWidgets('pagina, lista e alerta seguem o sistema', (tester) async {
      Widget tela() => Pagina(
            titulo: 'Clientes',
            tituloGrande: true,
            corpo: Builder(
              builder: (context) => ListView(children: [
                SecaoLista(children: [ItemLista(titulo: 'Amanda', valor: 'R\$ 10,00', seta: true, aoTocar: () {})]),
                Botao.principal('Apagar', aoTocar: () => confirmar(context, titulo: 'Apagar?', mensagem: 'x', acao: 'Apagar')),
              ]),
            ),
          );

      await tester.pumpWidget(app(TargetPlatform.iOS, tela()));
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(CupertinoListSection), findsOneWidget);
      expect(find.byType(CupertinoListTile), findsOneWidget);
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(TargetPlatform.android, tela()));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
