import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  String? _busca;
  late Future<Dados<List<Produto>>> _futuro = ApiService.instancia.produtos();

  Future<void> _atualizar() async {
    setState(() => _futuro = ApiService.instancia.produtos(busca: _busca));
    await _futuro;
  }

  @override
  Widget build(BuildContext context) {
    return CarregarDados<List<Produto>>(
      futuro: _futuro,
      aoAtualizar: _atualizar,
      construir: (dados) => ListView(
        children: [
          CampoBusca(
            dica: 'Buscar produto',
            aoBuscar: (texto) {
              _busca = texto;
              _atualizar();
            },
          ),
          if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
          if (dados.valor.isEmpty) const ListTile(title: Text('Nenhum produto encontrado.')),
          for (final p in dados.valor) _ProdutoTile(produto: p),
        ],
      ),
    );
  }
}

class _ProdutoTile extends StatelessWidget {
  final Produto produto;

  const _ProdutoTile({required this.produto});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final baixo = produto.estoque <= 15;

    return Semantics(
      label: '${produto.nome}, ${formatarMoeda(produto.preco)}, ${produto.estoque} em estoque',
      excludeSemantics: true,
      child: ListTile(
        leading: CircleAvatar(child: Text(produto.tamanho)),
        title: Text(produto.nome),
        subtitle: Text('${produto.categoria ?? ''} - ${produto.cor}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatarMoeda(produto.preco), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Estoque: ${produto.estoque}',
              style: TextStyle(color: baixo ? cores.error : null),
            ),
          ],
        ),
      ),
    );
  }
}
