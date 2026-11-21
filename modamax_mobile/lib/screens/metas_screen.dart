import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/aneis.dart';
import '../widgets/comum.dart';

/// Metas e resultados de qualquer mes: aneis, comparacao com o mes anterior, faturamento por
/// dia, mais vendidos e historico. A diretoria tambem define as metas por aqui.
class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  static final _primeiroMes = DateTime(2020, 1);
  final _hoje = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _mes = _hoje;
  late Future<Dados<MetaMes>> _futuro = _carregar();
  late Future<Dados<List<ResumoMes>>> _historico = ApiService.instancia.historicoMetas();

  Future<Dados<MetaMes>> _carregar() => ApiService.instancia.metaDoMes(_mes.year, _mes.month);

  // Ate 12 meses a frente (para planejar) e de volta ate o inicio dos registros.
  bool get _podeAvancar => _mes.isBefore(DateTime(_hoje.year, _hoje.month + 12));
  bool get _podeVoltar => _mes.isAfter(_primeiroMes);

  void _irPara(DateTime mes) => setState(() {
        _mes = DateTime(mes.year, mes.month);
        _futuro = _carregar();
      });

  Future<void> _atualizar() async {
    setState(() {
      _futuro = _carregar();
      _historico = ApiService.instancia.historicoMetas();
    });
    try {
      await Future.wait([_futuro, _historico]);
    } on ApiException {
      // O erro ja aparece na tela.
    }
  }

  Future<void> _editar(MetaMes meta) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditarMetaScreen(meta: meta)),
    );
    if (salvou != true || !mounted) return;
    mostrarMensagem(context, 'Meta de ${meta.nomeMes} salva.');
    await _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: 'Metas',
      corpo: Column(
        children: [
          _SeletorMes(
            mes: _mes,
            aoVoltar: _podeVoltar ? () => _irPara(DateTime(_mes.year, _mes.month - 1)) : null,
            aoAvancar: _podeAvancar ? () => _irPara(DateTime(_mes.year, _mes.month + 1)) : null,
            aoHoje: _mes == _hoje ? null : () => _irPara(_hoje),
          ),
          Expanded(
            child: CarregarDados<MetaMes>(
              futuro: _futuro,
              aoAtualizar: _atualizar,
              construir: (dados) => ListaAtualizavel(
                aoAtualizar: _atualizar,
                children: [
                  if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
                  _CartaoAneis(meta: dados.valor, aoEditar: () => _editar(dados.valor)),
                  if (!dados.valor.futuro) _Resultados(meta: dados.valor),
                  if (!dados.valor.futuro) Cartao(child: _GraficoDiario(meta: dados.valor)),
                  if (dados.valor.maisVendidos.isNotEmpty) _MaisVendidos(meta: dados.valor),
                  FutureBuilder<Dados<List<ResumoMes>>>(
                    future: _historico,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.valor.isEmpty) return const SizedBox.shrink();
                      return _Historico(meses: snapshot.data!.valor, selecionado: _mes, aoEscolher: _irPara);
                    },
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

// ---------------------------------------------------------------------------------------------
// Partes da tela

const _nomesMeses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String _nomeMes(DateTime mes) => '${_nomesMeses[mes.month - 1]} de ${mes.year}';

/// "Novembro de 2026" -> "novembro"
String _mesMinusculo(String nomeMes) => nomeMes.split(' ').first.toLowerCase();

/// Barra com o mes escolhido e setas para o anterior e o proximo.
class _SeletorMes extends StatelessWidget {
  final DateTime mes;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoAvancar;
  final VoidCallback? aoHoje;

  const _SeletorMes({required this.mes, required this.aoVoltar, required this.aoAvancar, required this.aoHoje});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime(DateTime.now().year, DateTime.now().month);
    final situacao = mes == agora ? 'Mês atual' : (mes.isBefore(agora) ? 'Mês encerrado' : 'Planejamento');
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          BotaoIcone(
            iconeMaterial: Icons.chevron_left,
            iconeIOS: CupertinoIcons.chevron_left,
            dica: 'Mês anterior',
            aoTocar: aoVoltar,
          ),
          Expanded(
            child: Column(
              children: [
                Text(_nomeMes(mes), style: estiloSubtitulo(context).copyWith(fontWeight: FontWeight.w700)),
                GestureDetector(
                  onTap: aoHoje,
                  child: Text(
                    aoHoje == null ? situacao : '$situacao · voltar para hoje',
                    style: estiloLegenda(context).copyWith(color: aoHoje == null ? null : corDestaque(context)),
                  ),
                ),
              ],
            ),
          ),
          BotaoIcone(
            iconeMaterial: Icons.chevron_right,
            iconeIOS: CupertinoIcons.chevron_right,
            dica: 'Próximo mês',
            aoTocar: aoAvancar,
          ),
        ],
      ),
    );
  }
}

/// Aneis do mes, situacao em uma frase e o botao de editar (diretoria).
class _CartaoAneis extends StatelessWidget {
  final MetaMes meta;
  final VoidCallback aoEditar;

  const _CartaoAneis({required this.meta, required this.aoEditar});

  @override
  Widget build(BuildContext context) {
    final f = meta.faturamento;
    final bateu = f.meta > 0 && f.realizado >= f.meta;
    final (String frase, Color? cor) = switch (meta.situacao) {
      _ when f.meta <= 0 && !meta.futuro => (
          'Não havia meta para este mês nem vendas suficientes nos meses anteriores para sugerir uma.',
          null
        ),
      'futuro' => ('O mês ainda não começou. Defina a meta com antecedência para orientar a equipe.', null),
      'encerrado' => bateu
          ? ('Meta de faturamento batida: ${f.percentualExibido}% do objetivo.', corVerde(context))
          : ('Faltaram ${formatarMoeda(f.meta - f.realizado)} para a meta de faturamento.', corLaranja(context)),
      _ => bateu
          ? ('Meta de faturamento batida! Tudo o que vier agora é lucro extra.', corVerde(context))
          : (meta.projecaoFaturamento >= f.meta
              ? (
                  'No ritmo atual, o mês fecha em ${formatarMoeda(meta.projecaoFaturamento)}: a meta será batida.',
                  corVerde(context)
                )
              : (
                  'No ritmo atual, o mês fecha em ${formatarMoeda(meta.projecaoFaturamento)}. '
                      'É preciso vender ${formatarMoeda(meta.necessarioPorDia)} por dia nos ${meta.diasRestantes} dias restantes.',
                  corLaranja(context)
                )),
    };

    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Metas do mês', style: estiloSubtitulo(context))),
              _Etiqueta(
                meta.definida ? 'Meta definida' : 'Meta sugerida',
                cor: meta.definida ? corAzul(context) : corCinza(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AneisMeta(meta: meta.comoMetaAtual),
          const SizedBox(height: 12),
          Text(frase, style: estiloCorpo(context).copyWith(fontSize: 15, color: cor)),
          if (!meta.definida) ...[
            const SizedBox(height: 6),
            Text(
              'Sem meta cadastrada: os valores são a média dos 3 meses anteriores com 10% de crescimento.',
              style: estiloLegenda(context),
            ),
          ],
          if (meta.podeEditar) ...[
            const SizedBox(height: 14),
            Botao.secundario(
              meta.definida ? 'Editar metas' : 'Definir metas',
              iconeMaterial: Icons.edit_outlined,
              iconeIOS: CupertinoIcons.pencil,
              aoTocar: aoEditar,
            ),
          ],
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;

  const _Etiqueta(this.texto, {required this.cor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: estiloLegenda(context).copyWith(color: cor, fontWeight: FontWeight.w600)),
      );
}

/// Faturamento, pedidos, pecas e ticket medio, comparados com o mes anterior.
class _Resultados extends StatelessWidget {
  final MetaMes meta;

  const _Resultados({required this.meta});

  @override
  Widget build(BuildContext context) {
    final ant = meta.mesAnterior;
    final nomeAnterior = _mesMinusculo(ant.nomeMes);

    // Mes encerrado: variacao em relacao ao anterior. Mes atual (incompleto): mostra o valor do
    // mes anterior inteiro, sem percentual, para nao comparar meio mes com um mes fechado.
    String? comparar(double atual, double anterior, String Function(double) formatar) {
      if (meta.atual) return '$nomeAnterior inteiro: ${formatar(anterior)}';
      if (anterior <= 0) return null;
      final variacao = ((atual - anterior) / anterior * 100).round();
      if (variacao == 0) return 'igual a $nomeAnterior';
      return '${variacao > 0 ? '▲' : '▼'} ${variacao.abs()}% em relação a $nomeAnterior';
    }

    Color? cor(double atual, double anterior) => meta.atual || anterior <= 0 || atual == anterior
        ? null
        : (atual > anterior ? corVerde(context) : corVermelha(context));

    String inteiro(double v) => v.toStringAsFixed(0);
    final linhas = [
      (
        'Faturamento',
        meta.faturamento.realizado,
        ant.faturamento,
        formatarMoeda,
        Icons.payments_outlined,
        CupertinoIcons.money_dollar_circle,
        corVerde(context)
      ),
      (
        'Pedidos',
        meta.pedidos.realizado,
        ant.pedidos.toDouble(),
        inteiro,
        Icons.receipt_long_outlined,
        CupertinoIcons.doc_text,
        corAzul(context)
      ),
      (
        'Peças vendidas',
        meta.pecas.realizado,
        ant.pecas.toDouble(),
        inteiro,
        Icons.checkroom_outlined,
        CupertinoIcons.bag,
        corIndigo(context)
      ),
      (
        'Ticket médio',
        meta.ticketMedio,
        ant.ticketMedio,
        formatarMoeda,
        Icons.sell_outlined,
        CupertinoIcons.tag,
        corTeal(context)
      ),
    ];

    return SecaoLista(
      cabecalho: 'Resultados do mês',
      children: [
        for (final l in linhas)
          ItemLista(
            inicio: Icon(icone(context, material: l.$5, ios: l.$6), color: l.$7),
            titulo: l.$1,
            subtitulo: comparar(l.$2, l.$3, l.$4),
            corSubtitulo: cor(l.$2, l.$3),
            valor: l.$4(l.$2),
          ),
        if (meta.atual) ...[
          ItemLista(
            inicio: Icon(icone(context, material: Icons.trending_up, ios: CupertinoIcons.graph_square),
                color: corLaranja(context)),
            titulo: 'Projeção do mês',
            subtitulo: 'Pelo ritmo de ${meta.diasDecorridos} de ${meta.diasNoMes} dias',
            valor: formatarMoeda(meta.projecaoFaturamento),
          ),
          if (meta.necessarioPorDia > 0)
            ItemLista(
              inicio: Icon(icone(context, material: Icons.flag_outlined, ios: CupertinoIcons.flag),
                  color: corVermelha(context)),
              titulo: 'Necessário por dia',
              subtitulo: '${meta.diasRestantes} dias restantes',
              valor: formatarMoeda(meta.necessarioPorDia),
            ),
        ],
      ],
    );
  }
}

/// Barras do faturamento de cada dia, com a linha da meta diaria (meta / dias do mes).
class _GraficoDiario extends StatelessWidget {
  final MetaMes meta;

  const _GraficoDiario({required this.meta});

  @override
  Widget build(BuildContext context) {
    final pontos = meta.faturamentoPorDia;
    final metaDiaria = meta.diasNoMes == 0 ? 0.0 : meta.faturamento.meta / meta.diasNoMes;
    final maior = pontos.fold<double>(metaDiaria, (m, p) => p.valor > m ? p.valor : m);
    final teto = maior <= 0 ? 1.0 : maior * 1.1;
    final diasBatidos = pontos.where((p) => p.valor >= metaDiaria && p.valor > 0).length;
    final melhor = pontos.isEmpty ? null : pontos.reduce((a, b) => b.valor > a.valor ? b : a);
    const altura = 150.0;
    final destaque = corDestaque(context);
    final verde = corVerde(context);
    final trilho = corTrilho(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Faturamento por dia', style: estiloSubtitulo(context)),
        const SizedBox(height: 4),
        Text(
          'Linha tracejada: meta diária de ${formatarMoeda(metaDiaria)}. Barras verdes bateram a meta do dia.',
          style: estiloLegenda(context),
        ),
        const SizedBox(height: 14),
        Semantics(
          label: 'Faturamento por dia de ${meta.nomeMes}. $diasBatidos dias acima da meta diária.'
              '${melhor != null && melhor.valor > 0 ? ' Melhor dia: ${melhor.rotulo}, ${formatarMoeda(melhor.valor)}.' : ''}',
          excludeSemantics: true,
          child: SizedBox(
            height: altura,
            child: Stack(
              children: [
                // Preenche a altura toda: sem isso a linha de barras fica no topo e sai da escala.
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final p in pontos)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              height: p.valor <= 0 ? 2 : (p.valor / teto * altura).clamp(3.0, altura),
                              decoration: BoxDecoration(
                                color: p.valor <= 0 ? trilho : (p.valor >= metaDiaria ? verde : destaque),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (metaDiaria > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: metaDiaria / teto * altura,
                    child: CustomPaint(size: const Size(double.infinity, 1), painter: _Tracejado(corCinza(context))),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final dia in [1, 10, 20, meta.diasNoMes]) Text('$dia', style: estiloLegenda(context)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          melhor == null || melhor.valor <= 0
              ? 'Nenhuma venda registrada neste mês.'
              : 'Melhor dia: ${melhor.rotulo}, com ${formatarMoeda(melhor.valor)} · $diasBatidos '
                  '${diasBatidos == 1 ? 'dia' : 'dias'} acima da meta diária',
          style: estiloSecundario(context),
        ),
      ],
    );
  }
}

class _Tracejado extends CustomPainter {
  final Color cor;

  _Tracejado(this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = cor
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _Tracejado antigo) => antigo.cor != cor;
}

class _MaisVendidos extends StatelessWidget {
  final MetaMes meta;

  const _MaisVendidos({required this.meta});

  @override
  Widget build(BuildContext context) => SecaoLista(
        cabecalho: 'Mais vendidos do mês',
        children: [
          for (final (i, p) in meta.maisVendidos.indexed)
            ItemLista(
              inicio: Avatar('${i + 1}º', tamanho: 34),
              titulo: p.produto,
              subtitulo: '${p.pecas} ${p.pecas == 1 ? 'peça' : 'peças'}',
              valor: formatarMoeda(p.valor),
            ),
        ],
      );
}

/// Ultimos 12 meses: grafico do percentual da meta batido e a lista (toque abre o mes).
class _Historico extends StatelessWidget {
  final List<ResumoMes> meses;
  final DateTime selecionado;
  final ValueChanged<DateTime> aoEscolher;

  const _Historico({required this.meses, required this.selecionado, required this.aoEscolher});

  @override
  Widget build(BuildContext context) {
    const altura = 110.0;
    const tetoPercentual = 150.0;
    final comMeta = meses.where((m) => m.metaFaturamento > 0).toList();
    final batidos = comMeta.where((m) => m.percentualExibido >= 100).length;
    final cinza = corCinza(context);
    final verde = corVerde(context);
    final laranja = corLaranja(context);

    Color corDo(ResumoMes m) => m.metaFaturamento <= 0 ? cinza : (m.percentualExibido >= 100 ? verde : laranja);

    return Column(
      children: [
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Últimos ${meses.length} meses', style: estiloSubtitulo(context)),
              const SizedBox(height: 4),
              Text(
                  comMeta.isEmpty
                      ? 'Nenhum mês com meta ainda. Toque em um mês para ver os detalhes.'
                      : 'Meta de faturamento batida em $batidos de ${comMeta.length} '
                          '${comMeta.length == 1 ? 'mês' : 'meses'} com meta. Toque em um mês para ver os detalhes.',
                  style: estiloLegenda(context)),
              const SizedBox(height: 14),
              SizedBox(
                height: altura + 18,
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final m in meses)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: m.metaFaturamento <= 0
                                  ? '${m.nomeMes}: sem meta'
                                  : '${m.nomeMes}: ${m.percentualExibido}% da meta',
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => aoEscolher(DateTime(m.ano, m.mes)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      height: (m.percentualExibido.clamp(0, tetoPercentual) / tetoPercentual * altura)
                                          .clamp(3.0, altura),
                                      decoration: BoxDecoration(
                                        color: corDo(m)
                                            .withValues(alpha: DateTime(m.ano, m.mes) == selecionado ? 1 : 0.75),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        border: DateTime(m.ano, m.mes) == selecionado
                                            ? Border.all(color: corDestaque(context), width: 2)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(m.nomeMes.substring(0, 3),
                                        style: estiloLegenda(context).copyWith(fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18 + 100 / tetoPercentual * altura,
                      child: CustomPaint(size: const Size(double.infinity, 1), painter: _Tracejado(corCinza(context))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SecaoLista(
          cabecalho: 'Histórico',
          children: [
            for (final m in meses.reversed)
              ItemLista(
                titulo: m.nomeMes,
                subtitulo: m.metaFaturamento <= 0
                    ? '${formatarMoeda(m.faturamento)} vendidos'
                    : '${formatarMoeda(m.faturamento)} de ${formatarMoeda(m.metaFaturamento)}'
                        '${m.definida ? '' : ' (sugerida)'}',
                fim: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Etiqueta(m.metaFaturamento <= 0 ? 'Sem meta' : '${m.percentualExibido}%', cor: corDo(m)),
                    if (ehIOS(context)) const CupertinoListTileChevron(),
                  ],
                ),
                aoTocar: () => aoEscolher(DateTime(m.ano, m.mes)),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Edicao (diretoria)

/// Define as metas de faturamento, pedidos e pecas do mes, com a opcao de usar a sugestao.
class EditarMetaScreen extends StatefulWidget {
  final MetaMes meta;

  const EditarMetaScreen({super.key, required this.meta});

  @override
  State<EditarMetaScreen> createState() => _EditarMetaScreenState();
}

class _EditarMetaScreenState extends State<EditarMetaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _faturamento = TextEditingController(text: _moeda(widget.meta.valores.faturamento));
  late final _pedidos = TextEditingController(text: '${widget.meta.valores.pedidos}');
  late final _pecas = TextEditingController(text: '${widget.meta.valores.pecas}');
  bool _salvando = false;

  static String _moeda(double v) => formatarMoeda(v).replaceFirst('R\$ ', '');

  @override
  void dispose() {
    for (final c in [_faturamento, _pedidos, _pecas]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? lerValor(String texto) => EditarMetaScreenLeitor.ler(texto);

  void _usarSugestao() {
    final s = widget.meta.sugestao;
    setState(() {
      _faturamento.text = _moeda(s.faturamento);
      _pedidos.text = '${s.pedidos}';
      _pecas.text = '${s.pecas}';
    });
    _formKey.currentState?.validate();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ApiService.instancia.salvarMeta(
        widget.meta.ano,
        widget.meta.mes,
        ValoresMeta(
          faturamento: lerValor(_faturamento.text)!,
          pedidos: int.parse(_pedidos.text.trim()),
          pecas: int.parse(_pecas.text.trim()),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String? _validarValor(String t) {
    final v = lerValor(t);
    if (v == null || v <= 0) return 'Informe um valor maior que zero.';
    if (v > 99999999) return 'Valor alto demais.';
    return null;
  }

  String? _validarInteiro(String t) {
    final v = int.tryParse(t.trim());
    if (v == null || v <= 0) return 'Informe um número inteiro maior que zero.';
    if (v > 100000) return 'Número alto demais.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ios = ehIOS(context);
    final m = widget.meta;
    final s = m.sugestao;
    return Pagina(
      titulo: 'Meta de ${_mesMinusculo(m.nomeMes)}',
      acoes: ios ? [BotaoTopo(rotulo: 'Salvar', aoTocar: _salvando ? null : _salvar)] : const [],
      corpo: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SecaoFormulario(
              cabecalho: m.nomeMes,
              rodape: 'A meta orienta os anéis do painel, a projeção e o valor necessário por dia.',
              children: [
                CampoTexto(
                  controle: _faturamento,
                  rotulo: 'Faturamento',
                  larguraRotulo: 120,
                  dica: 'R\$ 0,00',
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  validar: _validarValor,
                ),
                CampoTexto(
                    controle: _pedidos,
                    rotulo: 'Pedidos',
                    larguraRotulo: 120,
                    teclado: TextInputType.number,
                    validar: _validarInteiro),
                CampoTexto(
                    controle: _pecas,
                    rotulo: 'Peças',
                    larguraRotulo: 120,
                    teclado: TextInputType.number,
                    validar: _validarInteiro),
              ],
            ),
            SecaoLista(
              cabecalho: 'Sugestão',
              rodape: 'Média dos 3 meses anteriores com 10% de crescimento.',
              children: [
                ItemLista(titulo: 'Faturamento', valor: formatarMoeda(s.faturamento)),
                ItemLista(titulo: 'Pedidos', valor: '${s.pedidos}'),
                ItemLista(titulo: 'Peças', valor: '${s.pecas}'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  Botao.secundario('Usar a sugestão',
                      iconeMaterial: Icons.auto_awesome_outlined,
                      iconeIOS: CupertinoIcons.wand_stars,
                      aoTocar: _usarSugestao),
                  if (!ios) ...[
                    const SizedBox(height: 12),
                    Botao.principal('Salvar metas', carregando: _salvando, aoTocar: _salvar),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leitura de valores em reais digitados: "12.500,00", "12500,5", "12500" ou "R$ 12.500".
abstract final class EditarMetaScreenLeitor {
  static double? ler(String texto) {
    var t = texto.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', '');
    }
    return double.tryParse(t);
  }
}
