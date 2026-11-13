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
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(_titulos[indice]),
              actions: [IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout), onPressed: _sair)],
            ),
            body: raiz,
          ),
        ),
      );

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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: _tocarAba,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Painel'),
            NavigationDestination(icon: Icon(Icons.checkroom_outlined), label: 'Produtos'),
            NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientes'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Pedidos'),
          ],
        ),
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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
            Text('Olá, ${usuario?.nome ?? ''}', style: Theme.of(context).textTheme.titleLarge),
            Text('Nível de acesso: ${usuario?.nivel ?? '-'}'),
            const SizedBox(height: 16),
            FutureBuilder<Dados<MetaAtual>>(
              future: _meta,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final meta = snapshot.data!.valor;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Metas · ${meta.mes}', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        AneisMeta(meta: meta),
                        const SizedBox(height: 8),
                        Text(
                          'Projeção do mês: ${formatarMoeda(meta.projecaoFaturamento)} · ${meta.diasRestantes} dias restantes',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            _Indicador(
              icone: Icons.attach_money,
              titulo: 'Faturamento',
              valor: formatarMoeda(d.faturamentoTotal),
              aoTocar: () => widget.aoAbrirAba(3),
            ),
            _Indicador(icone: Icons.receipt_long, titulo: 'Pedidos', valor: '${d.totalPedidos}', aoTocar: () => widget.aoAbrirAba(3)),
            _Indicador(icone: Icons.checkroom, titulo: 'Produtos', valor: '${d.totalProdutos}', aoTocar: () => widget.aoAbrirAba(1)),
            _Indicador(icone: Icons.people, titulo: 'Clientes', valor: '${d.totalClientes}', aoTocar: () => widget.aoAbrirAba(2)),
            _Indicador(
              icone: Icons.warning_amber,
              titulo: 'Produtos com estoque baixo',
              valor: '${d.produtosEstoqueBaixo}',
              destaque: d.produtosEstoqueBaixo > 0,
              aoTocar: widget.aoMostrarEstoqueBaixo,
            ),
            const SizedBox(height: 8),
            FutureBuilder<Dados<GraficosDashboard>>(
              future: _graficos,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final g = snapshot.data!.valor;
                return Column(
                  children: [
                    _CartaoReposicao(
                      futuro: _reposicao,
                      aoVerTodos: widget.aoMostrarEstoqueBaixo,
                      aoAbrirProduto: widget.aoAbrirProduto,
                    ),
                    GraficoBarras(titulo: 'Faturamento por mês', pontos: g.vendasPorMes, formatar: formatarMoeda),
                    GraficoBarras(
                      titulo: 'Mais vendidos',
                      pontos: g.produtosMaisVendidos,
                      formatar: (v) => '${v.toStringAsFixed(0)} un.',
                      horizontal: true,
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

class _Indicador extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String valor;
  final bool destaque;
  final VoidCallback aoTocar;

  const _Indicador({
    required this.icone,
    required this.titulo,
    required this.valor,
    required this.aoTocar,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      color: destaque ? cores.errorContainer : null,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: aoTocar,
        leading: Icon(icone),
        title: Text(titulo),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(valor, style: Theme.of(context).textTheme.titleMedium),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// Produtos que acabam antes da proxima entrega, vindos da central de reposicao da API.
class _CartaoReposicao extends StatelessWidget {
  final Future<Dados<List<ItemReposicao>>> futuro;
  final VoidCallback aoVerTodos;
  final ValueChanged<String> aoAbrirProduto;

  const _CartaoReposicao({required this.futuro, required this.aoVerTodos, required this.aoAbrirProduto});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Dados<List<ItemReposicao>>>(
      future: futuro,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final repor = snapshot.data!.valor.where((r) => r.situacao != 'Ok').toList();
        final cores = Theme.of(context).colorScheme;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                onTap: aoVerTodos,
                trailing: const Icon(Icons.chevron_right),
                leading: Icon(Icons.inventory_2_outlined, color: cores.primary),
                title: const Text('Precisam de reposição'),
                subtitle: Text(repor.isEmpty ? 'Todos os produtos estão com estoque em dia.' : '${repor.length} produto(s) pela previsão de vendas'),
              ),
              for (final r in repor.take(4))
                ListTile(
                  dense: true,
                  onTap: () => aoAbrirProduto(r.produto),
                  leading: Icon(Icons.circle, size: 12, color: r.critico ? Colors.red : Colors.orange,
                      semanticLabel: r.critico ? 'Crítico' : 'Atenção'),
                  title: Text(r.produto),
                  subtitle: Text('Estoque ${r.estoque} · dura ${r.diasDeCobertura ?? '-'} dias'),
                  trailing: Text('Comprar ${r.quantidadeSugerida}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        );
      },
    );
  }
}

