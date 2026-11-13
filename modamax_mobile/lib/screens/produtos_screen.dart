import 'package:flutter/material.dart';

import '../catalogo.dart';
import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';
import 'leitor_screen.dart';
import 'produto_form_screen.dart';

/// Lista de produtos agrupada por modelo, com busca, filtros e leitor de codigo de barras.
class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => ProdutosScreenState();
}

class ProdutosScreenState extends State<ProdutosScreen> {
  String? _busca;
  FiltroProdutos _filtro = const FiltroProdutos();
  late Future<Dados<List<Produto>>> _futuro = ApiService.instancia.produtos();

  // Apagados arrastando: saem da lista na hora, sem esperar recarregar.
  final _apagados = <int>{};

  Future<void> _atualizar() async {
    setState(() {
      _apagados.clear();
      _futuro = ApiService.instancia.produtos(busca: _busca);
    });
    await _futuro;
  }

  /// Usado pelo painel: abre a lista ja filtrada pelos tamanhos com estoque baixo.
  void mostrarEstoqueBaixo() {
    setState(() => _filtro = FiltroProdutos(disponibilidade: Disponibilidade.estoqueBaixo, ordenacao: _filtro.ordenacao));
  }

  /// Usado pelo painel: recarrega a lista (ex.: depois de mudar algo em outra aba).
  Future<void> recarregar() => _atualizar();

  /// Le o codigo de barras da etiqueta e mostra o produto correspondente.
  Future<void> _lerCodigo() async {
    final codigo = await LeitorCodigoScreen.abrir(context);
    if (codigo == null || !mounted) return;

    try {
      final produto = await ApiService.instancia.produtoPorCodigo(codigo);
      if (!mounted) return;
      final estoqueMudou = await abrirFicha(context, produto);
      if (estoqueMudou == true) await _atualizar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    }
  }

  Future<void> _novoProduto() async {
    final mudou = await ProdutoFormScreen.abrir(context);
    if (mudou == true) await _atualizar();
  }

  Future<void> _abrirModelo(ModeloProduto modelo) async {
    final mudou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProdutoModeloScreen(nome: modelo.nome)),
    );
    if (mudou == true) await _atualizar();
  }

  Future<void> _abrirFiltros(List<Produto> produtos) async {
    final escolhido = await showModalBottomSheet<FiltroProdutos>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FiltrosSheet(produtos: produtos, inicial: _filtro),
    );
    if (escolhido != null) setState(() => _filtro = escolhido);
  }

  @override
  Widget build(BuildContext context) {
    final podeCadastrar = ApiService.instancia.podeGerenciarEstoque;
    return CarregarDados<List<Produto>>(
      futuro: _futuro,
      aoAtualizar: _atualizar,
      construir: (dados) {
        final produtos = dados.valor.where((p) => !_apagados.contains(p.idProduto)).toList();
        final modelos = _filtro.aplicar(produtos);
        return ListView(
          children: [
            CampoBusca(
              dica: 'Buscar produto ou código',
              aoBuscar: (texto) {
                _busca = texto;
                _atualizar();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _lerCodigo,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Ler código'),
                    ),
                  ),
                  if (podeCadastrar) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: dados.doCache ? null : _novoProduto,
                        icon: const Icon(Icons.add),
                        label: const Text('Novo produto'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _BarraFiltros(
              filtro: _filtro,
              resultados: modelos.length,
              aoAbrir: () => _abrirFiltros(produtos),
              aoMudar: (f) => setState(() => _filtro = f),
            ),
            if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
            if (modelos.isEmpty)
              ListTile(
                title: Text(_filtro.vazio ? 'Nenhum produto encontrado.' : 'Nenhum produto com esses filtros.'),
                subtitle: _filtro.vazio ? null : const Text('Toque em Filtros para mudar a seleção.'),
              ),
            for (final m in modelos)
              ArrastarParaApagar(
                chave: ValueKey('modelo-${m.nome}'),
                permitido: !dados.doCache && ApiService.instancia.podeExcluirProduto,
                aoApagar: () => apagarModelo(context, m),
                aoRemover: () => setState(() => _apagados.addAll(m.tamanhos.map((p) => p.idProduto))),
                child: _ModeloTile(modelo: m, aoTocar: () => _abrirModelo(m)),
              ),
          ],
        );
      },
    );
  }
}

