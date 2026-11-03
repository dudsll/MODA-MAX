import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';
import 'leitor_screen.dart';

/// Registro de pedido pelo app: escolhe cliente, tipo de venda e itens.
/// A API valida estoque, aplica 10% de desconto no atacado e da baixa no estoque.
class NovoPedidoScreen extends StatefulWidget {
  const NovoPedidoScreen({super.key});

  @override
  State<NovoPedidoScreen> createState() => _NovoPedidoScreenState();
}

class _NovoPedidoScreenState extends State<NovoPedidoScreen> {
  late final Future<(List<Cliente>, List<Produto>)> _dados = _carregar();

  Cliente? _cliente;
  String _tipoVenda = 'Varejo';
  final List<ItemCarrinho> _itens = [];
  bool _enviando = false;

  Future<(List<Cliente>, List<Produto>)> _carregar() async {
    final clientes = await ApiService.instancia.clientes();
    final produtos = await ApiService.instancia.produtos();
    return (clientes.valor, produtos.valor.where((p) => p.estoque > 0).toList());
  }

  double _precoUnitario(Produto p) =>
      _tipoVenda == 'Atacado' ? double.parse((p.preco * 0.9).toStringAsFixed(2)) : p.preco;

  double get _total => _itens.fold(0, (soma, i) => soma + _precoUnitario(i.produto) * i.quantidade);

  Future<void> _adicionarProduto(List<Produto> produtos) async {
    final produto = await showModalBottomSheet<Produto>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Escolha o produto')),
            for (final p in produtos)
              ListTile(
                title: Text(p.nome),
                subtitle: Text('Tam. ${p.tamanho} - ${p.estoque} em estoque'),
                trailing: Text(formatarMoeda(p.preco)),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (produto == null) return;
    _adicionarAoCarrinho(produto);
  }

  /// Le a etiqueta e coloca o produto no carrinho; ler de novo aumenta a quantidade.
  Future<void> _lerCodigo(List<Produto> produtos) async {
    final codigo = await LeitorCodigoScreen.abrir(context, titulo: 'Adicionar pelo código');
    if (codigo == null || !mounted) return;

    final produto = produtos.where((p) => p.codigoBarras == codigo).firstOrNull;
    if (produto == null) {
      mostrarMensagem(context, 'Nenhum produto disponível com o código $codigo.');
      return;
    }
    _adicionarAoCarrinho(produto);
    mostrarMensagem(context, '${produto.nome} adicionado.');
  }

  void _adicionarAoCarrinho(Produto produto) {
    setState(() {
      final existente = _itens.where((i) => i.produto.idProduto == produto.idProduto).firstOrNull;
      if (existente != null) {
        if (existente.quantidade < produto.estoque) existente.quantidade++;
      } else {
        _itens.add(ItemCarrinho(produto));
      }
    });
  }

  Future<void> _enviar() async {
    if (_cliente == null) {
      mostrarMensagem(context, 'Selecione o cliente.');
      return;
    }
    if (_itens.isEmpty) {
      mostrarMensagem(context, 'Adicione ao menos um produto.');
      return;
    }

    setState(() => _enviando = true);
    try {
      final pedido = await ApiService.instancia.criarPedido(
        idCliente: _cliente!.idCliente,
        tipoVenda: _tipoVenda,
        itens: _itens,
      );
      if (!mounted) return;
      mostrarMensagem(context, 'Pedido #${pedido.idPedido} registrado.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo pedido')),
      body: FutureBuilder<(List<Cliente>, List<Produto>)>(
        future: _dados,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final (clientes, produtos) = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<Cliente>(
                value: _cliente,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                items: [
                  for (final c in clientes) DropdownMenuItem(value: c, child: Text(c.nome)),
                ],
                onChanged: (c) => setState(() => _cliente = c),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Varejo', label: Text('Varejo')),
                  ButtonSegment(value: 'Atacado', label: Text('Atacado (-10%)')),
                ],
                selected: {_tipoVenda},
                onSelectionChanged: (s) => setState(() => _tipoVenda = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Itens', style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Adicionar pelo código de barras',
                    onPressed: () => _lerCodigo(produtos),
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                  TextButton.icon(
                    onPressed: () => _adicionarProduto(produtos),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar produto'),
                  ),
                ],
              ),
              if (_itens.isEmpty) const ListTile(title: Text('Nenhum produto adicionado.')),
              for (final item in _itens)
                ListTile(
                  title: Text(item.produto.nome),
                  subtitle: Text('${formatarMoeda(_precoUnitario(item.produto))} cada'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Diminuir quantidade de ${item.produto.nome}',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          if (item.quantidade > 1) {
                            item.quantidade--;
                          } else {
                            _itens.remove(item);
                          }
                        }),
                      ),
                      Text('${item.quantidade}', semanticsLabel: 'Quantidade ${item.quantidade}'),
                      IconButton(
                        tooltip: 'Aumentar quantidade de ${item.produto.nome}',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: item.quantidade >= item.produto.estoque
                            ? null
                            : () => setState(() => item.quantidade++),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              ListTile(
                title: const Text('Total estimado'),
                trailing: Text(formatarMoeda(_total), style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: const Icon(Icons.send),
                label: const Text('Registrar pedido'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          );
        },
      ),
    );
  }
}
