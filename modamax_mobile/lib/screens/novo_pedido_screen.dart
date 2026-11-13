import 'package:flutter/cupertino.dart';
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
  String _formaPagamento = 'Pix';
  int _parcelas = 1;
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
    final produto = await abrirFolha<Produto>(
      context,
      construir: (folha, rolagem) => Folha(
        titulo: 'Escolha o produto',
        rolagem: rolagem,
        children: [
          SecaoLista(children: [
            for (final p in produtos)
              ItemLista(
                titulo: p.nome,
                subtitulo: 'Tam. ${p.tamanho} · ${p.cor} · ${p.estoque} em estoque',
                valor: formatarMoeda(p.preco),
                aoTocar: () => Navigator.of(folha).pop(p),
              ),
          ]),
        ],
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
        formaPagamento: _formaPagamento,
        parcelas: _formaPagamento == 'Credito' ? _parcelas : 1,
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
    return Pagina(
      titulo: 'Novo pedido',
      corpo: FutureBuilder<(List<Cliente>, List<Produto>)>(
        future: _dados,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());

          final (clientes, produtos) = snapshot.data!;
          final ios = ehIOS(context);

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SecaoFormulario(children: [
                Seletor<int>(
                  rotulo: 'Cliente',
                  valor: _cliente?.idCliente,
                  opcoes: {for (final c in clientes) c.idCliente: c.nome},
                  aoMudar: (id) => setState(() => _cliente = clientes.firstWhere((c) => c.idCliente == id)),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Segmentado<String>(
                  opcoes: const {'Varejo': 'Varejo', 'Atacado': 'Atacado (-10%)'},
                  selecionado: _tipoVenda,
                  aoMudar: (t) => setState(() => _tipoVenda = t),
                ),
              ),
              SecaoFormulario(cabecalho: 'Pagamento', children: [
                Seletor<String>(
                  rotulo: 'Forma de pagamento',
                  valor: _formaPagamento,
                  opcoes: formasPagamento,
                  aoMudar: (f) => setState(() {
                    _formaPagamento = f;
                    if (_formaPagamento != 'Credito') _parcelas = 1;
                  }),
                ),
                // Parcelamento so no cartao de credito, de 1 a 6 vezes (mesma regra da API).
                if (_formaPagamento == 'Credito')
                  Seletor<int>(
                    rotulo: 'Parcelas',
                    valor: _parcelas,
                    opcoes: {
                      for (var n = 1; n <= maxParcelas; n++) n: n == 1 ? 'À vista' : '${n}x de ${formatarMoeda(_total / n)}',
                    },
                    aoMudar: (n) => setState(() => _parcelas = n),
                  ),
              ]),
              SecaoLista(
                cabecalho: 'Itens',
                children: [
                  if (_itens.isEmpty) const ItemLista(titulo: 'Nenhum produto adicionado.'),
                  for (final item in _itens)
                    ItemLista(
                      titulo: item.produto.nome,
                      subtitulo: 'Tam. ${item.produto.tamanho} · ${formatarMoeda(_precoUnitario(item.produto))} cada',
                      fim: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BotaoIcone(
                            dica: 'Diminuir quantidade de ${item.produto.nome}',
                            iconeMaterial: Icons.remove_circle_outline,
                            iconeIOS: CupertinoIcons.minus_circle,
                            aoTocar: () => setState(() {
                              if (item.quantidade > 1) {
                                item.quantidade--;
                              } else {
                                _itens.remove(item);
                              }
                            }),
                          ),
                          Text('${item.quantidade}', semanticsLabel: 'Quantidade ${item.quantidade}'),
                          BotaoIcone(
                            dica: 'Aumentar quantidade de ${item.produto.nome}',
                            iconeMaterial: Icons.add_circle_outline,
                            iconeIOS: CupertinoIcons.plus_circle,
                            aoTocar: item.quantidade >= item.produto.estoque
                                ? null
                                : () => setState(() => item.quantidade++),
                          ),
                        ],
                      ),
                    ),
                  ItemLista(titulo: 'Total estimado', valor: formatarMoeda(_total)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Botao.secundario(
                        'Adicionar',
                        iconeMaterial: Icons.add,
                        iconeIOS: CupertinoIcons.add,
                        aoTocar: () => _adicionarProduto(produtos),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Botao.secundario(
                        'Ler código',
                        iconeMaterial: Icons.qr_code_scanner,
                        iconeIOS: CupertinoIcons.barcode_viewfinder,
                        aoTocar: () => _lerCodigo(produtos),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ios ? 20 : 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Botao.principal('Registrar pedido', carregando: _enviando, aoTocar: _enviar),
              ),
            ],
          );
        },
      ),
    );
  }
}
