import 'package:flutter/cupertino.dart';
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

  /// Usado pelo painel: abre a lista ja filtrada pelos itens com estoque baixo.
  void mostrarEstoqueBaixo() {
    setState(
        () => _filtro = FiltroProdutos(disponibilidade: Disponibilidade.estoqueBaixo, ordenacao: _filtro.ordenacao));
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
    final escolhido = await abrirFolha<FiltroProdutos>(
      context,
      construir: (_, rolagem) => _FiltrosSheet(produtos: produtos, inicial: _filtro, rolagem: rolagem),
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
        return ListaAtualizavel(
          aoAtualizar: _atualizar,
          children: [
            CampoBusca(
              dica: 'Buscar produto ou código',
              texto: _busca,
              aoBuscar: (texto) {
                _busca = texto;
                _atualizar();
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ehIOS(context) ? 20 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: Botao.secundario(
                      'Ler código',
                      iconeMaterial: Icons.qr_code_scanner,
                      iconeIOS: CupertinoIcons.barcode_viewfinder,
                      aoTocar: _lerCodigo,
                    ),
                  ),
                  if (podeCadastrar) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Botao.principal(
                        'Novo produto',
                        iconeMaterial: Icons.add,
                        iconeIOS: CupertinoIcons.add,
                        aoTocar: dados.doCache ? null : _novoProduto,
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
              SecaoLista(
                rodape: _filtro.vazio ? null : 'Toque em Filtros para mudar a seleção.',
                children: [
                  ItemLista(titulo: _filtro.vazio ? 'Nenhum produto encontrado.' : 'Nenhum produto com esses filtros.'),
                ],
              ),
            SecaoLista(
              children: [
                for (final m in modelos)
                  ArrastarParaApagar(
                    chave: ValueKey('modelo-${m.nome}'),
                    permitido: !dados.doCache && ApiService.instancia.podeExcluirProduto,
                    aoApagar: () => apagarModelo(context, m),
                    aoRemover: () => setState(() => _apagados.addAll(m.tamanhos.map((p) => p.idProduto))),
                    child: _ModeloTile(modelo: m, aoTocar: () => _abrirModelo(m)),
                  ),
              ],
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
    final ios = ehIOS(context);
    final etiquetas = <Widget>[
      for (final c in filtro.categorias)
        _Etiqueta(c, () => aoMudar(filtro.copyWith(categorias: {...filtro.categorias}..remove(c)))),
      for (final f in filtro.fornecedores)
        _Etiqueta(f, () => aoMudar(filtro.copyWith(fornecedores: {...filtro.fornecedores}..remove(f)))),
      for (final t in filtro.tamanhos)
        _Etiqueta('Tam. $t', () => aoMudar(filtro.copyWith(tamanhos: {...filtro.tamanhos}..remove(t)))),
      for (final c in filtro.cores) _Etiqueta(c, () => aoMudar(filtro.copyWith(cores: {...filtro.cores}..remove(c)))),
      if (filtro.disponibilidade != Disponibilidade.todos)
        _Etiqueta(nomesDisponibilidade[filtro.disponibilidade]!,
            () => aoMudar(filtro.copyWith(disponibilidade: Disponibilidade.todos))),
      if (filtro.precoMinimo != null || filtro.precoMaximo != null)
        _Etiqueta('${formatarMoeda(filtro.precoMinimo ?? 0)} a ${formatarMoeda(filtro.precoMaximo ?? 0)}',
            () => aoMudar(filtro.copyWith(limparPreco: true))),
    ];
    final rotulo = filtro.vazio ? 'Filtros' : 'Filtros (${filtro.quantidade})';

    return Padding(
      padding: EdgeInsets.fromLTRB(ios ? 20 : 16, 8, ios ? 20 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ios
                  ? CupertinoButton.tinted(
                      sizeStyle: CupertinoButtonSize.small,
                      onPressed: aoAbrir,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(CupertinoIcons.slider_horizontal_3, size: 18),
                        const SizedBox(width: 6),
                        Text(rotulo),
                      ]),
                    )
                  : FilledButton.tonalIcon(onPressed: aoAbrir, icon: const Icon(Icons.tune), label: Text(rotulo)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$resultados ${resultados == 1 ? 'modelo' : 'modelos'} · ${nomesOrdenacao[filtro.ordenacao]}',
                  style: estiloLegenda(context),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (etiquetas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ...etiquetas,
              ios
                  ? CupertinoButton(
                      sizeStyle: CupertinoButtonSize.small,
                      onPressed: () => aoMudar(FiltroProdutos(ordenacao: filtro.ordenacao)),
                      child: const Text('Limpar'),
                    )
                  : TextButton(
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

/// Filtro escolhido: "pilula" com o x para remover (iPhone) ou chip do Material (Android).
class _Etiqueta extends StatelessWidget {
  final String texto;
  final VoidCallback aoRemover;

  const _Etiqueta(this.texto, this.aoRemover);

  @override
  Widget build(BuildContext context) {
    if (!ehIOS(context)) {
      return InputChip(label: Text(texto), onDeleted: aoRemover, deleteButtonTooltipMessage: 'Remover filtro $texto');
    }
    // Filtro escolhido: botao "tingido" pequeno do iOS com o x de remover.
    return Semantics(
      button: true,
      label: 'Remover filtro $texto',
      excludeSemantics: true,
      child: CupertinoButton.tinted(
        sizeStyle: CupertinoButtonSize.small,
        onPressed: aoRemover,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(texto),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.xmark_circle_fill, size: 16),
        ]),
      ),
    );
  }
}

/// Folha de filtros: ordenacao, tipo de produto, fornecedor, tamanho, cor, disponibilidade e
/// faixa de preco. No iPhone as opcoes sao listas com marcacao (como em Ajustes); no Android,
/// chips. Mostra quantos modelos vao aparecer antes de aplicar.
class _FiltrosSheet extends StatefulWidget {
  final List<Produto> produtos;
  final FiltroProdutos inicial;
  final ScrollController? rolagem;

  const _FiltrosSheet({required this.produtos, required this.inicial, this.rolagem});

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  late FiltroProdutos _f = widget.inicial;
  late final _opcoes = OpcoesFiltro.de(widget.produtos);

  Set<String> _alternar(Set<String> atual, String valor) =>
      atual.contains(valor) ? ({...atual}..remove(valor)) : {...atual, valor};

  /// Grupo de opcoes. [multipla]: varias podem ficar marcadas (tipo, tamanho...).
  Widget _grupo<T>(String titulo, Map<T, String> opcoes, bool Function(T) marcado, void Function(T) aoTocar) {
    if (opcoes.isEmpty) return const SizedBox.shrink();
    if (ehIOS(context)) {
      return SecaoLista(cabecalho: titulo, children: [
        for (final o in opcoes.entries)
          CupertinoListTile(
            title: Text(o.value),
            trailing: marcado(o.key) ? const Icon(CupertinoIcons.check_mark) : null,
            onTap: () => setState(() => aoTocar(o.key)),
          ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in opcoes.entries)
              FilterChip(
                label: Text(o.value),
                selected: marcado(o.key),
                onSelected: (_) => setState(() => aoTocar(o.key)),
              ),
          ]),
        ],
      ),
    );
  }

  Map<String, String> _mapa(List<String> valores, {String prefixo = ''}) => {for (final v in valores) v: '$prefixo$v'};

  /// Faixa de preco; a faixa inteira equivale a "sem filtro de preco".
  void _definirFaixa(double minimo, double maximo) {
    final inteira = minimo <= _opcoes.menorPreco && maximo >= _opcoes.maiorPreco;
    _f = inteira ? _f.copyWith(limparPreco: true) : _f.copyWith(precoMinimo: minimo, precoMaximo: maximo);
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _f.aplicar(widget.produtos).length;
    final faixa = _opcoes.maiorPreco > _opcoes.menorPreco;
    final minimo = (_f.precoMinimo ?? _opcoes.menorPreco).clamp(_opcoes.menorPreco, _opcoes.maiorPreco).toDouble();
    final maximo = (_f.precoMaximo ?? _opcoes.maiorPreco).clamp(minimo, _opcoes.maiorPreco).toDouble();

    return Folha(
      titulo: 'Filtros',
      fechar: 'Cancelar',
      rolagem: widget.rolagem,
      acao: BotaoTopo(rotulo: 'Limpar', aoTocar: () => setState(() => _f = FiltroProdutos(ordenacao: _f.ordenacao))),
      rodape: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Botao.principal(
          'Mostrar $resultado ${resultado == 1 ? 'modelo' : 'modelos'}',
          aoTocar: () => Navigator.of(context).pop(_f),
        ),
      ),
      children: [
        _grupo<Ordenacao>(
            'Ordenar por', nomesOrdenacao, (o) => _f.ordenacao == o, (o) => _f = _f.copyWith(ordenacao: o)),
        _grupo<String>('Tipo de produto', _mapa(_opcoes.categorias), _f.categorias.contains,
            (o) => _f = _f.copyWith(categorias: _alternar(_f.categorias, o))),
        _grupo<String>('Fornecedor', _mapa(_opcoes.fornecedores), _f.fornecedores.contains,
            (o) => _f = _f.copyWith(fornecedores: _alternar(_f.fornecedores, o))),
        _grupo<String>('Tamanho', _mapa(_opcoes.tamanhos), _f.tamanhos.contains,
            (o) => _f = _f.copyWith(tamanhos: _alternar(_f.tamanhos, o))),
        _grupo<String>(
            'Cor', _mapa(_opcoes.cores), _f.cores.contains, (o) => _f = _f.copyWith(cores: _alternar(_f.cores, o))),
        _grupo<Disponibilidade>('Disponibilidade', nomesDisponibilidade, (d) => _f.disponibilidade == d,
            (d) => _f = _f.copyWith(disponibilidade: d)),
        if (faixa)
          SecaoLista(
            cabecalho: 'Preço',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatarMoeda(minimo)} a ${formatarMoeda(maximo)}'),
                    // iPhone: o iOS nao tem controle de faixa; usa dois controles deslizantes do
                    // iOS (minimo e maximo). Android: controle de faixa do Material.
                    if (ehIOS(context)) ...[
                      _LinhaPreco(
                        rotulo: 'Mínimo',
                        valor: minimo,
                        min: _opcoes.menorPreco,
                        max: _opcoes.maiorPreco,
                        aoMudar: (v) => setState(() => _definirFaixa(v, maximo < v ? v : maximo)),
                      ),
                      _LinhaPreco(
                        rotulo: 'Máximo',
                        valor: maximo,
                        min: _opcoes.menorPreco,
                        max: _opcoes.maiorPreco,
                        aoMudar: (v) => setState(() => _definirFaixa(minimo > v ? v : minimo, v)),
                      ),
                    ] else
                      RangeSlider(
                        min: _opcoes.menorPreco,
                        max: _opcoes.maiorPreco,
                        values: RangeValues(minimo, maximo),
                        labels: RangeLabels(formatarMoeda(minimo), formatarMoeda(maximo)),
                        onChanged: (v) => setState(() => _definirFaixa(v.start, v.end)),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Controle deslizante do iOS com rotulo e valor (filtro de preco no iPhone).
class _LinhaPreco extends StatelessWidget {
  final String rotulo;
  final double valor;
  final double min;
  final double max;
  final ValueChanged<double> aoMudar;

  const _LinhaPreco({required this.rotulo, required this.valor, required this.min, required this.max, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(rotulo, style: estiloLegenda(context))),
        Expanded(child: CupertinoSlider(value: valor, min: min, max: max, onChanged: aoMudar)),
        SizedBox(width: 92, child: Text(formatarMoeda(valor), textAlign: TextAlign.end)),
      ],
    );
  }
}

/// Um modelo na lista: foto (ou sigla), nome, tipo, tamanhos, estoque e preco.
class _ModeloTile extends StatelessWidget {
  final ModeloProduto modelo;
  final VoidCallback aoTocar;

  const _ModeloTile({required this.modelo, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final m = modelo;
    final grade = m.tamanhos.map((p) => p.tamanho).toSet().toList();
    final tamanhos = grade.length == 1 ? grade.first : '${grade.first} a ${grade.last}';
    final cores = m.cores.length > 1 ? ' · ${m.cores.length} cores' : '';
    final preco = formatarMoeda(m.menorPreco);

    return Semantics(
      label: '${m.nome}, ${m.menorPreco == m.maiorPreco ? preco : 'a partir de $preco'}, tamanhos $tamanhos, '
          '${m.estoqueTotal} peças em estoque',
      excludeSemantics: true,
      button: true,
      child: ItemLista(
        inicio: FotoProduto(produto: m.principal, tamanho: 40),
        titulo: m.nome,
        subtitulo: 'Tam. $tamanhos$cores · ${m.estoqueTotal} peças',
        valor: preco,
        seta: true,
        aoTocar: aoTocar,
      ),
    );
  }
}

/// Pergunta e apaga todos os itens de um modelo (somente diretoria). A API recusa os
/// itens que ja foram vendidos; o aviso diz quantos ficaram.
Future<bool> apagarModelo(BuildContext context, ModeloProduto modelo) async {
  if (modelo.tamanhos.length == 1) return apagarProduto(context, modelo.tamanhos.first);

  final confirmou = await confirmarExclusao(
    context,
    titulo: 'Apagar ${modelo.nome}?',
    mensagem: 'Os ${modelo.tamanhos.length} itens deste modelo (tamanhos e cores) serão removidos do catálogo. '
        'Itens que já foram vendidos não podem ser apagados.',
  );
  if (!confirmou || !context.mounted) return false;

  var apagados = 0;
  for (final p in modelo.tamanhos) {
    try {
      await ApiService.instancia.excluirProduto(p.idProduto);
      apagados++;
    } on ApiException {
      // Item com vendas: continua no catalogo.
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

/// Tela do modelo: foto, dados e os itens (tamanho e cor) com o estoque de cada um.
/// Gerencia e diretoria editam, dao entrada e adicionam itens; a diretoria apaga.
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
    setState(() { _futuro = _carregar(); });
  }

  Future<void> _tocarItem(Produto p) async {
    if (!ApiService.instancia.podeGerenciarEstoque) {
      await abrirFicha(context, p);
      return;
    }

    final acao = await escolherAcao<String>(
      context,
      titulo: 'Tamanho ${p.tamanho} · ${p.cor}',
      mensagem: '${p.estoque} peças em estoque',
      opcoes: const [
        OpcaoAcao('editar', 'Editar item', Icons.edit_outlined),
        OpcaoAcao('entrada', 'Registrar entrada de estoque', Icons.add_box_outlined),
      ],
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
      child: Pagina(
        titulo: widget.nome,
        corpo: FutureBuilder<ModeloProduto?>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
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
    final ios = ehIOS(context);
    final preco = m.menorPreco == m.maiorPreco
        ? formatarMoeda(m.menorPreco)
        : '${formatarMoeda(m.menorPreco)} a ${formatarMoeda(m.maiorPreco)}';
    final disponiveis = m.tamanhos.where((p) => p.estoque > 0).length;

    return ListaAtualizavel(
      aoAtualizar: () async {
        setState(() { _futuro = _carregar(); });
        await _futuro;
      },
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 8),
        Center(child: FotoProduto(produto: m.principal, tamanho: 140)),
        const SizedBox(height: 12),
        Text(m.nome, textAlign: TextAlign.center, style: estiloTituloGrande(context)),
        Text([m.categoria, m.fornecedor].whereType<String>().join(' · '),
            textAlign: TextAlign.center, style: estiloSecundario(context)),
        SecaoLista(children: [
          ItemLista(titulo: 'Preço', valor: preco),
          ItemLista(
            titulo: 'Atacado (10% de desconto)',
            valor: '${formatarMoeda(m.menorPreco * 0.9)}${m.menorPreco == m.maiorPreco ? '' : '+'}',
          ),
          if (m.descricao != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(m.descricao!, style: estiloSecundario(context))),
        ]),
        SecaoLista(
          cabecalho: 'Itens',
          rodape: '$disponiveis de ${m.tamanhos.length} com estoque · ${m.estoqueTotal} peças',
          children: [
            for (final p in m.tamanhos)
              ArrastarParaApagar(
                chave: ValueKey('item-${p.idProduto}'),
                permitido: ApiService.instancia.podeExcluirProduto,
                aoApagar: () => apagarProduto(context, p),
                aoRemover: _recarregar,
                child: _ItemTile(produto: p, mostrarPreco: m.menorPreco != m.maiorPreco, aoTocar: () => _tocarItem(p)),
              ),
          ],
        ),
        if (ApiService.instancia.podeGerenciarEstoque)
          BotaoNovo(texto: 'Adicionar item', aoTocar: () => _adicionarItem(m)),
        if (ApiService.instancia.podeExcluirProduto) ...[
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ios ? 0 : 16),
            child: BotaoApagar(
              texto: m.tamanhos.length == 1 ? 'Apagar Produto' : 'Apagar Modelo (${m.tamanhos.length} itens)',
              aoTocar: () => _apagarModelo(m),
            ),
          ),
        ],
      ],
    );
  }
}

/// Um item do modelo: o tamanho num circulo (ou a foto propria do item, ex.: outra cor),
/// cor e situacao do estoque.
class _ItemTile extends StatelessWidget {
  final Produto produto;
  final bool mostrarPreco;
  final VoidCallback aoTocar;

  const _ItemTile({required this.produto, required this.mostrarPreco, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final p = produto;
    final esgotado = p.estoque == 0;
    final baixo = !esgotado && p.estoque <= limiteEstoqueBaixo;
    final situacao = esgotado
        ? 'Esgotado'
        : baixo
            ? 'Estoque baixo · ${p.estoque} peças'
            : '${p.estoque} peças';

    return ItemLista(
      inicio: p.fotoUrl != null ? FotoProduto(produto: p, tamanho: 40) : Avatar(p.tamanho, apagado: esgotado),
      titulo: 'Tamanho ${p.tamanho} · ${p.cor}',
      subtitulo: situacao + (p.codigoBarras == null ? '' : ' · ${p.codigoBarras}'),
      corSubtitulo: esgotado || baixo ? corVermelha(context) : null,
      valor: mostrarPreco ? formatarMoeda(p.preco) : null,
      seta: true,
      aoTocar: aoTocar,
    );
  }
}

/// Foto do produto, redonda; sem foto (ou sem rede), a sigla do produto (ex.: "CF").
class FotoProduto extends StatelessWidget {
  final Produto produto;
  final double tamanho;

  const FotoProduto({super.key, required this.produto, this.tamanho = 40});

  @override
  Widget build(BuildContext context) {
    final endereco = produto.enderecoFoto(apiBaseUrl);
    final semFoto = Semantics(label: produto.nome, child: Avatar(siglaProduto(produto.nome), tamanho: tamanho));
    if (endereco == null) return semFoto;

    return ClipOval(
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

/// Abre a ficha de um item por cima da tela (inclusive da barra inferior).
/// Devolve true quando o estoque mudou.
Future<bool?> abrirFicha(BuildContext context, Produto produto) =>
    abrirFolha<bool>(context, construir: (_, rolagem) => FichaProduto(produto: produto, rolagem: rolagem));

/// Ficha de um item (aberta pelo leitor de codigo ou pela tela do modelo). Gerencia e
/// diretoria registram a entrada de mercadoria ali mesmo (a API executa a procedure
/// sp_RegistrarEntradaEstoque). Fecha devolvendo true quando o estoque foi alterado.
class FichaProduto extends StatefulWidget {
  final Produto produto;
  final ScrollController? rolagem;

  const FichaProduto({super.key, required this.produto, this.rolagem});

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
    final ios = ehIOS(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) Navigator.of(context).pop(_alterado);
      },
      child: Folha(
        titulo: 'Item',
        rolagem: widget.rolagem,
        aoFechar: () => Navigator.of(context).pop(_alterado),
        children: [
          const SizedBox(height: 8),
          Center(child: FotoProduto(produto: p, tamanho: 88)),
          const SizedBox(height: 8),
          Text(p.nome, textAlign: TextAlign.center, style: estiloTitulo(context)),
          Text('Tamanho ${p.tamanho} · ${p.cor}', textAlign: TextAlign.center, style: estiloSecundario(context)),
          SecaoLista(children: [
            ItemLista(titulo: 'Preço', valor: formatarMoeda(p.preco)),
            ItemLista(titulo: 'Estoque', valor: '$_estoque peças'),
            ItemLista(titulo: 'Código de barras', valor: p.codigoBarras ?? '-'),
            if (p.categoria != null) ItemLista(titulo: 'Tipo', valor: p.categoria),
          ]),
          if (ApiService.instancia.podeGerenciarEstoque) ...[
            SecaoFormulario(
              cabecalho: 'Entrada de mercadoria',
              children: [
                CampoTexto(controle: _quantidade, rotulo: 'Quantidade', teclado: TextInputType.number),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ios ? 20 : 16, vertical: 4),
              child: Botao.principal(
                'Registrar entrada',
                iconeMaterial: Icons.add_box_outlined,
                iconeIOS: CupertinoIcons.plus_rectangle_on_rectangle,
                carregando: _enviando,
                aoTocar: _registrarEntrada,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
