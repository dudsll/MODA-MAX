import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';
import 'leitor_screen.dart';

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

  /// Le o codigo de barras da etiqueta e mostra o produto correspondente.
  Future<void> _lerCodigo() async {
    final codigo = await LeitorCodigoScreen.abrir(context);
    if (codigo == null || !mounted) return;

    try {
      final produto = await ApiService.instancia.produtoPorCodigo(codigo);
      if (!mounted) return;
      final estoqueMudou = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => FichaProduto(produto: produto),
      );
      if (estoqueMudou == true) await _atualizar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    }
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _lerCodigo,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Ler código de barras'),
            ),
          ),
          if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
          if (dados.valor.isEmpty) const ListTile(title: Text('Nenhum produto encontrado.')),
          for (final p in dados.valor) _ProdutoTile(produto: p),
        ],
      ),
    );
  }
}

/// Miniatura da foto do produto; sem foto (ou sem rede), mostra o tamanho da peca.
class FotoProduto extends StatelessWidget {
  final Produto produto;
  final double tamanho;

  const FotoProduto({super.key, required this.produto, this.tamanho = 48});

  @override
  Widget build(BuildContext context) {
    final endereco = produto.enderecoFoto(apiBaseUrl);
    final semFoto = CircleAvatar(radius: tamanho / 2, child: Text(produto.tamanho));
    if (endereco == null) return semFoto;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tamanho / 4),
      child: Image.network(
        endereco,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        semanticLabel: 'Foto de ${produto.nome}',
        errorBuilder: (_, __, ___) => semFoto,
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
        leading: FotoProduto(produto: produto),
        title: Text(produto.nome),
        subtitle: Text('${produto.categoria ?? ''} - ${produto.cor} - Tam. ${produto.tamanho}'),
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

/// Ficha do produto lido pelo codigo de barras. Gerencia e diretoria podem registrar a
/// entrada de mercadoria ali mesmo (a API executa a procedure sp_RegistrarEntradaEstoque).
/// Fecha devolvendo true quando o estoque foi alterado.
class FichaProduto extends StatefulWidget {
  final Produto produto;

  const FichaProduto({super.key, required this.produto});

  @override
  State<FichaProduto> createState() => _FichaProdutoState();
}

class _FichaProdutoState extends State<FichaProduto> {
  final _quantidade = TextEditingController(text: '1');
  late int _estoque = widget.produto.estoque;
  bool _alterado = false;
  bool _enviando = false;

  Future<void> _registrarEntrada() async {
    final quantidade = int.tryParse(_quantidade.text);
    if (quantidade == null || quantidade <= 0) {
      mostrarMensagem(context, 'Informe uma quantidade maior que zero.');
      return;
    }

    setState(() => _enviando = true);
    try {
      final novoEstoque = await ApiService.instancia.entradaEstoque(
        widget.produto.idProduto,
        quantidade,
        observacao: 'Entrada pelo leitor de código de barras do app',
      );
      if (!mounted) return;
      setState(() {
        _estoque = novoEstoque;
        _alterado = true;
      });
      mostrarMensagem(context, 'Entrada registrada. Estoque atual: $novoEstoque.');
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    _quantidade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final textos = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) Navigator.of(context).pop(_alterado);
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FotoProduto(produto: p, tamanho: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nome, style: textos.titleLarge),
                        Text('${p.categoria ?? ''} - ${p.cor} - Tam. ${p.tamanho}'),
                        Text('Código: ${p.codigoBarras ?? '-'}', style: textos.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preço'),
                trailing: Text(formatarMoeda(p.preco), style: textos.titleMedium),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Estoque'),
                trailing: Text('$_estoque peças', style: textos.titleMedium),
              ),
              if (ApiService.instancia.podeGerenciarEstoque) ...[
                const Divider(),
                Text('Entrada de mercadoria', style: textos.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantidade,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _enviando ? null : _registrarEntrada,
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Registrar'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_alterado),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
