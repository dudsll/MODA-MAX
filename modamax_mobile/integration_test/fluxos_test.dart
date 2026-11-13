// Teste de ponta a ponta: abre o app de verdade (simulador ou celular), ligado a API rodando
// com os dados de demonstracao, e percorre os fluxos principais tocando e digitando como um
// usuario. Cria e apaga os proprios dados (item, cliente e pedidos de teste).
//
// Rodar (com a API em modo demonstracao):
//   flutter test integration_test -d <simulador>
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:modamax_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fluxos principais do app no iPhone', (tester) async {
    // Comeca deslogado e sem cache.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await tester.pumpWidget(const ModaMaxApp());
    final t = _Testador(tester);

    // ---- Login com o acesso de demonstracao
    await t.esperar(find.text('Entrar'));
    await t.tocar(find.text('Diretoria'));
    await t.tocar(find.text('Entrar'));
    await t.esperar(find.text('Olá, Diretoria ModaMax'));
    expect(find.byType(CupertinoTabBar), findsOneWidget, reason: 'barra de abas do iOS');

    // ---- Painel clicavel: "Estoque baixo" abre Produtos ja filtrado
    await t.tocar(find.text('Estoque baixo'));
    // O filtro aplicado aparece como etiqueta, com o botao "Limpar" ao lado.
    await t.esperar(find.text('Limpar'));
    expect(find.text('Estoque baixo'), findsOneWidget);
    await t.tocar(find.text('Limpar'));
    await t.esperar(find.text('12 modelos · Nome'));

    // ---- Busca
    await t.digitar(find.byType(CupertinoSearchTextField), 'Skinny', confirmar: true);
    await t.esperar(find.text('1 modelo · Nome'));
    // Limpar pelo "x" do campo (como o usuario faz) volta a lista completa.
    await t.tocar(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await t.esperar(find.text('12 modelos · Nome'));

    // ---- Filtros: tipo "Calca" mostra 3 modelos (Jeans, Flare e Skinny)
    await t.tocar(find.textContaining('Filtros'));
    await t.esperar(find.text('Tipo de produto'.toUpperCase()));
    await t.tocar(find.descendant(of: find.byType(CupertinoListTile), matching: find.text('Calca')));
    await t.tocar(find.text('Mostrar 3 modelos'));
    await t.esperar(find.text('3 modelos · Nome'));
    await t.tocar(find.text('Limpar'));
    await t.esperar(find.text('12 modelos · Nome'));

    // ---- Modelo: adicionar, editar e apagar (deslizando) um item
    await t.tocar(find.text('Calca Skinny'));
    await t.esperar(find.text('ITENS'));
    await t.tocar(find.text('Adicionar item'));
    await t.esperar(find.text('Novo item'));
    await t.digitar(t.campo('Tamanho'), '46');
    await t.digitar(t.campo('Estoque'), '3');
    await t.tocar(find.text('Salvar'));
    await t.esperar(find.text('Tamanho 46 · Preto'));

    await t.tocar(find.text('Tamanho 46 · Preto'));
    await t.tocar(find.text('Editar item'));
    await t.esperar(find.text('Editar item'));
    await t.digitar(t.campo('Estoque'), '4');
    await t.tocar(find.text('Salvar'));
    await t.esperar(find.textContaining('4 peças'));

    await t.deslizarParaApagar(find.text('Tamanho 46 · Preto'));
    await t.esperar(find.byType(CupertinoAlertDialog));
    await t.tocar(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Apagar')));
    await t.esperarSumir(find.text('Tamanho 46 · Preto'));
    await t.tocar(find.byType(CupertinoNavigationBarBackButton));
    await t.esperar(find.text('12 modelos · Nome'));

    // ---- Clientes: cadastrar, abrir a ficha, editar e apagar
    await t.aba('Clientes');
    await t.tocar(find.text('Novo cliente'));
    await t.esperar(find.text('Novo cliente'));
    await t.digitar(t.campo('Nome'), 'Cliente Teste App');
    await t.digitar(t.campo('CPF'), '12345678909');
    await t.digitar(t.campo('E-mail'), 'teste.app@modamax.com');
    await t.tocar(find.text('Salvar'));
    await t.esperar(find.text('Cliente Teste App'));

    await t.tocar(find.text('Cliente Teste App'));
    await t.esperar(find.text('Pessoa física'));
    await t.tocar(find.text('Editar'));
    await t.esperar(find.text('Editar cliente'));
    await t.tocar(find.text('Apagar Cliente'));
    await t.tocar(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Apagar')));
    await t.esperarSumir(find.text('Cliente Teste App'));

    // Cliente com pedidos nao pode ser apagado: o aviso aparece e ele continua na lista.
    await t.deslizarParaApagar(find.text('Amanda da Silva'));
    await t.tocar(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Apagar')));
    await t.esperar(find.textContaining('possui pedidos'));
    expect(find.text('Amanda da Silva'), findsOneWidget);

    // ---- Pedido com PIX: registrar, ver o PIX e confirmar o pagamento
    await t.aba('Pedidos');
    await t.novoPedido(cliente: 'Bianca Arantes Araujo', produto: 'Bermuda Jeans');
    await t.tocar(find.text('Bianca Arantes Araujo').first);
    await t.esperar(find.text('PIX copia e cola'));
    await t.tocar(find.text('PIX copia e cola'));
    await t.tocar(find.text('Copiar código'));
    await t.esperar(find.text('Código PIX copiado.'));
    await t.tocar(find.text('Confirmar pagamento'));
    await t.esperar(find.text('Pagamento confirmado.'));

    // ---- Pedido no cartao em 3x: registrar e cancelar
    await t.novoPedido(cliente: 'Dhebora Barreto', produto: 'Blusa Jeans', parcelas3x: true);
    await t.tocar(find.text('Dhebora Barreto').first);
    await t.esperar(find.textContaining('Cartão de crédito em 3x'));
    await t.tocar(find.text('Cancelar Pedido'));
    await t.tocar(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Cancelar pedido')));
    await t.esperar(find.text('Pedido cancelado.'));

    // ---- Painel: item da reposicao abre o modelo, com a barra de abas visivel
    await t.aba('Painel');
    await t.esperar(find.text('PRECISAM DE REPOSIÇÃO'));
    final primeiro = find.descendant(
      of: find.ancestor(of: find.text('PRECISAM DE REPOSIÇÃO'), matching: find.byType(CupertinoListSection)),
      matching: find.byType(CupertinoListTile),
    );
    await t.tocar(primeiro.first);
    await t.esperar(find.text('ITENS'));
    expect(find.byType(CupertinoTabBar), findsOneWidget);
  });
}

class _Testador {
  final WidgetTester tester;

  _Testador(this.tester);

  /// Espera o elemento aparecer (a API responde em segundos; o app tem animacoes infinitas,
  /// como a rodinha do iOS, entao nao da para usar pumpAndSettle).
  Future<void> esperar(Finder alvo, {Duration limite = const Duration(seconds: 20)}) async {
    final fim = DateTime.now().add(limite);
    while (DateTime.now().isBefore(fim)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (alvo.evaluate().isNotEmpty) return;
    }
    final textos = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toSet();
    fail('Não apareceu na tela: $alvo\nTextos visíveis: ${textos.join(' | ')}');
  }

  Future<void> esperarSumir(Finder alvo, {Duration limite = const Duration(seconds: 20)}) async {
    final fim = DateTime.now().add(limite);
    while (DateTime.now().isBefore(fim)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (alvo.evaluate().isEmpty) return;
    }
    fail('Continuou na tela: $alvo');
  }

  /// Procura o alvo; se ainda nao estiver na tela, rola a lista para baixo (as listas so
  /// montam o que esta perto da area visivel).
  Future<void> procurar(Finder alvo) async {
    for (var tentativa = 0; tentativa < 40; tentativa++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (alvo.evaluate().isNotEmpty) return;
      // Espera um pouco (a tela pode estar carregando) antes de comecar a rolar.
      if (tentativa < 10) continue;
      final rolavel = find.byType(Scrollable).hitTestable();
      if (rolavel.evaluate().isNotEmpty) {
        await tester.drag(rolavel.first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    await esperar(alvo);
  }

  Future<void> tocar(Finder alvo) async {
    await procurar(alvo);
    await tester.ensureVisible(alvo.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(alvo.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Campo de formulario do iOS pelo rotulo (o texto de ajuda e o proprio rotulo).
  Finder campo(String rotulo) =>
      find.byWidgetPredicate((w) => w is CupertinoTextField && w.placeholder == rotulo);

  Future<void> digitar(Finder alvo, String texto, {bool confirmar = false}) async {
    await procurar(alvo);
    await tester.ensureVisible(alvo.first);
    await tester.enterText(alvo.first, texto);
    if (confirmar) await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Desliza a linha para a esquerda e toca no botao "Apagar" revelado.
  Future<void> deslizarParaApagar(Finder linha) async {
    await procurar(linha);
    await tester.ensureVisible(linha.first);
    await tester.drag(linha.first, const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tocar(find.text('Apagar'));
  }

  Future<void> aba(String nome) async {
    await tocar(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text(nome)));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> novoPedido({required String cliente, required String produto, bool parcelas3x = false}) async {
    await tocar(find.text('Novo pedido'));
    await esperar(find.text('Registrar pedido'));
    await tocar(find.text('Cliente'));
    await tocar(find.text(cliente));
    if (parcelas3x) {
      await tocar(find.text('Forma de pagamento'));
      await tocar(find.text('Cartão de crédito'));
      await tocar(find.text('Parcelas'));
      await tocar(find.textContaining('3x de'));
    }
    await tocar(find.text('Adicionar'));
    await esperar(find.text('Escolha o produto'));
    await tocar(find.text(produto));
    await tocar(find.text('Registrar pedido'));
    await esperar(find.textContaining('registrado.'));
    await esperar(find.text('Novo pedido'));
  }
}
