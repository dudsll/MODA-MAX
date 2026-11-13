import 'package:flutter/material.dart';

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
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;

  static const _titulos = ['Painel', 'Produtos', 'Clientes', 'Pedidos'];

  Future<void> _sair() async {
    await ApiService.instancia.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      const _PainelTab(),
      const ProdutosScreen(),
      const ClientesScreen(),
      const PedidosScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_aba]),
        actions: [
          IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout), onPressed: _sair),
        ],
      ),
      body: IndexedStack(index: _aba, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), label: 'Produtos'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Pedidos'),
        ],
      ),
    );
  }
}

class _PainelTab extends StatefulWidget {
  const _PainelTab();

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
            _Indicador(icone: Icons.attach_money, titulo: 'Faturamento', valor: formatarMoeda(d.faturamentoTotal)),
            _Indicador(icone: Icons.receipt_long, titulo: 'Pedidos', valor: '${d.totalPedidos}'),
            _Indicador(icone: Icons.checkroom, titulo: 'Produtos', valor: '${d.totalProdutos}'),
            _Indicador(icone: Icons.people, titulo: 'Clientes', valor: '${d.totalClientes}'),
            _Indicador(
              icone: Icons.warning_amber,
              titulo: 'Produtos com estoque baixo',
              valor: '${d.produtosEstoqueBaixo}',
              destaque: d.produtosEstoqueBaixo > 0,
            ),
            const SizedBox(height: 8),
            FutureBuilder<Dados<GraficosDashboard>>(
              future: _graficos,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final g = snapshot.data!.valor;
                return Column(
                  children: [
                    _CartaoReposicao(futuro: _reposicao),
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

  const _Indicador({required this.icone, required this.titulo, required this.valor, this.destaque = false});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      color: destaque ? cores.errorContainer : null,
      child: ListTile(
        leading: Icon(icone),
        title: Text(titulo),
        trailing: Text(valor, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// Produtos que acabam antes da proxima entrega, vindos da central de reposicao da API.
class _CartaoReposicao extends StatelessWidget {
  final Future<Dados<List<ItemReposicao>>> futuro;

  const _CartaoReposicao({required this.futuro});

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(Icons.inventory_2_outlined, color: cores.primary),
                title: const Text('Precisam de reposição'),
                subtitle: Text(repor.isEmpty ? 'Todos os produtos estão com estoque em dia.' : '${repor.length} produto(s) pela previsão de vendas'),
              ),
              for (final r in repor.take(4))
                ListTile(
                  dense: true,
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

