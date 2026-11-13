import 'models.dart';

/// Na API cada tamanho e um produto proprio (tem codigo de barras e estoque proprios).
/// No app, os tamanhos do mesmo modelo aparecem juntos: "Calca Flare de Lantejoulas"
/// vira um item so, e os tamanhos ficam dentro da tela do produto.
class ModeloProduto {
  final String nome;
  final List<Produto> tamanhos;

  ModeloProduto(this.nome, List<Produto> tamanhos) : tamanhos = ordenarPorTamanho(tamanhos);

  Produto get principal => tamanhos.firstWhere((p) => p.fotoUrl != null, orElse: () => tamanhos.first);
  String? get categoria => principal.categoria;
  String? get fornecedor => principal.fornecedor;
  String? get descricao => tamanhos.map((p) => p.descricao).firstWhere((d) => d != null && d.isNotEmpty, orElse: () => null);
  int get estoqueTotal => tamanhos.fold(0, (soma, p) => soma + p.estoque);
  double get menorPreco => tamanhos.map((p) => p.preco).reduce((a, b) => a < b ? a : b);
  double get maiorPreco => tamanhos.map((p) => p.preco).reduce((a, b) => a > b ? a : b);
  List<String> get cores => tamanhos.map((p) => p.cor).toSet().toList();

  /// Algum tamanho com 15 pecas ou menos (mesmo limite de "estoque baixo" da Web e da API).
  bool get temEstoqueBaixo => tamanhos.any((p) => p.estoque <= limiteEstoqueBaixo);
}

const limiteEstoqueBaixo = 15;

const _palavrasDeLigacao = {'de', 'da', 'do', 'das', 'dos', 'e', 'com', 'em', 'para', 'a', 'o'};

/// Sigla do produto para o icone sem foto, como as iniciais do app Contatos: as iniciais das
/// duas primeiras palavras do nome, sem as de ligacao ("Calca Flare de Lantejoulas" -> "CF",
/// "Bermuda" -> "B").
String siglaProduto(String nome) {
  final palavras = nome
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && !_palavrasDeLigacao.contains(p.toLowerCase()))
      .toList();
  if (palavras.isEmpty) return '?';
  return palavras.take(2).map((p) => p[0]).join().toUpperCase();
}

String _chave(String nome) => nome.trim().toLowerCase();

/// Junta os tamanhos pelo nome do modelo (sem diferenciar maiusculas), em ordem alfabetica.
List<ModeloProduto> agruparPorModelo(Iterable<Produto> produtos) {
  final grupos = <String, List<Produto>>{};
  for (final p in produtos) {
    grupos.putIfAbsent(_chave(p.nome), () => []).add(p);
  }
  return grupos.values.map((lista) => ModeloProduto(lista.first.nome.trim(), lista)).toList()
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
}

const _ordemLetras = ['PP', 'P', 'M', 'G', 'GG', 'XG', 'XGG', 'EG', 'EGG', 'U', 'UNICO', 'ÚNICO'];

/// Posicao do tamanho na grade: letras na ordem PP..XGG, depois numeros (36, 38...), depois o resto.
int _posicao(String tamanho) {
  final t = tamanho.trim().toUpperCase();
  final letra = _ordemLetras.indexOf(t);
  if (letra >= 0) return letra;
  final numero = int.tryParse(t);
  if (numero != null) return 100 + numero;
  return 1000;
}

int compararTamanhos(String a, String b) {
  final diferenca = _posicao(a) - _posicao(b);
  return diferenca != 0 ? diferenca : a.compareTo(b);
}

List<Produto> ordenarPorTamanho(Iterable<Produto> produtos) =>
    produtos.toList()..sort((a, b) {
      final porTamanho = compararTamanhos(a.tamanho, b.tamanho);
      return porTamanho != 0 ? porTamanho : a.cor.compareTo(b.cor);
    });

enum Disponibilidade { todos, emEstoque, estoqueBaixo, esgotado }

enum Ordenacao { nome, menorPreco, maiorPreco, maiorEstoque, menorEstoque }

const nomesDisponibilidade = {
  Disponibilidade.todos: 'Todos',
  Disponibilidade.emEstoque: 'Em estoque',
  Disponibilidade.estoqueBaixo: 'Estoque baixo',
  Disponibilidade.esgotado: 'Esgotado',
};

const nomesOrdenacao = {
  Ordenacao.nome: 'Nome',
  Ordenacao.menorPreco: 'Menor preço',
  Ordenacao.maiorPreco: 'Maior preço',
  Ordenacao.maiorEstoque: 'Mais estoque',
  Ordenacao.menorEstoque: 'Menos estoque',
};

/// Filtros da lista de produtos. Os filtros valem para cada tamanho: um modelo aparece se
/// algum tamanho dele atende a todos os filtros (ex.: "tamanho 38 em estoque").
class FiltroProdutos {
  final Set<String> categorias;
  final Set<String> fornecedores;
  final Set<String> tamanhos;
  final Set<String> cores;
  final Disponibilidade disponibilidade;
  final double? precoMinimo;
  final double? precoMaximo;
  final Ordenacao ordenacao;

