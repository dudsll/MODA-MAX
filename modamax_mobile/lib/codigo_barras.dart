/// Validacao de codigos de barras GTIN (EAN-8, UPC-A, EAN-13 e GTIN-14),
/// a mesma regra usada pela API: o ultimo digito confere os demais.
library;

const _tamanhosValidos = {8, 12, 13, 14};

/// Remove espacos e tracos; devolve null quando nada foi informado.
String? normalizarCodigoBarras(String? codigo) {
  if (codigo == null) return null;
  final limpo = codigo.replaceAll(RegExp(r'[\s-]'), '');
  return limpo.isEmpty ? null : limpo;
}

bool codigoBarrasValido(String? codigo) {
  if (codigo == null || !_tamanhosValidos.contains(codigo.length) || !RegExp(r'^\d+$').hasMatch(codigo)) {
    return false;
  }
  final semDigito = codigo.substring(0, codigo.length - 1);
  return digitoVerificador(semDigito) == int.parse(codigo[codigo.length - 1]);
}

/// Digito verificador modulo 10 com pesos 3 e 1, da direita para a esquerda.
int digitoVerificador(String semDigito) {
  var soma = 0;
  for (var i = 0; i < semDigito.length; i++) {
    final peso = (semDigito.length - i) % 2 == 1 ? 3 : 1;
    soma += int.parse(semDigito[i]) * peso;
  }
  return (10 - soma % 10) % 10;
}
