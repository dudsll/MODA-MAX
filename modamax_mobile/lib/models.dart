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
  final String? codigoBarras;

  /// Caminho da foto na API (ex.: /uploads/produtos/abc.jpg) ou null se nao houver foto.
  final String? fotoUrl;

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
    this.codigoBarras,
    this.fotoUrl,
  });

  /// Endereco completo da foto, juntando o servidor da API com o caminho devolvido por ela.
  String? enderecoFoto(String servidor) {
    final foto = fotoUrl;
    if (foto == null || foto.isEmpty) return null;
    if (foto.startsWith('http://') || foto.startsWith('https://')) return foto;
    return '$servidor$foto';
  }

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
        codigoBarras: json['codigoBarras'] as String?,
        fotoUrl: json['fotoUrl'] as String?,
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
  final String formaPagamento;
  final int parcelas;
  final String statusPagamento;

  Pedido({
    required this.idPedido,
    required this.idCliente,
    this.cliente,
    required this.dataPedido,
    required this.tiposVenda,
    required this.status,
    required this.valorTotal,
    required this.itens,
    this.formaPagamento = 'Pix',
    this.parcelas = 1,
    this.statusPagamento = 'Pendente',
  });

  bool get pagamentoPendente => statusPagamento == 'Pendente' && status != 'Cancelado';

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
        // Valores padrao para dados salvos no cache antes da versao com pagamentos.
        formaPagamento: json['formaPagamento'] as String? ?? 'Pix',
        parcelas: json['parcelas'] as int? ?? 1,
        statusPagamento: json['statusPagamento'] as String? ?? 'Pendente',
      );
}

/// Formas de pagamento aceitas pela API (codigo -> nome exibido).
const formasPagamento = {
  'Pix': 'PIX',
  'Credito': 'Cartão de crédito',
  'Debito': 'Cartão de débito',
  'Boleto': 'Boleto',
  'Dinheiro': 'Dinheiro',
};

const maxParcelas = 6;

String nomePagamento(String forma) => formasPagamento[forma] ?? forma;

class IndicadorMeta {
  final double meta;
  final double realizado;
  final int percentual;

  IndicadorMeta({required this.meta, required this.realizado, required this.percentual});

  factory IndicadorMeta.fromJson(Map<String, dynamic> json) => IndicadorMeta(
        meta: _decimal(json['meta']),
        realizado: _decimal(json['realizado']),
        percentual: json['percentual'] as int,
      );
}

/// Progresso das metas do mes (GET /api/metas/atual).
class MetaAtual {
  final String mes;
  final bool definida;
  final IndicadorMeta faturamento;
  final IndicadorMeta pedidos;
  final IndicadorMeta pecas;
  final double projecaoFaturamento;
  final int diasRestantes;

  MetaAtual({
    required this.mes,
    required this.definida,
    required this.faturamento,
    required this.pedidos,
    required this.pecas,
    required this.projecaoFaturamento,
    required this.diasRestantes,
  });

  factory MetaAtual.fromJson(Map<String, dynamic> json) => MetaAtual(
        mes: json['mes'] as String,
        definida: json['definida'] as bool,
        faturamento: IndicadorMeta.fromJson(json['faturamento'] as Map<String, dynamic>),
        pedidos: IndicadorMeta.fromJson(json['pedidos'] as Map<String, dynamic>),
        pecas: IndicadorMeta.fromJson(json['pecas'] as Map<String, dynamic>),
        projecaoFaturamento: _decimal(json['projecaoFaturamento']),
        diasRestantes: json['diasRestantes'] as int,
      );
}

/// Produto da central de reposicao (GET /api/reposicao).
class ItemReposicao {
  final int idProduto;
  final String produto;
  final String? categoria;
  final int estoque;
  final int vendidosNoPeriodo;
  final int? diasDeCobertura;
  final int quantidadeSugerida;
  final String situacao;

  ItemReposicao({
    required this.idProduto,
    required this.produto,
    this.categoria,
    required this.estoque,
    required this.vendidosNoPeriodo,
    this.diasDeCobertura,
    required this.quantidadeSugerida,
    required this.situacao,
  });

  bool get critico => situacao == 'Critico';

  factory ItemReposicao.fromJson(Map<String, dynamic> json) => ItemReposicao(
        idProduto: json['idProduto'] as int,
        produto: json['produto'] as String,
        categoria: json['categoria'] as String?,
        estoque: json['estoque'] as int,
        vendidosNoPeriodo: json['vendidosNoPeriodo'] as int,
        diasDeCobertura: json['diasDeCobertura'] as int?,
        quantidadeSugerida: json['quantidadeSugerida'] as int,
        situacao: json['situacao'] as String,
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

class PontoGrafico {
  final String rotulo;
  final double valor;

  PontoGrafico(this.rotulo, this.valor);

  factory PontoGrafico.fromJson(Map<String, dynamic> json) =>
      PontoGrafico(json['rotulo'] as String, _decimal(json['valor']));
}

class GraficosDashboard {
  final List<PontoGrafico> vendasPorMes;
  final List<PontoGrafico> produtosMaisVendidos;
  final List<PontoGrafico> pedidosPorStatus;

  GraficosDashboard({required this.vendasPorMes, required this.produtosMaisVendidos, required this.pedidosPorStatus});

  static List<PontoGrafico> _lista(dynamic json) =>
      (json as List<dynamic>).map((p) => PontoGrafico.fromJson(p as Map<String, dynamic>)).toList();

  factory GraficosDashboard.fromJson(Map<String, dynamic> json) => GraficosDashboard(
        vendasPorMes: _lista(json['vendasPorMes']),
        produtosMaisVendidos: _lista(json['produtosMaisVendidos']),
        pedidosPorStatus: _lista(json['pedidosPorStatus']),
      );
}
