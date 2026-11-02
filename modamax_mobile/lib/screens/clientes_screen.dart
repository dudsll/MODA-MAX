import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/comum.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  String? _busca;
  late Future<Dados<List<Cliente>>> _futuro = ApiService.instancia.clientes();

  Future<void> _atualizar() async {
    setState(() => _futuro = ApiService.instancia.clientes(busca: _busca));
    await _futuro;
  }

  Future<void> _abrirFormulario([Cliente? cliente]) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: cliente)),
    );
    if (salvou == true) _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo cliente'),
      ),
      body: CarregarDados<List<Cliente>>(
        futuro: _futuro,
        aoAtualizar: _atualizar,
        construir: (dados) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            CampoBusca(
              dica: 'Buscar por nome ou documento',
              aoBuscar: (texto) {
                _busca = texto;
                _atualizar();
              },
            ),
            if (dados.doCache) AvisoOffline(sincronizadoEm: dados.sincronizadoEm),
            if (dados.valor.isEmpty) const ListTile(title: Text('Nenhum cliente encontrado.')),
            for (final c in dados.valor)
              ListTile(
                leading: CircleAvatar(child: Text(c.nome.isEmpty ? '?' : c.nome[0])),
                title: Text(c.nome),
                subtitle: Text('${c.tipo} ${c.documento}\n${c.email}'),
                isThreeLine: true,
                trailing: const Icon(Icons.edit_outlined),
                onTap: dados.doCache ? null : () => _abrirFormulario(c),
              ),
          ],
        ),
      ),
    );
  }
}

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
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensagem(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String? _obrigatorio(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obrigatorio.' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cliente == null ? 'Novo cliente' : 'Editar cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome'), validator: _obrigatorio),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PF', label: Text('Pessoa fisica')),
                ButtonSegment(value: 'PJ', label: Text('Pessoa juridica')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _documento,
              decoration: InputDecoration(labelText: _tipo == 'PF' ? 'CPF' : 'CNPJ'),
              keyboardType: TextInputType.number,
              validator: _obrigatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail valido.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefone,
              decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _endereco, decoration: const InputDecoration(labelText: 'Endereco (opcional)')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
