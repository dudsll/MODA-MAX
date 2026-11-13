import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/aneis.dart';
import '../widgets/comum.dart';
import '../widgets/graficos.dart';
import 'clientes_screen.dart';
import 'login_screen.dart';
import 'pedidos_screen.dart';
import 'produtos_screen.dart';

/// Tela principal com navegacao inferior: Painel, Produtos, Clientes e Pedidos.
///
/// Cada aba tem a sua propria pilha de telas (como as abas dos apps do iPhone): abrir um
/// produto, um cliente ou um pedido mantem a barra inferior visivel, e tocar de novo na aba
/// volta para o inicio dela.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;
  final _navegadores = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _produtos = GlobalKey<ProdutosScreenState>();

  static const _painel = 0, _abaProdutos = 1, _abaClientes = 2, _abaPedidos = 3;
  static const _titulos = ['Painel', 'Produtos', 'Clientes', 'Pedidos'];

  Future<void> _sair() async {
    await ApiService.instancia.logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// Vai para a aba, voltando ao inicio dela.
  void _irPara(int aba) {
    _navegadores[aba].currentState?.popUntil((rota) => rota.isFirst);
    setState(() => _aba = aba);
  }

  void _tocarAba(int aba) {
    if (aba == _aba) {
      _navegadores[aba].currentState?.popUntil((rota) => rota.isFirst);
    } else {
      setState(() => _aba = aba);
    }
  }

  void _mostrarEstoqueBaixo() {
    _irPara(_abaProdutos);
    _produtos.currentState?.mostrarEstoqueBaixo();
  }

  /// Abre o produto dentro da aba Produtos (a barra inferior continua na tela).
  Future<void> _abrirProduto(String nome) async {
    _irPara(_abaProdutos);
    final mudou = await _navegadores[_abaProdutos].currentState?.push<bool>(
      MaterialPageRoute(builder: (_) => ProdutoModeloScreen(nome: nome)),
    );
    if (mudou == true) _produtos.currentState?.recarregar();
  }

  Widget _construirAba(int indice, Widget raiz) => Navigator(
        key: _navegadores[indice],
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => Pagina(
            titulo: _titulos[indice],
            tituloGrande: true,
            acoes: [
              BotaoTopo(rotulo: 'Sair', iconeMaterial: Icons.logout, aoTocar: _sair),
            ],
            corpo: raiz,
          ),
        ),
      );

  static const _iconesIOS = [
    (CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill),
    (CupertinoIcons.tag, CupertinoIcons.tag_fill),
    (CupertinoIcons.person_2, CupertinoIcons.person_2_fill),
    (CupertinoIcons.doc_text, CupertinoIcons.doc_text_fill),
  ];

  /// Barra inferior: a do iOS no iPhone e a do Material 3 no Android.
  Widget _barraInferior(BuildContext context) {
    if (ehIOS(context)) {
      return CupertinoTabBar(
        currentIndex: _aba,
        onTap: _tocarAba,
        items: [
          for (final (i, titulo) in _titulos.indexed)
            BottomNavigationBarItem(icon: Icon(_iconesIOS[i].$1), activeIcon: Icon(_iconesIOS[i].$2), label: titulo),
        ],
      );
    }
    return NavigationBar(
      selectedIndex: _aba,
      onDestinationSelected: _tocarAba,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Painel'),
        NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom), label: 'Produtos'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) async {
        if (saiu) return;
        // Botao voltar do Android: primeiro volta dentro da aba, depois para o Painel.
        final navegador = _navegadores[_aba].currentState;
        if (navegador != null && await navegador.maybePop()) return;
        if (_aba != _painel) {
          setState(() => _aba = _painel);
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _aba,
          children: [
            _construirAba(
              _painel,
              _PainelTab(
                aoAbrirAba: _irPara,
                aoMostrarEstoqueBaixo: _mostrarEstoqueBaixo,
                aoAbrirProduto: _abrirProduto,
              ),
            ),
            _construirAba(_abaProdutos, ProdutosScreen(key: _produtos)),
            _construirAba(_abaClientes, const ClientesScreen()),
            _construirAba(_abaPedidos, const PedidosScreen()),
          ],
        ),
        bottomNavigationBar: _barraInferior(context),
      ),
    );
  }
}

class _PainelTab extends StatefulWidget {
  final ValueChanged<int> aoAbrirAba;
  final VoidCallback aoMostrarEstoqueBaixo;
  final ValueChanged<String> aoAbrirProduto;

  const _PainelTab({required this.aoAbrirAba, required this.aoMostrarEstoqueBaixo, required this.aoAbrirProduto});

  @override
  State<_PainelTab> createState() => _PainelTabState();
}

class _PainelTabState extends State<_PainelTab> {
  late Future<Dados<Dashboard>> _futuro = ApiService.instancia.dashboard();
  late Future<Dados<GraficosDashboard>> _graficos = ApiService.instancia.graficos();
  late Future<Dados<MetaAtual>> _meta = ApiService.instancia.metaAtual();
  late Future<Dados<List<ItemReposicao>>> _reposicao = ApiService.instancia.reposicao();

