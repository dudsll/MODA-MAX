import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../codigo_barras.dart';
import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';
import 'leitor_screen.dart';
import 'produtos_screen.dart';

/// Cadastro e edicao de produto (gerencia e diretoria), com foto pela camera ou galeria
/// e codigo de barras lido pela camera. A exclusao fica com a diretoria, como na Web.
///
/// Fecha devolvendo true quando algo mudou, para a lista ser recarregada.
class ProdutoFormScreen extends StatefulWidget {
  /// Tamanho que esta sendo editado (null para cadastrar).
  final Produto? produto;

  /// Ao adicionar um item a um modelo (outro tamanho e/ou outra cor): nome, cor, preco,
  /// categoria, fornecedor e foto vem preenchidos a partir deste produto; o usuario informa
  /// o tamanho, ajusta a cor se for o caso e o estoque.
  final Produto? modelo;

  const ProdutoFormScreen({super.key, this.produto, this.modelo});

  static Future<bool?> abrir(BuildContext context, {Produto? produto, Produto? modelo}) => Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => ProdutoFormScreen(produto: produto, modelo: modelo)));

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Produto? _original = widget.produto;
  late final Produto? _base = widget.produto ?? widget.modelo;
  late final _nome = TextEditingController(text: _base?.nome);
  late final _descricao = TextEditingController(text: _base?.descricao);
  late final _tamanho = TextEditingController(text: _original?.tamanho);
  late final _cor = TextEditingController(text: _base?.cor);
  late final _preco = TextEditingController(
      text: _base == null ? '' : _base.preco.toStringAsFixed(2).replaceAll('.', ','));
  late final _estoque = TextEditingController(text: '${_original?.estoque ?? 0}');
  late final _codigo = TextEditingController(text: _original?.codigoBarras);

  late Future<(List<Categoria>, List<Fornecedor>)> _opcoes = _carregarOpcoes();
  int? _idCategoria;
  int? _idFornecedor;
  XFile? _novaFoto;
  bool _salvando = false;
  bool _alterado = false;

  bool get _editando => _original != null;

  Future<(List<Categoria>, List<Fornecedor>)> _carregarOpcoes() async {
    final categorias = await ApiService.instancia.categorias();
    final fornecedores = await ApiService.instancia.fornecedores();
    final base = _base;
    _idCategoria ??= base != null && base.idCategoria != 0 ? base.idCategoria : null;
    _idFornecedor ??= base != null && base.idFornecedor != 0 ? base.idFornecedor : null;
    return (categorias, fornecedores);
  }

  @override
  void dispose() {
    for (final c in [_nome, _descricao, _tamanho, _cor, _preco, _estoque, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origem == null) return;

    try {
      // A API aceita ate 2 MB: reduzir a foto da camera evita recusa por tamanho.
      final foto = await ImagePicker().pickImage(source: origem, maxWidth: 1600, imageQuality: 80);
      if (foto != null) setState(() => _novaFoto = foto);
    } catch (_) {
      if (mounted) mostrarMensagem(context, 'Não foi possível abrir a câmera ou a galeria.');
    }
  }

  Future<void> _lerCodigo() async {
    final codigo = await LeitorCodigoScreen.abrir(context, titulo: 'Código do produto');
    if (codigo != null) setState(() => _codigo.text = codigo);
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final corpo = {
        'nome': _nome.text.trim(),
        'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
        'tamanho': _tamanho.text.trim(),
        'cor': _cor.text.trim(),
        'preco': lerPreco(_preco.text)!,
        'estoque': int.parse(_estoque.text.trim()),
        'idCategoria': _idCategoria,
        'idFornecedor': _idFornecedor,
        'codigoBarras': normalizarCodigoBarras(_codigo.text),
      };
      var produto = await ApiService.instancia.salvarProduto(corpo, id: _original?.idProduto);
      _alterado = true;

      final foto = _novaFoto;
      final fotoDoModelo = widget.modelo?.enderecoFoto(apiBaseUrl);
      if (foto != null) {
        produto = await ApiService.instancia.enviarFotoProduto(produto.idProduto, await foto.readAsBytes(), foto.name);
      } else if (!_editando && fotoDoModelo != null) {
        // Novo item de um modelo: reaproveita a foto do modelo (pode ser trocada depois).
        final bytes = await ApiService.instancia.baixarFoto(fotoDoModelo);
        if (bytes != null) {
          produto = await ApiService.instancia.enviarFotoProduto(
              produto.idProduto, bytes, fotoDoModelo.split('/').last);
        }
      }

      if (!mounted) return;
      mostrarMensagem(context, _editando ? 'Produto atualizado.' : widget.modelo != null ? 'Item adicionado.' : 'Produto cadastrado.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    setState(() => _salvando = true);
    final apagou = await apagarProduto(context, _original!);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (apagou) Navigator.of(context).pop(true);
  }

  String? _obrigatorio(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório.' : null;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) Navigator.of(context).pop(_alterado);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_editando ? 'Editar item' : widget.modelo != null ? 'Novo item' : 'Novo produto')),
        body: FutureBuilder<(List<Categoria>, List<Fornecedor>)>(
          future: _opcoes,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}'),
                    TextButton(
                      onPressed: () => setState(() => _opcoes = _carregarOpcoes()),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final (categorias, fornecedores) = snapshot.data!;

            return Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(child: _Foto(original: _base, nova: _novaFoto, aoTocar: _escolherFoto)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nome,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: _obrigatorio,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descricao,
                    decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tamanho,
                          decoration: const InputDecoration(labelText: 'Tamanho'),
                          textCapitalization: TextCapitalization.characters,
                          validator: _obrigatorio,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cor,
                          decoration: const InputDecoration(labelText: 'Cor'),
                          textCapitalization: TextCapitalization.sentences,
                          validator: _obrigatorio,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _preco,
                          decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            final valor = lerPreco(v);
                            return valor == null || valor <= 0 ? 'Informe um preço válido.' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _estoque,
                          decoration: const InputDecoration(labelText: 'Estoque'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final valor = int.tryParse((v ?? '').trim());
                            return valor == null || valor < 0 ? 'Informe o estoque.' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _idCategoria,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      for (final c in categorias) DropdownMenuItem(value: c.idCategoria, child: Text(c.nome)),
                    ],
                    onChanged: (v) => setState(() => _idCategoria = v),
                    validator: (v) => v == null ? 'Escolha a categoria.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _idFornecedor,
                    decoration: const InputDecoration(labelText: 'Fornecedor'),
                    items: [
                      for (final f in fornecedores) DropdownMenuItem(value: f.idFornecedor, child: Text(f.nome)),
                    ],
                    onChanged: (v) => setState(() => _idFornecedor = v),
                    validator: (v) => v == null ? 'Escolha o fornecedor.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codigo,
                    decoration: InputDecoration(
                      labelText: 'Código de barras (opcional)',
                      suffixIcon: IconButton(
                        tooltip: 'Ler com a câmera',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _lerCodigo,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().isEmpty || codigoBarrasValido(v))
                        ? null
                        : 'Código inválido. Confira os números da etiqueta.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: _salvando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_editando ? 'Salvar alterações' : widget.modelo != null ? 'Adicionar item' : 'Cadastrar produto'),
                  ),
                  if (_editando && ApiService.instancia.podeExcluirProduto) ...[
                    const SizedBox(height: 32),
                    BotaoApagar(texto: 'Apagar Produto', aoTocar: _salvando ? null : _excluir),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pergunta e apaga o produto pela API (somente diretoria). A API recusa produtos que ja
/// foram vendidos; nesse caso mostra o aviso e devolve false.
Future<bool> apagarProduto(BuildContext context, Produto produto) async {
  final confirmar = await confirmarExclusao(
    context,
    titulo: 'Apagar produto?',
    mensagem: '${produto.nome} será removido do catálogo. Produtos que já foram vendidos não podem ser apagados.',
  );
  if (!confirmar || !context.mounted) return false;

  try {
    await ApiService.instancia.excluirProduto(produto.idProduto);
    if (context.mounted) mostrarMensagem(context, 'Produto apagado.');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) mostrarMensagem(context, e.mensagem);
    return false;
  }
}

/// Le um preco digitado em formato brasileiro ("1.299,90") ou com ponto ("129.90").
double? lerPreco(String? texto) {
  var t = (texto ?? '').trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Foto atual (ou a recem-escolhida) com o botao para trocar.
class _Foto extends StatelessWidget {
  final Produto? original;
  final XFile? nova;
  final VoidCallback aoTocar;

  const _Foto({required this.original, required this.nova, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final foto = nova;
    Widget imagem;
    if (foto != null) {
      imagem = FutureBuilder(
        future: foto.readAsBytes(),
        builder: (_, s) => s.hasData
            ? Image.memory(s.data!, width: 120, height: 120, fit: BoxFit.cover)
            : const SizedBox(width: 120, height: 120),
      );
    } else if (original != null) {
      imagem = FotoProduto(produto: original!, tamanho: 120);
    } else {
      imagem = Container(
        width: 120,
        height: 120,
        color: cores.surfaceContainerHighest,
        child: Icon(Icons.checkroom, size: 48, color: cores.onSurfaceVariant),
      );
    }

    return Column(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(24), child: imagem),
        TextButton.icon(
          onPressed: aoTocar,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(foto != null || original?.fotoUrl != null ? 'Trocar foto' : 'Adicionar foto'),
        ),
      ],
    );
  }
}
