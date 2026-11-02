import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
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

  Future<void> _atualizar() async {
    setState(() {
      _futuro = ApiService.instancia.dashboard();
      _graficos = ApiService.instancia.graficos();
    });
    try {
      await Future.wait([_futuro, _graficos]);
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
            Text('Ola, ${usuario?.nome ?? ''}', style: Theme.of(context).textTheme.titleLarge),
            Text('Nivel de acesso: ${usuario?.nivel ?? '-'}'),
            const SizedBox(height: 16),
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
                    GraficoBarras(titulo: 'Faturamento por mes', pontos: g.vendasPorMes, formatar: formatarMoeda),
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
