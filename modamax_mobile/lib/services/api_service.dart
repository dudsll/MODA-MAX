import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

/// "Estratégico" -> "estrategico": compara niveis de acesso sem depender de acento.
String nivelSemAcento(String? nivel) {
  const trocas = {'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c'};
  return (nivel ?? '').trim().toLowerCase().split('').map((c) => trocas[c] ?? c).join();
}

class ApiException implements Exception {
  final String mensagem;
  final int? statusCode;

  ApiException(this.mensagem, {this.statusCode});

  bool get naoAutorizado => statusCode == 401;

  @override
  String toString() => mensagem;
}

/// Resultado de uma leitura que pode ter vindo do cache local (modo offline).
class Dados<T> {
  final T valor;
  final bool doCache;
  final DateTime? sincronizadoEm;

  Dados(this.valor, {this.doCache = false, this.sincronizadoEm});
}

/// Comunicacao com a API REST do ModaMax.
///
/// - Guarda o token JWT do login em SharedPreferences.
/// - Sincronizacao: toda listagem bem-sucedida e salva localmente; sem rede,
///   o app mostra a ultima copia sincronizada.
class ApiService {
  ApiService._();

  static final ApiService instancia = ApiService._();

  static const _chaveToken = 'token';
  static const _chaveUsuario = 'usuario';

  String? _token;
  Usuario? usuario;