  const FiltroProdutos({
    this.categorias = const {},
    this.fornecedores = const {},
    this.tamanhos = const {},
    this.cores = const {},
    this.disponibilidade = Disponibilidade.todos,
    this.precoMinimo,
    this.precoMaximo,
    this.ordenacao = Ordenacao.nome,
  });

  /// Quantos filtros estao ativos (a ordenacao nao conta).
  int get quantidade =>
      categorias.length +
      fornecedores.length +
      tamanhos.length +
      cores.length +
      (disponibilidade == Disponibilidade.todos ? 0 : 1) +
      (precoMinimo != null || precoMaximo != null ? 1 : 0);

  bool get vazio => quantidade == 0;

  FiltroProdutos copyWith({
    Set<String>? categorias,
    Set<String>? fornecedores,
    Set<String>? tamanhos,
    Set<String>? cores,
    Disponibilidade? disponibilidade,
    double? precoMinimo,
    double? precoMaximo,
    bool limparPreco = false,
    Ordenacao? ordenacao,
  }) =>
      FiltroProdutos(
        categorias: categorias ?? this.categorias,
        fornecedores: fornecedores ?? this.fornecedores,
        tamanhos: tamanhos ?? this.tamanhos,
        cores: cores ?? this.cores,
        disponibilidade: disponibilidade ?? this.disponibilidade,
        precoMinimo: limparPreco ? null : (precoMinimo ?? this.precoMinimo),
        precoMaximo: limparPreco ? null : (precoMaximo ?? this.precoMaximo),
        ordenacao: ordenacao ?? this.ordenacao,
      );

  bool atende(Produto p) {
    if (categorias.isNotEmpty && !categorias.contains(p.categoria)) return false;
    if (fornecedores.isNotEmpty && !fornecedores.contains(p.fornecedor)) return false;
    if (tamanhos.isNotEmpty && !tamanhos.contains(p.tamanho)) return false;
    if (cores.isNotEmpty && !cores.contains(p.cor)) return false;
    if (precoMinimo != null && p.preco < precoMinimo!) return false;
    if (precoMaximo != null && p.preco > precoMaximo!) return false;
    switch (disponibilidade) {
      case Disponibilidade.todos:
        return true;
      case Disponibilidade.emEstoque:
        return p.estoque > 0;
      // Inclui os esgotados: e a mesma regra do indicador "Estoque baixo" do painel (itens que
      // precisam de reposicao), que conta tambem os que zeraram.
      case Disponibilidade.estoqueBaixo:
        return p.estoque <= limiteEstoqueBaixo;
      case Disponibilidade.esgotado:
        return p.estoque == 0;
    }
  }

  /// Aplica os filtros, agrupa por modelo e ordena.
  List<ModeloProduto> aplicar(Iterable<Produto> produtos) {
    final modelos = agruparPorModelo(produtos.where(atende));
    switch (ordenacao) {
      case Ordenacao.nome:
        break;
      case Ordenacao.menorPreco:
        modelos.sort((a, b) => a.menorPreco.compareTo(b.menorPreco));
      case Ordenacao.maiorPreco:
        modelos.sort((a, b) => b.maiorPreco.compareTo(a.maiorPreco));
      case Ordenacao.maiorEstoque:
        modelos.sort((a, b) => b.estoqueTotal.compareTo(a.estoqueTotal));
      case Ordenacao.menorEstoque:
        modelos.sort((a, b) => a.estoqueTotal.compareTo(b.estoqueTotal));
    }
    return modelos;
  }
}

/// Opcoes que existem nos produtos carregados (o filtro so oferece o que da resultado).
class OpcoesFiltro {
  final List<String> categorias;
  final List<String> fornecedores;
  final List<String> tamanhos;
  final List<String> cores;
  final double menorPreco;
  final double maiorPreco;

  OpcoesFiltro._(this.categorias, this.fornecedores, this.tamanhos, this.cores, this.menorPreco, this.maiorPreco);

  factory OpcoesFiltro.de(List<Produto> produtos) {
    List<String> unicos(Iterable<String?> valores) =>
        (valores.whereType<String>().where((v) => v.isNotEmpty).toSet().toList()..sort());
    final precos = produtos.map((p) => p.preco);
    return OpcoesFiltro._(
      unicos(produtos.map((p) => p.categoria)),
      unicos(produtos.map((p) => p.fornecedor)),
      produtos.map((p) => p.tamanho).toSet().toList()..sort(compararTamanhos),
      unicos(produtos.map((p) => p.cor)),
      precos.isEmpty ? 0 : precos.reduce((a, b) => a < b ? a : b),
      precos.isEmpty ? 0 : precos.reduce((a, b) => a > b ? a : b),
    );
  }
}
