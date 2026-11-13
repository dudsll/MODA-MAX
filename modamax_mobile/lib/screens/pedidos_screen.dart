import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    setState(() { _futuro = ApiService.instancia.pedidos(); });
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
    return CarregarDados<List<Pedido>>(
      futuro: _futuro,
      aoAtualizar: _atualizar,
      construir: (dados) => ListaAtualizavel(
        aoAtualizar: _atualizar,
        children: [
          const SizedBox(height: 8),
          BotaoNovo(texto: 'Novo pedido', aoTocar: dados.doCache ? null : _novoPedido),
          if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
          if (dados.valor.isEmpty) const SecaoLista(children: [ItemLista(titulo: 'Nenhum pedido registrado.')]),
          SecaoLista(
            rodape: dados.valor.isEmpty ? null : '${dados.valor.length} pedidos',
            children: [
              for (final p in dados.valor)
                ItemLista(
                  inicio: StatusPedido(status: p.status),
                  titulo: p.cliente ?? 'Pedido #${p.idPedido}',
                  subtitulo: '#${p.idPedido} · ${formatarData(p.dataPedido).substring(0, 5)} · ${p.status}',
                  valor: formatarMoeda(p.valorTotal),
                  seta: true,
                  aoTocar: () => _abrirDetalhe(p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusPedido extends StatelessWidget {
  final String status;

  const StatusPedido({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final ios = ehIOS(context);
    final (icone, cor) = switch (status) {
      'Finalizado' => (ios ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle, corVerde(context)),
      'Cancelado' => (ios ? CupertinoIcons.xmark_circle_fill : Icons.cancel, corVermelha(context)),
      _ => (ios ? CupertinoIcons.cube_box_fill : Icons.inventory_2, corLaranja(context)),
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
  bool _pagando = false;

  /// Busca o "PIX copia e cola" do pedido na API e oferece copiar para enviar ao cliente.
  Future<void> _mostrarPix() async {
    try {
      final codigo = await ApiService.instancia.pixDoPedido(widget.pedido.idPedido);
      if (!mounted) return;
      final copiou = await abrirFolha<bool>(
        context,
        construir: (folha, rolagem) => Folha(
          titulo: 'PIX copia e cola',
          rolagem: rolagem,
          children: [
            SecaoLista(
              rodape: 'Envie este código ao cliente; ele cola no app do banco para pagar.',
              children: [
                ItemLista(titulo: 'Valor', valor: formatarMoeda(widget.pedido.valorTotal)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(codigo, style: const TextStyle(fontFamily: 'Menlo', fontSize: 12)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Botao.principal(
                'Copiar código',
                iconeMaterial: Icons.copy,
                iconeIOS: CupertinoIcons.doc_on_doc,
                aoTocar: () async {
                  await Clipboard.setData(ClipboardData(text: codigo));
                  if (folha.mounted) Navigator.of(folha).pop(true);
                },
              ),
            ),
          ],
        ),
      );
      if (copiou == true && mounted) mostrarMensagem(context, 'Código PIX copiado.');
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    }
  }

  Future<void> _confirmarPagamento() async {
    setState(() => _pagando = true);
    try {
      await ApiService.instancia.confirmarPagamento(widget.pedido.idPedido);
      if (!mounted) return;
      mostrarMensagem(context, 'Pagamento confirmado.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  Future<void> _cancelar() async {
    final confirmou = await confirmar(
      context,
      titulo: 'Cancelar pedido?',
      mensagem: 'Os itens voltam para o estoque e o pagamento recebido é estornado.',
      acao: 'Cancelar pedido',
      cancelar: 'Voltar',
    );
    if (!confirmou) return;

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
    final ios = ehIOS(context);
    final pago = p.statusPagamento == 'Pago';

    return Pagina(
      titulo: 'Pedido #${p.idPedido}',
      corpo: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SecaoLista(children: [
            ItemLista(
              inicio: Icon(icone(context, material: Icons.person, ios: CupertinoIcons.person_crop_circle)),
              titulo: p.cliente ?? '-',
              subtitulo: 'Cliente',
            ),
            ItemLista(
              inicio: StatusPedido(status: p.status),
              titulo: p.status,
              subtitulo: '${formatarData(p.dataPedido)} · ${p.tiposVenda}',
            ),
          ]),
          SecaoLista(cabecalho: 'Itens', children: [
            for (final i in p.itens)
              ItemLista(
                titulo: i.produto ?? 'Produto ${i.idProduto}',
                subtitulo: '${i.quantidade} x ${formatarMoeda(i.precoUnitario)}',
                valor: formatarMoeda(i.subtotal),
              ),
            ItemLista(titulo: 'Total', valor: formatarMoeda(p.valorTotal)),
          ]),
          SecaoLista(cabecalho: 'Pagamento', children: [
            ItemLista(
              inicio: Icon(
                pago
                    ? (ios ? CupertinoIcons.checkmark_seal_fill : Icons.verified)
                    : (ios ? CupertinoIcons.clock : Icons.schedule),
                color: pago ? corVerde(context) : corLaranja(context),
              ),
              titulo: '${nomePagamento(p.formaPagamento)}${p.parcelas > 1 ? ' em ${p.parcelas}x de ${formatarMoeda(p.valorTotal / p.parcelas)}' : ''}',
              subtitulo: 'Pagamento ${p.statusPagamento.toLowerCase()}',
            ),
          ]),
          if (p.pagamentoPendente)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  if (p.formaPagamento == 'Pix') ...[
                    Botao.secundario('PIX copia e cola', iconeMaterial: Icons.qr_code_2, iconeIOS: CupertinoIcons.qrcode, aoTocar: _mostrarPix),
                    const SizedBox(height: 10),
                  ],
                  Botao.principal(
                    'Confirmar pagamento',
                    iconeMaterial: Icons.check_circle_outline,
                    iconeIOS: CupertinoIcons.checkmark_circle,
                    carregando: _pagando,
                    aoTocar: _confirmarPagamento,
                  ),
                ],
              ),
            ),
          // Cancelar e permitido so aos niveis Estrategico e Tatico (mesma regra da API).
          if (p.status != 'Cancelado' && ApiService.instancia.podeGerenciarEstoque) ...[
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ios ? 0 : 16),
              child: BotaoApagar(texto: 'Cancelar Pedido', aoTocar: _cancelando ? null : _cancelar),
            ),
          ],
        ],
      ),
    );
  }
}