  Future<bool> restaurarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_chaveToken);
    final usuarioJson = prefs.getString(_chaveUsuario);
    if (_token == null || usuarioJson == null) return false;
    usuario = Usuario.fromJson(jsonDecode(usuarioJson) as Map<String, dynamic>);
    return true;
  }

  Future<Usuario> login(String email, String senha) async {
    final resposta = await _enviar('POST', '/api/auth/login', corpo: {'email': email, 'senha': senha}, autenticado: false);
    final json = resposta as Map<String, dynamic>;

    _token = json['token'] as String;
    usuario = Usuario.fromJson(json);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveToken, _token!);
    await prefs.setString(_chaveUsuario, jsonEncode(usuario!.toJson()));
    return usuario!;
  }

  Future<void> logout() async {
    _token = null;
    usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveToken);
    await prefs.remove(_chaveUsuario);
  }

  Future<Dados<Dashboard>> dashboard() => _lerComCache(
        '/api/dashboard',
        (json) => Dashboard.fromJson(json as Map<String, dynamic>),
      );

  Future<Dados<GraficosDashboard>> graficos() => _lerComCache(
        '/api/dashboard/graficos',
        (json) => GraficosDashboard.fromJson(json as Map<String, dynamic>),
      );

  Future<Dados<List<Produto>>> produtos({String? busca}) => _lerComCache(
        _comBusca('/api/produtos', busca),
        (json) => (json as List).map((p) => Produto.fromJson(p as Map<String, dynamic>)).toList(),
      );

  Future<Dados<List<Cliente>>> clientes({String? busca}) => _lerComCache(
        _comBusca('/api/clientes', busca),
        (json) => (json as List).map((c) => Cliente.fromJson(c as Map<String, dynamic>)).toList(),
      );

  Future<Dados<List<Pedido>>> pedidos() => _lerComCache(
        '/api/pedidos',
        (json) => (json as List).map((p) => Pedido.fromJson(p as Map<String, dynamic>)).toList(),
      );

  Future<Pedido> pedido(int id) async =>
      Pedido.fromJson(await _enviar('GET', '/api/pedidos/$id') as Map<String, dynamic>);

  Future<Pedido> criarPedido({
    required int idCliente,
    required String tipoVenda,
    required List<ItemCarrinho> itens,
    String formaPagamento = 'Pix',
    int parcelas = 1,
  }) async {
    final json = await _enviar('POST', '/api/pedidos', corpo: {
      'idCliente': idCliente,
      'tiposVenda': tipoVenda,
      'formaPagamento': formaPagamento,
      'parcelas': parcelas,
      'itens': itens.map((i) => i.toJson()).toList(),
    });
    return Pedido.fromJson(json as Map<String, dynamic>);
  }

  Future<void> cancelarPedido(int id) => _enviar('PUT', '/api/pedidos/$id/cancelar');

  Future<void> confirmarPagamento(int id) => _enviar('PUT', '/api/pedidos/$id/pagamento');

  /// "PIX copia e cola" do pedido para enviar ao cliente.
  Future<String> pixDoPedido(int id) async =>
      ((await _enviar('GET', '/api/pedidos/$id/pix')) as Map<String, dynamic>)['copiaECola'] as String;

  Future<Dados<MetaAtual>> metaAtual() => _lerComCache(
        '/api/metas/atual',
        (json) => MetaAtual.fromJson(json as Map<String, dynamic>),
      );

  Future<Dados<List<ItemReposicao>>> reposicao() => _lerComCache(
        '/api/reposicao',
        (json) => (json as List).map((r) => ItemReposicao.fromJson(r as Map<String, dynamic>)).toList(),
      );

  /// Busca o produto pelo codigo de barras lido na camera (sem cache: o estoque precisa ser o atual).
  Future<Produto> produtoPorCodigo(String codigo) async => Produto.fromJson(
      await _enviar('GET', '/api/produtos/codigo/${Uri.encodeComponent(codigo)}') as Map<String, dynamic>);

  /// Registra entrada de mercadoria e devolve o novo estoque (somente Estrategico e Tatico).
  Future<int> entradaEstoque(int idProduto, int quantidade, {String? observacao}) async {
    final json = await _enviar('POST', '/api/produtos/$idProduto/entrada-estoque',
        corpo: {'quantidade': quantidade, 'observacao': observacao});
    return (json as Map<String, dynamic>)['estoque'] as int;
  }

  /// Nivel sem acento e em minusculas: a API devolve "Estratégico", "Tático" e "Operacional".
  String get _nivel => nivelSemAcento(usuario?.nivel);

  /// Gerentes e diretoria podem dar entrada no estoque, cadastrar produtos e cancelar pedidos.
  bool get podeGerenciarEstoque => _nivel == 'estrategico' || _nivel == 'tatico';

  /// Somente a diretoria exclui produtos (mesma regra da API e da Web).
  bool get podeExcluirProduto => _nivel == 'estrategico';

  /// Gerencia e diretoria excluem clientes (a API recusa quem ja tem pedidos).
  bool get podeExcluirCliente => podeGerenciarEstoque;

  Future<void> excluirCliente(int id) => _enviar('DELETE', '/api/clientes/$id');

  Future<Cliente> cliente(int id) async =>
      Cliente.fromJson(await _enviar('GET', '/api/clientes/$id') as Map<String, dynamic>);

  Future<List<Categoria>> categorias() async => ((await _enviar('GET', '/api/categorias')) as List)
      .map((c) => Categoria.fromJson(c as Map<String, dynamic>))
      .toList();

  Future<List<Fornecedor>> fornecedores() async => ((await _enviar('GET', '/api/fornecedores')) as List)
      .map((f) => Fornecedor.fromJson(f as Map<String, dynamic>))
      .toList();

  /// Cadastra (sem id) ou altera um produto e devolve o produto como ficou na API.
  Future<Produto> salvarProduto(Map<String, dynamic> corpo, {int? id}) async {
    if (id == null) {
      return Produto.fromJson(await _enviar('POST', '/api/produtos', corpo: corpo) as Map<String, dynamic>);
    }
    await _enviar('PUT', '/api/produtos/$id', corpo: corpo);
    return Produto.fromJson(await _enviar('GET', '/api/produtos/$id') as Map<String, dynamic>);
  }

  Future<void> excluirProduto(int id) => _enviar('DELETE', '/api/produtos/$id');

  /// Baixa a foto de um produto (para reaproveita-la num novo tamanho do mesmo modelo).
  Future<Uint8List?> baixarFoto(String endereco) async {
    try {
      final resposta = await http.get(Uri.parse(endereco)).timeout(const Duration(seconds: 15));
      return resposta.statusCode == 200 ? resposta.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  /// Envia a foto (JPG, PNG ou WebP de ate 2 MB; a API confere o conteudo do arquivo).
  Future<Produto> enviarFotoProduto(int id, Uint8List bytes, String nomeArquivo) async {
    final requisicao = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/produtos/$id/foto'))
      ..headers['Accept'] = 'application/json'
      ..files.add(http.MultipartFile.fromBytes('foto', bytes, filename: nomeArquivo));
    if (_token != null) requisicao.headers['Authorization'] = 'Bearer $_token';
    final resposta = await _executar(() async =>
        http.Response.fromStream(await requisicao.send().timeout(const Duration(seconds: 30))));
    return Produto.fromJson(resposta as Map<String, dynamic>);
  }

  Future<Cliente> salvarCliente(Map<String, dynamic> corpo, {int? id}) async {
    if (id == null) {
      return Cliente.fromJson(await _enviar('POST', '/api/clientes', corpo: corpo) as Map<String, dynamic>);
    }
    await _enviar('PUT', '/api/clientes/$id', corpo: corpo);
    return Cliente.fromJson({...corpo, 'idCliente': id});
  }

  String _comBusca(String caminho, String? busca) =>
      (busca == null || busca.trim().isEmpty) ? caminho : '$caminho?busca=${Uri.encodeQueryComponent(busca.trim())}';

  Future<Dados<T>> _lerComCache<T>(String caminho, T Function(dynamic json) converter) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = 'cache:$caminho';

    try {
      final json = await _enviar('GET', caminho);
      await prefs.setString(chave, jsonEncode({'em': DateTime.now().toIso8601String(), 'dados': json}));
      return Dados(converter(json));
    } on ApiException catch (e) {
      // Erro de regra/permissao: nao adianta mostrar cache.
      if (e.statusCode != null) rethrow;

      final salvo = prefs.getString(chave);
      if (salvo == null) rethrow;
      final cache = jsonDecode(salvo) as Map<String, dynamic>;
      return Dados(
        converter(cache['dados']),
        doCache: true,
        sincronizadoEm: DateTime.parse(cache['em'] as String),
      );
    }
  }

  Future<dynamic> _enviar(String metodo, String caminho, {Object? corpo, bool autenticado = true}) async {
    final uri = Uri.parse('$apiBaseUrl$caminho');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (autenticado && _token != null) 'Authorization': 'Bearer $_token',
    };

    return _executar(() async {
      final requisicao = http.Request(metodo, uri)..headers.addAll(headers);
      if (corpo != null) requisicao.body = jsonEncode(corpo);
      return http.Response.fromStream(await requisicao.send().timeout(const Duration(seconds: 15)));
    });
  }

  /// Executa a requisicao e converte a resposta (JSON ou erro em Problem Details).
  Future<dynamic> _executar(Future<http.Response> Function() enviar) async {
    http.Response resposta;
    try {
      resposta = await enviar();
    } catch (_) {
      throw ApiException('Sem conexão com o servidor ModaMax.');
    }

    if (resposta.statusCode == 401) {
      throw ApiException('Sessão expirada ou credenciais inválidas.', statusCode: 401);
    }
    if (resposta.statusCode == 403) {
      throw ApiException('Seu nível de acesso não permite esta operação.', statusCode: 403);
    }
    if (resposta.statusCode >= 400) {
      throw ApiException(_mensagemDeErro(resposta), statusCode: resposta.statusCode);
    }

    if (resposta.body.isEmpty) return null;
    return jsonDecode(utf8.decode(resposta.bodyBytes));
  }

  String _mensagemDeErro(http.Response resposta) {
    try {
      // A API responde erros no padrao Problem Details: a mensagem para o usuario vem em "detail".
      final json = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (json is Map && json['detail'] != null) return json['detail'] as String;
      if (json is Map && json['mensagem'] != null) return json['mensagem'] as String;
      if (json is Map && json['title'] != null) return json['title'] as String;
    } catch (_) {}
    return 'Erro ${resposta.statusCode} ao comunicar com a API.';
  }
}
