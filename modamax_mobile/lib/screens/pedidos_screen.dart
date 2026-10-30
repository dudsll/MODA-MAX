import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';
import 'novo_pedido_screen.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  late Future<Dados<List<Pedido>>> _futuro = ApiService.instancia.pedidos();

  Future<void> _atualizar() async {
    setState(() => _futuro = ApiService.instancia.pedidos());
    await _futuro;
  }

  Future<void> _novoPedido() async {
    final criou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NovoPedidoScreen()),
    );
    if (criou == true) _atualizar();
  }

  Future<void> _abrirDetalhe(Pedido pedido) async {
    final alterou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PedidoDetalheScreen(pedido: pedido)),
    );
    if (alterou == true) _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoPedido,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Novo pedido'),
      ),
      body: CarregarDados<List<Pedido>>(
        futuro: _futuro,
        aoAtualizar: _atualizar,
        construir: (dados) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
            if (dados.valor.isEmpty) const ListTile(title: Text('Nenhum pedido registrado.')),
            for (final p in dados.valor)
              ListTile(
                leading: StatusPedido(status: p.status),
                title: Text('Pedido #${p.idPedido} - ${p.cliente ?? ''}'),
                subtitle: Text('${formatarData(p.dataPedido)} - ${p.tiposVenda} - ${p.status}'),
                trailing: Text(formatarMoeda(p.valorTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _abrirDetalhe(p),
              ),
          ],
        ),
      ),
    );
  }
}

class StatusPedido extends StatelessWidget {
  final String status;

  const StatusPedido({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (icone, cor) = switch (status) {
      'Finalizado' => (Icons.check_circle, Colors.green),
      'Cancelado' => (Icons.cancel, Colors.red),
      _ => (Icons.inventory_2, Colors.orange),
    };
    // O texto do status tambem aparece na linha, entao a cor nao e a unica pista (acessibilidade).
    return Icon(icone, color: cor, semanticLabel: status);
  }
}

class PedidoDetalheScreen extends StatefulWidget {
  final Pedido pedido;

  const PedidoDetalheScreen({super.key, required this.pedido});

  @override
  State<PedidoDetalheScreen> createState() => _PedidoDetalheScreenState();
}

class _PedidoDetalheScreenState extends State<PedidoDetalheScreen> {
  bool _cancelando = false;

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar pedido?'),
        content: const Text('Os itens voltam para o estoque.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar pedido')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cancelando = true);
    try {
      await ApiService.instancia.cancelarPedido(widget.pedido.idPedido);
      if (!mounted) return;
      mostrarMensagem(context, 'Pedido cancelado.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Pedido #${p.idPedido}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(leading: const Icon(Icons.person), title: Text(p.cliente ?? '-'), subtitle: const Text('Cliente')),
          ListTile(
            leading: StatusPedido(status: p.status),
            title: Text(p.status),
            subtitle: Text('${formatarData(p.dataPedido)} - ${p.tiposVenda}'),
          ),
          const Divider(),
          Text('Itens', style: tema.textTheme.titleMedium),
          for (final i in p.itens)
            ListTile(
              title: Text(i.produto ?? 'Produto ${i.idProduto}'),
              subtitle: Text('${i.quantidade} x ${formatarMoeda(i.precoUnitario)}'),
              trailing: Text(formatarMoeda(i.subtotal)),
            ),
          const Divider(),
          ListTile(
            title: const Text('Total'),
            trailing: Text(formatarMoeda(p.valorTotal), style: tema.textTheme.titleLarge),
          ),
          if (p.status != 'Cancelado') ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cancelando ? null : _cancelar,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar pedido'),
              style: OutlinedButton.styleFrom(
                foregroundColor: tema.colorScheme.error,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
