// Modelos que espelham os DTOs JSON da API ModaMax.

double _decimal(dynamic valor) => (valor as num?)?.toDouble() ?? 0;

class Usuario {
  final int idUsuario;
  final String nome;
  final String email;
  final String nivel;

  Usuario({required this.idUsuario, required this.nome, required this.email, required this.nivel});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        idUsuario: json['idUsuario'] as int,
        nome: json['nome'] as String,
        email: json['email'] as String,
        nivel: json['nivel'] as String,
      );

  Map<String, dynamic> toJson() => {'idUsuario': idUsuario, 'nome': nome, 'email': email, 'nivel': nivel};
}

class Categoria {
  final int idCategoria;
  final String nome;

  Categoria({required this.idCategoria, required this.nome});

  factory Categoria.fromJson(Map<String, dynamic> json) =>
      Categoria(idCategoria: json['idCategoria'] as int, nome: json['nome'] as String);
}

class Produto {
  final int idProduto;
  final String nome;
  final String? descricao;
  final String tamanho;
  final String cor;
  final double preco;
  final int estoque;
  final String? categoria;
  final String? fornecedor;

  Produto({
    required this.idProduto,
    required this.nome,
    this.descricao,
    required this.tamanho,
    required this.cor,
    required this.preco,
    required this.estoque,
    this.categoria,
    this.fornecedor,
  });

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
        idProduto: json['idProduto'] as int,
        nome: json['nome'] as String,
        descricao: json['descricao'] as String?,
        tamanho: json['tamanho'] as String,
        cor: json['cor'] as String,
        preco: _decimal(json['preco']),
        estoque: json['estoque'] as int,
        categoria: json['categoria'] as String?,
        fornecedor: json['fornecedor'] as String?,
      );
}

class Cliente {
  final int idCliente;
  final String nome;
  final String tipo;
  final String documento;
  final String email;
  final String? telefone;
  final String? endereco;

  Cliente({
    required this.idCliente,
    required this.nome,
    required this.tipo,
    required this.documento,
    required this.email,
    this.telefone,
    this.endereco,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        idCliente: json['idCliente'] as int,
        nome: json['nome'] as String,
        tipo: json['tipo'] as String,
        documento: json['documento'] as String,
        email: json['email'] as String,
        telefone: json['telefone'] as String?,
        endereco: json['endereco'] as String?,
      );

  /// Corpo enviado em POST/PUT /api/clientes.
  static Map<String, dynamic> corpo({
    required String nome,
    required String tipo,
    required String documento,
    required String email,
    String? telefone,
    String? endereco,
  }) =>
      {
        'nome': nome,
        'tipo': tipo,
        'documento': documento,
        'email': email,
        'telefone': telefone,
        'endereco': endereco,
      };
}

class ItemPedido {
  final int idProduto;
  final String? produto;
  final int quantidade;
  final double precoUnitario;
  final double desconto;
  final double subtotal;

  ItemPedido({
    required this.idProduto,
    this.produto,
    required this.quantidade,
    required this.precoUnitario,
    required this.desconto,
    required this.subtotal,
  });

  factory ItemPedido.fromJson(Map<String, dynamic> json) => ItemPedido(
        idProduto: json['idProduto'] as int,
        produto: json['produto'] as String?,
        quantidade: json['quantidade'] as int,
        precoUnitario: _decimal(json['precoUnitario']),
        desconto: _decimal(json['desconto']),
        subtotal: _decimal(json['subtotal']),
      );
}

class Pedido {
  final int idPedido;
  final int idCliente;
  final String? cliente;
  final DateTime dataPedido;
  final String tiposVenda;
  final String status;
  final double valorTotal;
  final List<ItemPedido> itens;

  Pedido({
    required this.idPedido,
    required this.idCliente,
    this.cliente,
    required this.dataPedido,
    required this.tiposVenda,
    required this.status,
    required this.valorTotal,
    required this.itens,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) => Pedido(
        idPedido: json['idPedido'] as int,
        idCliente: json['idCliente'] as int,
        cliente: json['cliente'] as String?,
        dataPedido: DateTime.parse(json['dataPedido'] as String),
        tiposVenda: json['tiposVenda'] as String,
        status: json['status'] as String,
        valorTotal: _decimal(json['valorTotal']),
        itens: (json['itens'] as List<dynamic>)
            .map((i) => ItemPedido.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

class Dashboard {
  final int totalProdutos;
  final int totalClientes;
  final int totalPedidos;
  final double faturamentoTotal;
  final int produtosEstoqueBaixo;

  Dashboard({
    required this.totalProdutos,
    required this.totalClientes,
    required this.totalPedidos,
    required this.faturamentoTotal,
    required this.produtosEstoqueBaixo,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        totalProdutos: json['totalProdutos'] as int,
        totalClientes: json['totalClientes'] as int,
        totalPedidos: json['totalPedidos'] as int,
        faturamentoTotal: _decimal(json['faturamentoTotal']),
        produtosEstoqueBaixo: json['produtosEstoqueBaixo'] as int,
      );
}

/// Item escolhido na tela de novo pedido (antes de enviar para a API).
class ItemCarrinho {
  final Produto produto;
  int quantidade;

  ItemCarrinho(this.produto, {this.quantidade = 1});

  Map<String, dynamic> toJson() => {'idProduto': produto.idProduto, 'quantidade': quantidade, 'desconto': 0};
}

String formatarMoeda(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return 'R\$ $inteiro,${partes[1]}';
}

String formatarData(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
