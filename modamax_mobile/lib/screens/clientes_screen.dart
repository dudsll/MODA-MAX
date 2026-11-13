import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';

/// Pergunta e apaga o cliente pela API. A API recusa clientes que ja fizeram pedidos
/// (para nao apagar o historico de vendas); nesse caso mostra o aviso e devolve false.
Future<bool> apagarCliente(BuildContext context, Cliente cliente) async {
  final confirmar = await confirmarExclusao(
    context,
    titulo: 'Apagar cliente?',
    mensagem: '${cliente.nome} será removido. Clientes que já fizeram pedidos não podem ser apagados, '
        'para não perder o histórico de vendas.',
  );
  if (!confirmar || !context.mounted) return false;

  try {
    await ApiService.instancia.excluirCliente(cliente.idCliente);
    if (context.mounted) mostrarMensagem(context, 'Cliente apagado.');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) mostrarMensagem(context, e.mensagem);
    return false;
  }
}

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  String? _busca;
  late Future<Dados<List<Cliente>>> _futuro = ApiService.instancia.clientes();

  // Apagados arrastando: saem da lista na hora, sem esperar recarregar.
  final _apagados = <int>{};

  Future<void> _atualizar() async {
    setState(() {
      _apagados.clear();
      _futuro = ApiService.instancia.clientes(busca: _busca);
    });
    await _futuro;
  }

  Future<void> _novoCliente() async {
    final salvou = await Navigator.of(context).push<ResultadoEdicao>(
      MaterialPageRoute(builder: (_) => const ClienteFormScreen()),
    );
    if (salvou != null) _atualizar();
  }

  Future<void> _abrirFicha(Cliente cliente) async {
    final mudou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteDetalheScreen(cliente: cliente)),
    );
    if (mudou == true) _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    return CarregarDados<List<Cliente>>(
      futuro: _futuro,
      aoAtualizar: _atualizar,
      construir: (dados) {
        final clientes = dados.valor.where((c) => !_apagados.contains(c.idCliente)).toList();
        return ListaAtualizavel(
          aoAtualizar: _atualizar,
          children: [
            CampoBusca(
              dica: 'Buscar por nome ou documento',
              texto: _busca,
              aoBuscar: (texto) {
                _busca = texto;
                _atualizar();
              },
            ),
            BotaoNovo(texto: 'Novo cliente', aoTocar: dados.doCache ? null : _novoCliente),
            if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
            if (clientes.isEmpty)
              const SecaoLista(children: [ItemLista(titulo: 'Nenhum cliente encontrado.')]),
            SecaoLista(
              rodape: clientes.isEmpty ? null : '${clientes.length} ${clientes.length == 1 ? 'cliente' : 'clientes'}',
              children: [
                for (final c in clientes)
                  ArrastarParaApagar(
                    chave: ValueKey('cliente-${c.idCliente}'),
                    permitido: !dados.doCache && ApiService.instancia.podeExcluirCliente,
                    aoApagar: () => apagarCliente(context, c),
                    aoRemover: () => setState(() => _apagados.add(c.idCliente)),
                    child: ItemLista(
                      inicio: Avatar(iniciais(c.nome)),
                      titulo: c.nome,
                      subtitulo: '${c.tipo} ${c.documento} · ${c.email}',
                      seta: true,
                      aoTocar: dados.doCache ? null : () => _abrirFicha(c),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Iniciais para o avatar, como no app Contatos ("Gabriel Mancini" -> "GM").
String iniciais(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  final primeira = partes.first[0];
  final ultima = partes.length > 1 ? partes.last[0] : '';
  return (primeira + ultima).toUpperCase();
}

/// Ficha do cliente, no estilo do app Contatos: avatar, nome, dados e "Editar" no canto.
/// Fecha devolvendo true quando o cliente foi alterado ou apagado.
class ClienteDetalheScreen extends StatefulWidget {
  final Cliente cliente;

  const ClienteDetalheScreen({super.key, required this.cliente});

  @override
  State<ClienteDetalheScreen> createState() => _ClienteDetalheScreenState();
}

class _ClienteDetalheScreenState extends State<ClienteDetalheScreen> {
  late Cliente _cliente = widget.cliente;
  bool _alterado = false;

  Future<void> _editar() async {
    final resultado = await Navigator.of(context).push<ResultadoEdicao>(
      MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: _cliente)),
    );
    if (resultado == null || !mounted) return;

    if (resultado == ResultadoEdicao.apagado) {
      Navigator.of(context).pop(true);
      return;
    }
    _alterado = true;
    try {
      final atualizado = await ApiService.instancia.cliente(_cliente.idCliente);
      if (mounted) setState(() => _cliente = atualizado);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cliente;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) Navigator.of(context).pop(_alterado);
      },
      child: Pagina(
        acoes: [BotaoTopo(rotulo: 'Editar', aoTocar: _editar)],
        corpo: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 8),
            Center(child: Avatar(iniciais(c.nome), tamanho: 112)),
            const SizedBox(height: 12),
            Text(c.nome, textAlign: TextAlign.center, style: estiloTituloGrande(context)),
            Text(c.tipo == 'PJ' ? 'Pessoa jurídica' : 'Pessoa física',
                textAlign: TextAlign.center, style: estiloSecundario(context)),
            const SizedBox(height: 12),
            SecaoLista(semIcones: true, children: [
              _Campo(rotulo: c.tipo == 'PJ' ? 'CNPJ' : 'CPF', valor: c.documento),
              _Campo(rotulo: 'e-mail', valor: c.email),
              if (c.telefone != null && c.telefone!.isNotEmpty) _Campo(rotulo: 'telefone', valor: c.telefone!),
              if (c.endereco != null && c.endereco!.isNotEmpty) _Campo(rotulo: 'endereço', valor: c.endereco!),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Um dado do cliente: o rotulo pequeno em cima e o valor embaixo, como no app Contatos.
class _Campo extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _Campo({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    // Ocupa a largura toda, para o texto ficar alinhado a esquerda (e nao centralizado).
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: estiloLegenda(context)),
          const SizedBox(height: 2),
          SelectableText(valor, style: estiloCorpo(context)),
        ],
      ),
    );
  }
}

/// Edicao (ou cadastro) do cliente. Na edicao, "Apagar Cliente" fica no fim da tela,
/// como "Apagar Contato" no iPhone.
class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente;

  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.cliente?.nome);
  late final _documento = TextEditingController(text: widget.cliente?.documento);
  late final _email = TextEditingController(text: widget.cliente?.email);
  late final _telefone = TextEditingController(text: widget.cliente?.telefone);
  late final _endereco = TextEditingController(text: widget.cliente?.endereco);
  late String _tipo = widget.cliente?.tipo ?? 'PF';
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in [_nome, _documento, _email, _telefone, _endereco]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      await ApiService.instancia.salvarCliente(
        Cliente.corpo(
          nome: _nome.text.trim(),
          tipo: _tipo,
          documento: _documento.text.trim(),
          email: _email.text.trim(),
          telefone: _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
          endereco: _endereco.text.trim().isEmpty ? null : _endereco.text.trim(),
        ),
        id: widget.cliente?.idCliente,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ResultadoEdicao.salvo);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _apagar() async {
    setState(() => _salvando = true);
    final apagou = await apagarCliente(context, widget.cliente!);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (apagou) Navigator.of(context).pop(ResultadoEdicao.apagado);
  }

  String? _obrigatorio(String valor) => valor.trim().isEmpty ? 'Campo obrigatório.' : null;

  @override
  Widget build(BuildContext context) {
    final editando = widget.cliente != null;
    final ios = ehIOS(context);
    return Pagina(
      titulo: editando ? 'Editar cliente' : 'Novo cliente',
      // No iPhone o "Salvar" fica no canto superior, como ao editar um contato.
      acoes: ios ? [BotaoTopo(rotulo: 'Salvar', aoTocar: _salvando ? null : _salvar)] : const [],
      corpo: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Segmentado<String>(
                opcoes: const {'PF': 'Pessoa física', 'PJ': 'Pessoa jurídica'},
                selecionado: _tipo,
                aoMudar: (t) => setState(() => _tipo = t),
              ),
            ),
            SecaoFormulario(children: [
              CampoTexto(controle: _nome, rotulo: 'Nome', maiusculas: TextCapitalization.words, validar: _obrigatorio),
              CampoTexto(
                controle: _documento,
                rotulo: _tipo == 'PF' ? 'CPF' : 'CNPJ',
                teclado: TextInputType.number,
                validar: _obrigatorio,
              ),
            ]),
            SecaoFormulario(cabecalho: 'Contato', children: [
              CampoTexto(
                controle: _email,
                rotulo: 'E-mail',
                teclado: TextInputType.emailAddress,
                validar: (v) => v.contains('@') ? null : 'Informe um e-mail válido.',
              ),
              CampoTexto(controle: _telefone, rotulo: 'Telefone', dica: 'Opcional', teclado: TextInputType.phone),
              CampoTexto(controle: _endereco, rotulo: 'Endereço', dica: 'Opcional', maiusculas: TextCapitalization.words),
            ]),
            if (!ios)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Botao.principal(
                  editando ? 'Salvar alterações' : 'Cadastrar cliente',
                  carregando: _salvando,
                  aoTocar: _salvar,
                ),
              ),
            if (editando && ApiService.instancia.podeExcluirCliente) ...[
              const SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ios ? 0 : 16),
                child: BotaoApagar(texto: 'Apagar Cliente', aoTocar: _salvando ? null : _apagar),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
