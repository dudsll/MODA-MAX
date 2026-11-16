/// Busca tolerante usada nas listas do app (produtos, clientes e escolha de produto no pedido).
///
/// - Ignora maiusculas, acentos e pontuacao: "calca", "CALÇA" e "Calça" sao iguais, e
///   "12345678909" acha o CPF "123.456.789-09".
/// - Cada palavra digitada precisa aparecer em algum campo, em qualquer ordem: "skinny calca"
///   acha "Calca Skinny"; "jaqueta preta" acha a jaqueta na cor preta.
/// - Aceita o comeco da palavra ("berm" acha "Bermuda") e pequenos erros de digitacao, como
///   letra trocada, faltando, sobrando ou invertida ("bremuda", "jens", "skiny").
///
/// Os resultados vem do mais parecido para o menos parecido.
library;

/// Texto sem acentos, em minusculas e so com letras, numeros e espacos simples.
String normalizarTexto(String texto) {
  final saida = StringBuffer();
  for (final r in texto.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final semAcento = _semAcento[c] ?? c;
    saida.write(RegExp(r'[a-z0-9]').hasMatch(semAcento) ? semAcento : ' ');
  }
  return saida.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

const _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Quantos erros de digitacao aceitar numa palavra: nenhum nas muito curtas (senao "pp"
/// acharia "p" e "g"), um ate 5 letras e dois a partir de 6.
int _tolerancia(int letras) => letras <= 3 ? 0 : (letras <= 5 ? 1 : 2);

/// Pontuacao de [consulta] nos [campos] (nome, cor, documento...): de 0 a 1, ou null se nao
/// combina. Consulta vazia combina com tudo (pontuacao 1).
double? pontuarBusca(String consulta, Iterable<String?> campos) {
  final termos = normalizarTexto(consulta).split(' ').where((t) => t.isNotEmpty).toList();
  if (termos.isEmpty) return 1;

  final textos = campos.whereType<String>().map(normalizarTexto).where((t) => t.isNotEmpty).toList();
  final palavras = textos.expand((t) => t.split(' ')).toSet();
  // Documentos e codigos so com os digitos ("123.456.789-09" -> "12345678909").
  final digitos = campos.whereType<String>().map((c) => c.replaceAll(RegExp(r'\D'), '')).where((d) => d.isNotEmpty);

  var soma = 0.0;
  for (final termo in termos) {
    var melhor = 0.0;
    if (RegExp(r'^\d{4,}$').hasMatch(termo) && digitos.any((d) => d.contains(termo))) {
      melhor = 1; // parte de um codigo de barras, CPF ou CNPJ
    }
    for (final palavra in palavras) {
      if (melhor == 1) break;
      final p = _pontuarPalavra(termo, palavra);
      if (p > melhor) melhor = p;
    }
    // Termo dentro de uma palavra maior ("flare" em "calcaflare") ou juntando duas
    // ("calcajeans").
    if (melhor < 0.6 && termo.length >= 3 && textos.any((t) => t.replaceAll(' ', '').contains(termo))) {
      melhor = 0.6;
    }
    if (melhor == 0) return null; // toda palavra digitada precisa combinar com algo
    soma += melhor;
  }
  return soma / termos.length;
}

double _pontuarPalavra(String termo, String palavra) {
  if (palavra == termo) return 1;
  if (palavra.startsWith(termo)) return 0.9; // comeco da palavra: "berm" -> "bermuda"
  if (termo.length >= 3 && palavra.contains(termo)) return 0.7;

  final tolerancia = _tolerancia(termo.length);
  if (tolerancia == 0) return 0;
  // Palavra inteira com erro ("jens" -> "jeans") ou o comeco dela ainda sendo digitado com
  // erro ("bremu" -> "bermuda").
  var erros = _distancia(termo, palavra);
  for (final tamanho in [termo.length - 1, termo.length, termo.length + 1]) {
    if (tamanho > 0 && tamanho < palavra.length) {
      final e = _distancia(termo, palavra.substring(0, tamanho));
      if (e < erros) erros = e;
    }
  }
  return erros <= tolerancia ? 0.5 - 0.1 * erros : 0;
}

/// Quantas letras precisam ser trocadas, incluidas, apagadas ou invertidas (vizinhas) para
/// transformar [a] em [b] (distancia de Damerau-Levenshtein, versao restrita).
int _distancia(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final custo = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + custo].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] && d[i - 2][j - 2] + 1 < v) {
        v = d[i - 2][j - 2] + 1;
      }
      d[i][j] = v;
    }
  }
  return d[a.length][b.length];
}

/// Filtra [itens] pela [consulta] e ordena do mais parecido para o menos parecido (empates
/// mantem a ordem original). Consulta vazia devolve a lista como esta.
List<T> buscar<T>(String? consulta, Iterable<T> itens, Iterable<String?> Function(T) campos) {
  if (consulta == null || normalizarTexto(consulta).isEmpty) return itens.toList();
  final pontuados = <(T, double, int)>[];
  var posicao = 0;
  for (final item in itens) {
    final p = pontuarBusca(consulta, campos(item));
    if (p != null) pontuados.add((item, p, posicao));
    posicao++;
  }
  pontuados.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0 ? c : a.$3.compareTo(b.$3);
  });
  return [for (final p in pontuados) p.$1];
}