/// Botao "Filtros" com o numero de filtros ativos e os filtros escolhidos em etiquetas
/// que podem ser removidas com um toque.
class _BarraFiltros extends StatelessWidget {
  final FiltroProdutos filtro;
  final int resultados;
  final VoidCallback aoAbrir;
  final ValueChanged<FiltroProdutos> aoMudar;

  const _BarraFiltros({required this.filtro, required this.resultados, required this.aoAbrir, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    final etiquetas = <Widget>[
      for (final c in filtro.categorias)
        _Etiqueta(c, () => aoMudar(filtro.copyWith(categorias: {...filtro.categorias}..remove(c)))),
      for (final f in filtro.fornecedores)
        _Etiqueta(f, () => aoMudar(filtro.copyWith(fornecedores: {...filtro.fornecedores}..remove(f)))),
      for (final t in filtro.tamanhos)
        _Etiqueta('Tam. $t', () => aoMudar(filtro.copyWith(tamanhos: {...filtro.tamanhos}..remove(t)))),
      for (final c in filtro.cores)
        _Etiqueta(c, () => aoMudar(filtro.copyWith(cores: {...filtro.cores}..remove(c)))),
      if (filtro.disponibilidade != Disponibilidade.todos)
        _Etiqueta(nomesDisponibilidade[filtro.disponibilidade]!,
            () => aoMudar(filtro.copyWith(disponibilidade: Disponibilidade.todos))),
      if (filtro.precoMinimo != null || filtro.precoMaximo != null)
        _Etiqueta('${formatarMoeda(filtro.precoMinimo ?? 0)} a ${formatarMoeda(filtro.precoMaximo ?? 0)}',
            () => aoMudar(filtro.copyWith(limparPreco: true))),
    ];
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: aoAbrir,
                icon: const Icon(Icons.tune),
                label: Text(filtro.vazio ? 'Filtros' : 'Filtros (${filtro.quantidade})'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$resultados ${resultados == 1 ? 'modelo' : 'modelos'} · ${nomesOrdenacao[filtro.ordenacao]}',
                  style: textos.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (etiquetas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              ...etiquetas,
              TextButton(
                onPressed: () => aoMudar(FiltroProdutos(ordenacao: filtro.ordenacao)),
                child: const Text('Limpar'),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final VoidCallback aoRemover;

  const _Etiqueta(this.texto, this.aoRemover);

  @override
  Widget build(BuildContext context) => InputChip(
        label: Text(texto),
        onDeleted: aoRemover,
        deleteButtonTooltipMessage: 'Remover filtro $texto',
      );
}

/// Folha de filtros: tipo de produto, fornecedor, tamanho, cor, disponibilidade, faixa de
/// preco e ordenacao. Mostra quantos modelos vao aparecer antes de aplicar.
class _FiltrosSheet extends StatefulWidget {
  final List<Produto> produtos;
  final FiltroProdutos inicial;

  const _FiltrosSheet({required this.produtos, required this.inicial});

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  late FiltroProdutos _f = widget.inicial;
  late final _opcoes = OpcoesFiltro.de(widget.produtos);

  Set<String> _alternar(Set<String> atual, String valor) =>
      atual.contains(valor) ? ({...atual}..remove(valor)) : {...atual, valor};

  Widget _secao(String titulo, List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  List<Widget> _chips(List<String> opcoes, Set<String> selecionados, void Function(String) aoTocar,
          {String prefixo = ''}) =>
      [
        for (final o in opcoes)
          FilterChip(
            label: Text('$prefixo$o'),
            selected: selecionados.contains(o),
            onSelected: (_) => setState(() => aoTocar(o)),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final resultado = _f.aplicar(widget.produtos).length;
    final faixa = _opcoes.maiorPreco > _opcoes.menorPreco;
    final minimo = (_f.precoMinimo ?? _opcoes.menorPreco).clamp(_opcoes.menorPreco, _opcoes.maiorPreco).toDouble();
    final maximo = (_f.precoMaximo ?? _opcoes.maiorPreco).clamp(minimo, _opcoes.maiorPreco).toDouble();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, rolagem) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: rolagem,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Text('Filtros', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                _secao('Ordenar por', [
                  for (final o in Ordenacao.values)
                    ChoiceChip(
                      label: Text(nomesOrdenacao[o]!),
                      selected: _f.ordenacao == o,
                      onSelected: (_) => setState(() => _f = _f.copyWith(ordenacao: o)),
                    ),
                ]),
                _secao('Tipo de produto', _chips(_opcoes.categorias, _f.categorias,
                    (o) => _f = _f.copyWith(categorias: _alternar(_f.categorias, o)))),
                _secao('Fornecedor', _chips(_opcoes.fornecedores, _f.fornecedores,
                    (o) => _f = _f.copyWith(fornecedores: _alternar(_f.fornecedores, o)))),
                _secao('Tamanho', _chips(_opcoes.tamanhos, _f.tamanhos,
                    (o) => _f = _f.copyWith(tamanhos: _alternar(_f.tamanhos, o)))),
                _secao('Cor', _chips(_opcoes.cores, _f.cores,
                    (o) => _f = _f.copyWith(cores: _alternar(_f.cores, o)))),
                _secao('Disponibilidade', [
                  for (final d in Disponibilidade.values)
                    ChoiceChip(
                      label: Text(nomesDisponibilidade[d]!),
                      selected: _f.disponibilidade == d,
                      onSelected: (_) => setState(() => _f = _f.copyWith(disponibilidade: d)),
                    ),
                ]),
                if (faixa) ...[
                  const SizedBox(height: 16),
                  Text('Preço: ${formatarMoeda(minimo)} a ${formatarMoeda(maximo)}',
                      style: Theme.of(context).textTheme.titleSmall),
                  RangeSlider(
                    min: _opcoes.menorPreco,
                    max: _opcoes.maiorPreco,
                    values: RangeValues(minimo, maximo),
                    labels: RangeLabels(formatarMoeda(minimo), formatarMoeda(maximo)),
                    onChanged: (v) => setState(() {
                      final inteiro = v.start <= _opcoes.menorPreco && v.end >= _opcoes.maiorPreco;
                      _f = inteiro
                          ? _f.copyWith(limparPreco: true)
                          : _f.copyWith(precoMinimo: v.start, precoMaximo: v.end);
                    }),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _f = FiltroProdutos(ordenacao: _f.ordenacao)),
                    child: const Text('Limpar'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_f),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: Text('Mostrar $resultado ${resultado == 1 ? 'modelo' : 'modelos'}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Um modelo na lista: foto, nome, tipo e fornecedor, tamanhos, preco e estoque.
class _ModeloTile extends StatelessWidget {
  final ModeloProduto modelo;
  final VoidCallback aoTocar;

  const _ModeloTile({required this.modelo, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final m = modelo;
    final preco = m.menorPreco == m.maiorPreco ? formatarMoeda(m.menorPreco) : 'a partir de ${formatarMoeda(m.menorPreco)}';
    final tamanhos = m.tamanhos.map((p) => p.tamanho).toSet().join(' · ');
    final listaCores = m.cores.length > 1 ? '\n${m.cores.length} cores: ${m.cores.join(', ')}' : '';

    return Semantics(
      label: '${m.nome}, $preco, tamanhos $tamanhos, ${m.estoqueTotal} peças em estoque',
      excludeSemantics: true,
      button: true,
      child: ListTile(
        onTap: aoTocar,
        leading: FotoProduto(produto: m.principal, tamanho: 56),
        title: Text(m.nome),
        subtitle: Text('${[m.categoria, m.fornecedor].whereType<String>().join(' · ')}\nTam. $tamanhos$listaCores'),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(preco, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${m.estoqueTotal} peças',
              style: TextStyle(color: m.temEstoqueBaixo ? cores.error : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pergunta e apaga todos os tamanhos de um modelo (somente diretoria). A API recusa os
/// tamanhos que ja foram vendidos; o aviso diz quantos ficaram.
Future<bool> apagarModelo(BuildContext context, ModeloProduto modelo) async {
  if (modelo.tamanhos.length == 1) return apagarProduto(context, modelo.tamanhos.first);

  final confirmar = await confirmarExclusao(
    context,
    titulo: 'Apagar ${modelo.nome}?',
    mensagem: 'Os ${modelo.tamanhos.length} itens deste modelo (tamanhos e cores) serão removidos do catálogo. '
        'Itens que já foram vendidos não podem ser apagados.',
  );
  if (!confirmar || !context.mounted) return false;

  var apagados = 0;
  for (final p in modelo.tamanhos) {
    try {
      await ApiService.instancia.excluirProduto(p.idProduto);
      apagados++;
    } on ApiException {
      // Tamanho com vendas: continua no catalogo.
    }
  }
  if (context.mounted) {
    final restantes = modelo.tamanhos.length - apagados;
    mostrarMensagem(
      context,
      restantes == 0
          ? 'Modelo apagado.'
          : apagados == 0
              ? 'Nenhum item foi apagado: todos já têm vendas.'
              : '$apagados item(ns) apagado(s); $restantes já têm vendas e continuam no catálogo.',
    );
  }
  return apagados == modelo.tamanhos.length;
}

/// Tela do modelo: foto, dados e os tamanhos com o estoque de cada um.
/// Gerencia e diretoria editam, dao entrada e adicionam tamanhos; a diretoria apaga.
/// Fecha devolvendo true quando algo mudou.
class ProdutoModeloScreen extends StatefulWidget {
  final String nome;

  const ProdutoModeloScreen({super.key, required this.nome});

  @override
  State<ProdutoModeloScreen> createState() => _ProdutoModeloScreenState();
}

class _ProdutoModeloScreenState extends State<ProdutoModeloScreen> {
  late Future<ModeloProduto?> _futuro = _carregar();
  bool _alterado = false;

  Future<ModeloProduto?> _carregar() async {
    final dados = await ApiService.instancia.produtos(busca: widget.nome);
    final chave = widget.nome.trim().toLowerCase();
    final tamanhos = dados.valor.where((p) => p.nome.trim().toLowerCase() == chave).toList();
    return tamanhos.isEmpty ? null : ModeloProduto(tamanhos.first.nome.trim(), tamanhos);
  }

  void _recarregar() {
    _alterado = true;
    setState(() => _futuro = _carregar());
  }

  Future<void> _tocarTamanho(Produto p) async {
    if (!ApiService.instancia.podeGerenciarEstoque) {
      await abrirFicha(context, p);
      return;
    }

    final acao = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Tamanho ${p.tamanho} · ${p.cor}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${p.estoque} peças em estoque'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar item'),
              onTap: () => Navigator.pop(contexto, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Registrar entrada de estoque'),
              onTap: () => Navigator.pop(contexto, 'entrada'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || acao == null) return;

    final mudou = acao == 'editar' ? await ProdutoFormScreen.abrir(context, produto: p) : await abrirFicha(context, p);
    if (mudou == true) _recarregar();
  }

  Future<void> _adicionarItem(ModeloProduto modelo) async {
    final mudou = await ProdutoFormScreen.abrir(context, modelo: modelo.principal);
    if (mudou == true) _recarregar();
  }

  Future<void> _apagarModelo(ModeloProduto modelo) async {
    final apagou = await apagarModelo(context, modelo);
    if (!mounted) return;
    if (apagou) {
      Navigator.of(context).pop(true);
    } else {
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) Navigator.of(context).pop(_alterado);
      },
      child: Scaffold(
        appBar: AppBar(),
        body: FutureBuilder<ModeloProduto?>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final modelo = snapshot.data;
            if (modelo == null) {
              return const Center(child: Text('Este produto não está mais no catálogo.'));
            }
            return _conteudo(modelo);
          },
        ),
      ),
    );
  }

  Widget _conteudo(ModeloProduto m) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final preco = m.menorPreco == m.maiorPreco
        ? formatarMoeda(m.menorPreco)
        : '${formatarMoeda(m.menorPreco)} a ${formatarMoeda(m.maiorPreco)}';
    final disponiveis = m.tamanhos.where((p) => p.estoque > 0).length;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _futuro = _carregar());
        await _futuro;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Center(child: FotoProduto(produto: m.principal, tamanho: 220)),
          const SizedBox(height: 16),
          Text(m.nome, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text([m.categoria, m.fornecedor].whereType<String>().join(' · '),
              style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(preco, style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          Text('Atacado (10% de desconto): ${formatarMoeda(m.menorPreco * 0.9)}${m.menorPreco == m.maiorPreco ? '' : ' em diante'}',
              style: textos.bodySmall),
          if (m.descricao != null) ...[
            const SizedBox(height: 12),
            Text(m.descricao!, style: textos.bodyLarge),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Itens', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
              Text('$disponiveis de ${m.tamanhos.length} com estoque · ${m.estoqueTotal} peças', style: textos.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, p) in m.tamanhos.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  ArrastarParaApagar(
                    chave: ValueKey('tamanho-${p.idProduto}'),
                    permitido: ApiService.instancia.podeExcluirProduto,
                    aoApagar: () => apagarProduto(context, p),
                    aoRemover: _recarregar,
                    child: _TamanhoTile(produto: p, mostrarPreco: m.menorPreco != m.maiorPreco, aoTocar: () => _tocarTamanho(p)),
                  ),
                ],
              ],
            ),
          ),
          if (ApiService.instancia.podeGerenciarEstoque) ...[
            const SizedBox(height: 8),
            BotaoNovo(texto: 'Adicionar item', aoTocar: () => _adicionarItem(m)),
          ],
          if (ApiService.instancia.podeExcluirProduto) ...[
            const SizedBox(height: 24),
            BotaoApagar(
              texto: m.tamanhos.length == 1 ? 'Apagar Produto' : 'Apagar Modelo (${m.tamanhos.length} itens)',
              aoTocar: () => _apagarModelo(m),
            ),
          ],
        ],
      ),
    );
  }
}

class _TamanhoTile extends StatelessWidget {
  final Produto produto;
  final bool mostrarPreco;
  final VoidCallback aoTocar;

  const _TamanhoTile({required this.produto, required this.mostrarPreco, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final p = produto;
    final esgotado = p.estoque == 0;
    final baixo = !esgotado && p.estoque <= limiteEstoqueBaixo;
    final situacao = esgotado ? 'Esgotado' : baixo ? 'Estoque baixo · ${p.estoque} peças' : '${p.estoque} peças';

    return ListTile(
      onTap: aoTocar,
      tileColor: cores.surface,
      // Com foto propria (ex.: outra cor), mostra a foto do item; sem foto, o tamanho.
      leading: p.fotoUrl != null
          ? FotoProduto(produto: p, tamanho: 44)
          : CircleAvatar(
              backgroundColor: esgotado ? cores.surfaceContainerHighest : cores.primaryContainer,
              foregroundColor: esgotado ? cores.onSurfaceVariant : cores.onPrimaryContainer,
              child: Text(p.tamanho, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
      title: Text('Tamanho ${p.tamanho} · ${p.cor}'),
      subtitle: Text(
        situacao + (p.codigoBarras == null ? '' : '\nCódigo ${p.codigoBarras}'),
        style: TextStyle(color: esgotado || baixo ? cores.error : null),
      ),
      isThreeLine: p.codigoBarras != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mostrarPreco) Text(formatarMoeda(p.preco)),
          const Icon(Icons.chevron_right),
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
    final cores = Theme.of(context).colorScheme;
    final grande = tamanho > 100;
    final semFoto = grande
        ? Container(
            width: tamanho,
            height: tamanho,
            decoration: BoxDecoration(color: cores.surfaceContainerHighest, borderRadius: BorderRadius.circular(tamanho / 8)),
            child: Icon(Icons.checkroom, size: tamanho / 3, color: cores.onSurfaceVariant),
          )
        : CircleAvatar(radius: tamanho / 2, child: Text(produto.tamanho));
    if (endereco == null) return semFoto;

    return ClipRRect(
      borderRadius: BorderRadius.circular(grande ? tamanho / 8 : tamanho / 4),
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

/// Abre a ficha de um tamanho por cima da tela (inclusive da barra inferior).
/// Devolve true quando o estoque mudou.
Future<bool?> abrirFicha(BuildContext context, Produto produto) => showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => FichaProduto(produto: produto),
    );

/// Ficha de um tamanho (aberta pelo leitor de codigo ou pela tela do modelo). Gerencia e
/// diretoria registram a entrada de mercadoria ali mesmo (a API executa a procedure
/// sp_RegistrarEntradaEstoque). Fecha devolvendo true quando o estoque foi alterado.
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
        observacao: 'Entrada pelo app',
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