  Future<void> _atualizar() async {
    setState(() {
      _futuro = ApiService.instancia.dashboard();
      _graficos = ApiService.instancia.graficos();
      _meta = ApiService.instancia.metaAtual();
      _reposicao = ApiService.instancia.reposicao();
    });
    try {
      await Future.wait([_futuro, _graficos, _meta, _reposicao]);
    } on ApiException {
      // O erro ja aparece na tela pelo FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ApiService.instancia.usuario;

    return CarregarDados<Dashboard>(
      futuro: _futuro,
      aoAtualizar: _atualizar,
      construir: (dados) {
        final d = dados.valor;
        final ios = ehIOS(context);
        return ListaAtualizavel(
          aoAtualizar: _atualizar,
          children: [
            if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá, ${usuario?.nome ?? ''}', style: estiloTitulo(context)),
                  Text('Nível de acesso: ${usuario?.nivel ?? '-'}', style: estiloSecundario(context)),
                ],
              ),
            ),
            FutureBuilder<Dados<MetaAtual>>(
              future: _meta,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final meta = snapshot.data!.valor;
                return _Cartao(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Metas · ${meta.mes}', style: estiloSubtitulo(context)),
                      const SizedBox(height: 12),
                      AneisMeta(meta: meta),
                      const SizedBox(height: 8),
                      Text(
                        'Projeção do mês: ${formatarMoeda(meta.projecaoFaturamento)} · ${meta.diasRestantes} dias restantes',
                        style: estiloLegenda(context),
                      ),
                    ],
                  ),
                );
              },
            ),
            SecaoLista(
              cabecalho: 'Resumo',
              children: [
                _Indicador(
                  icone: ios ? CupertinoIcons.money_dollar_circle : Icons.attach_money,
                  cor: corVerde(context),
                  titulo: 'Faturamento',
                  valor: formatarMoeda(d.faturamentoTotal),
                  aoTocar: () => widget.aoAbrirAba(3),
                ),
                _Indicador(
                  icone: ios ? CupertinoIcons.doc_text : Icons.receipt_long,
                  cor: corIndigo(context),
                  titulo: 'Pedidos',
                  valor: '${d.totalPedidos}',
                  aoTocar: () => widget.aoAbrirAba(3),
                ),
                _Indicador(
                  icone: ios ? CupertinoIcons.tag : Icons.checkroom,
                  cor: corAzul(context),
                  titulo: 'Produtos',
                  valor: '${d.totalProdutos}',
                  aoTocar: () => widget.aoAbrirAba(1),
                ),
                _Indicador(
                  icone: ios ? CupertinoIcons.person_2 : Icons.people,
                  cor: corTeal(context),
                  titulo: 'Clientes',
                  valor: '${d.totalClientes}',
                  aoTocar: () => widget.aoAbrirAba(2),
                ),
                _Indicador(
                  icone: ios ? CupertinoIcons.exclamationmark_triangle : Icons.warning_amber,
                  cor: d.produtosEstoqueBaixo > 0 ? corLaranja(context) : corCinza(context),
                  titulo: 'Estoque baixo',
                  valor: '${d.produtosEstoqueBaixo}',
                  aoTocar: widget.aoMostrarEstoqueBaixo,
                ),
              ],
            ),
            _Reposicao(
              futuro: _reposicao,
              aoVerTodos: widget.aoMostrarEstoqueBaixo,
              aoAbrirProduto: widget.aoAbrirProduto,
            ),
            FutureBuilder<Dados<GraficosDashboard>>(
              future: _graficos,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final g = snapshot.data!.valor;
                return Column(
                  children: [
                    _Cartao(child: GraficoBarras(titulo: 'Faturamento por mês', pontos: g.vendasPorMes, formatar: formatarMoeda)),
                    _Cartao(
                      child: GraficoBarras(
                        titulo: 'Mais vendidos',
                        pontos: g.produtosMaisVendidos,
                        formatar: (v) => '${v.toStringAsFixed(0)} un.',
                        horizontal: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Cartao branco arredondado com a mesma margem das secoes de lista.
class _Cartao extends StatelessWidget {
  final Widget child;

  const _Cartao({required this.child});

  @override
  Widget build(BuildContext context) {
    final ios = ehIOS(context);
    return Container(
      margin: EdgeInsets.fromLTRB(ios ? 20 : 16, 8, ios ? 20 : 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ios ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ios ? 10 : 16),
      ),
      child: child,
    );
  }
}

class _Indicador extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String valor;
  final VoidCallback aoTocar;

  const _Indicador({required this.icone, required this.cor, required this.titulo, required this.valor, required this.aoTocar});

  @override
  Widget build(BuildContext context) => ItemLista(
        inicio: Icon(icone, color: cor),
        titulo: titulo,
        valor: valor,
        seta: true,
        aoTocar: aoTocar,
      );
}

/// Itens que acabam antes da proxima entrega, vindos da central de reposicao da API.
class _Reposicao extends StatelessWidget {
  final Future<Dados<List<ItemReposicao>>> futuro;
  final VoidCallback aoVerTodos;
  final ValueChanged<String> aoAbrirProduto;

  const _Reposicao({required this.futuro, required this.aoVerTodos, required this.aoAbrirProduto});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Dados<List<ItemReposicao>>>(
      future: futuro,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final repor = snapshot.data!.valor.where((r) => r.situacao != 'Ok').toList();
        return SecaoLista(
          cabecalho: 'Precisam de reposição',
          rodape: repor.isEmpty
              ? 'Todos os produtos estão com estoque em dia.'
              : '${repor.length} item(ns) acabam antes da próxima entrega, pela previsão de vendas.',
          children: [
            for (final r in repor.take(4))
              ItemLista(
                inicio: Icon(Icons.circle, size: 12, color: r.critico ? corVermelha(context) : corLaranja(context),
                    semanticLabel: r.critico ? 'Crítico' : 'Atenção'),
                titulo: r.produto,
                subtitulo: 'Estoque ${r.estoque} · dura ${r.diasDeCobertura ?? '-'} dias',
                valor: 'Comprar ${r.quantidadeSugerida}',
                seta: true,
                aoTocar: () => aoAbrirProduto(r.produto),
              ),
            if (repor.isNotEmpty)
              ItemLista(
                titulo: 'Ver todos com estoque baixo',
                seta: true,
                aoTocar: aoVerTodos,
              ),
          ],
        );
      },
    );
  }
}
