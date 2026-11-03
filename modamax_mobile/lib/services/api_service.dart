import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

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

  Future<Pedido> criarPedido({required int idCliente, required String tipoVenda, required List<ItemCarrinho> itens}) async {
    final json = await _enviar('POST', '/api/pedidos', corpo: {
      'idCliente': idCliente,
      'tiposVenda': tipoVenda,
      'itens': itens.map((i) => i.toJson()).toList(),
    });
    return Pedido.fromJson(json as Map<String, dynamic>);
  }

  Future<void> cancelarPedido(int id) => _enviar('PUT', '/api/pedidos/$id/cancelar');

  /// Busca o produto pelo codigo de barras lido na camera (sem cache: o estoque precisa ser o atual).
  Future<Produto> produtoPorCodigo(String codigo) async => Produto.fromJson(
      await _enviar('GET', '/api/produtos/codigo/${Uri.encodeComponent(codigo)}') as Map<String, dynamic>);

  /// Registra entrada de mercadoria e devolve o novo estoque (somente Estrategico e Tatico).
  Future<int> entradaEstoque(int idProduto, int quantidade, {String? observacao}) async {
    final json = await _enviar('POST', '/api/produtos/$idProduto/entrada-estoque',
        corpo: {'quantidade': quantidade, 'observacao': observacao});
    return (json as Map<String, dynamic>)['estoque'] as int;
  }

  /// Gerentes e diretoria podem dar entrada no estoque e cancelar pedidos.
  bool get podeGerenciarEstoque => usuario != null && usuario!.nivel != 'Operacional';

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

    http.Response resposta;
    try {
      final requisicao = http.Request(metodo, uri)..headers.addAll(headers);
      if (corpo != null) requisicao.body = jsonEncode(corpo);
      resposta = await http.Response.fromStream(await requisicao.send().timeout(const Duration(seconds: 15)));
    } catch (_) {
      throw ApiException('Sem conexao com o servidor ModaMax.');
    }

    if (resposta.statusCode == 401) {
      throw ApiException('Sessao expirada ou credenciais invalidas.', statusCode: 401);
    }
    if (resposta.statusCode == 403) {
      throw ApiException('Seu nivel de acesso nao permite esta operacao.', statusCode: 403);
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
