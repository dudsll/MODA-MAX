import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Componentes adaptativos: no iPhone usam os componentes da Apple (Cupertino) e no Android
/// os do Google (Material 3). As telas usam so estas pecas, e cada sistema fica com o
/// visual nativo dele, sem duplicar a logica.
bool ehIOS(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS;

/// Escolhe o icone de cada sistema (ex.: lupa do iOS ou do Material).
IconData icone(BuildContext context, {required IconData material, required IconData ios}) =>
    ehIOS(context) ? ios : material;

/// Cabecalho e rodape de secao no padrao do iOS: texto pequeno e cinza.
Widget _textoSecao(BuildContext context, String texto, {bool cabecalho = true}) => Text(
      cabecalho ? texto.toUpperCase() : texto,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: cabecalho ? 0.2 : 0,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );

/// Cor de fundo agrupada (cinza-claro do iOS, preto no tema escuro).
Color fundoAgrupado(BuildContext context) => ehIOS(context)
    ? CupertinoColors.systemGroupedBackground.resolveFrom(context)
    : Theme.of(context).scaffoldBackgroundColor;

// ---------------------------------------------------------------------------------------------
// Pagina e barra de topo

/// Tela com barra de topo. No iPhone: barra do iOS (titulo grande nas abas, titulo central e
/// "voltar" com seta nas telas abertas por cima). No Android: Scaffold com AppBar.
class Pagina extends StatelessWidget {
  final String? titulo;
  final bool tituloGrande;
  final List<Widget> acoes;
  final Widget? inicio;
  final Widget corpo;

  const Pagina({
    super.key,
    this.titulo,
    this.tituloGrande = false,
    this.acoes = const [],
    this.inicio,
    required this.corpo,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = acoes.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: acoes);
    if (ehIOS(context)) {
      final barra = tituloGrande
          ? CupertinoNavigationBar.large(
              largeTitle: titulo == null ? null : Text(titulo!),
              leading: inicio,
              trailing: trailing,
            )
          : CupertinoNavigationBar(
              middle: titulo == null ? null : Text(titulo!),
              leading: inicio,
              trailing: trailing,
            );
      return CupertinoPageScaffold(
        backgroundColor: fundoAgrupado(context),
        navigationBar: barra,
        child: SafeArea(
          bottom: false,
          // Alguns widgets basicos (campos de texto) precisam de um ancestral Material; ele e
          // transparente e usa a tipografia do iOS como texto padrao.
          child: Material(
            type: MaterialType.transparency,
            textStyle: CupertinoTheme.of(context).textTheme.textStyle,
            child: corpo,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: titulo == null ? null : Text(titulo!), leading: inicio, actions: acoes),
      body: corpo,
    );
  }
}

/// Botao da barra de topo: texto ("Editar") ou icone ("Sair").
class BotaoTopo extends StatelessWidget {
  final String rotulo;
  final IconData? iconeMaterial;
  final IconData? iconeIOS;
  final VoidCallback? aoTocar;

  const BotaoTopo({super.key, required this.rotulo, this.iconeMaterial, this.iconeIOS, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(36, 36),
        onPressed: aoTocar,
        child: iconeIOS == null ? Text(rotulo) : Icon(iconeIOS, semanticLabel: rotulo),
      );
    }
    return iconeMaterial == null
        ? TextButton(onPressed: aoTocar, child: Text(rotulo))
        : IconButton(tooltip: rotulo, icon: Icon(iconeMaterial), onPressed: aoTocar);
  }
}

// ---------------------------------------------------------------------------------------------
// Botoes

enum _TipoBotao { principal, secundario, texto }

/// Botao de largura total: principal (azul), secundario (azul claro) ou so texto.
class Botao extends StatelessWidget {
  final String texto;
  final IconData? iconeMaterial;
  final IconData? iconeIOS;
  final VoidCallback? aoTocar;
  final bool carregando;
  final bool destrutivo;
  final _TipoBotao _tipo;

  const Botao.principal(this.texto,
      {super.key, this.iconeMaterial, this.iconeIOS, required this.aoTocar, this.carregando = false})
      : _tipo = _TipoBotao.principal,
        destrutivo = false;

  const Botao.secundario(this.texto,
      {super.key, this.iconeMaterial, this.iconeIOS, required this.aoTocar, this.destrutivo = false})
      : _tipo = _TipoBotao.secundario,
        carregando = false;

  const Botao.texto(this.texto,
      {super.key, this.iconeMaterial, this.iconeIOS, required this.aoTocar, this.destrutivo = false})
      : _tipo = _TipoBotao.texto,
        carregando = false;

  @override
  Widget build(BuildContext context) {
    final ios = ehIOS(context);
    final iconeEscolhido = ios ? (iconeIOS ?? iconeMaterial) : iconeMaterial;
    final cor = destrutivo
        ? (ios ? CupertinoColors.destructiveRed.resolveFrom(context) : Theme.of(context).colorScheme.error)
        : null;
    final conteudo = carregando
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconeEscolhido != null) ...[Icon(iconeEscolhido, size: 20, color: cor), const SizedBox(width: 8)],
              Flexible(
                  child:
                      Text(texto, overflow: TextOverflow.ellipsis, style: cor == null ? null : TextStyle(color: cor))),
            ],
          );
    final acao = carregando ? null : aoTocar;

    if (ios) {
      final botao = switch (_tipo) {
        _TipoBotao.principal => CupertinoButton.filled(onPressed: acao, child: conteudo),
        _TipoBotao.secundario => CupertinoButton.tinted(onPressed: acao, child: conteudo),
        _TipoBotao.texto => CupertinoButton(onPressed: acao, child: conteudo),
      };
      return _tipo == _TipoBotao.texto ? botao : SizedBox(width: double.infinity, child: botao);
    }
    final estilo = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)));
    return switch (_tipo) {
      _TipoBotao.principal => FilledButton(onPressed: acao, style: estilo, child: conteudo),
      _TipoBotao.secundario => FilledButton.tonal(onPressed: acao, style: estilo, child: conteudo),
      _TipoBotao.texto => TextButton(onPressed: acao, child: conteudo),
    };
  }
}

// ---------------------------------------------------------------------------------------------
// Listas

/// Grupo de itens. No iPhone: secao arredondada com divisorias finas (como em Ajustes e
/// Contatos). No Android: lista simples.
class SecaoLista extends StatelessWidget {
  final String? cabecalho;
  final String? rodape;
  final List<Widget> children;

  /// Linhas sem icone a esquerda: a divisoria comeca junto do texto (como na ficha do Contatos).
  final bool semIcones;

  const SecaoLista({super.key, this.cabecalho, this.rodape, required this.children, this.semIcones = false});

  /// Sem icone a esquerda em nenhuma linha: a divisoria comeca junto do texto, como nos
  /// Ajustes do iPhone (o padrao do Flutter deixa o recuo de um icone que nao existe).
  bool get _semIcones =>
      semIcones ||
      children.every((w) =>
          (w is ItemLista && w.inicio == null) || (w is CupertinoListTile && w.leading == null));

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (ehIOS(context)) {
      return CupertinoListSection.insetGrouped(
        header: cabecalho == null ? null : _textoSecao(context, cabecalho!),
        footer: rodape == null ? null : _textoSecao(context, rodape!, cabecalho: false),
        backgroundColor: fundoAgrupado(context),
        dividerMargin: _semIcones ? 20 : 14,
        additionalDividerMargin: _semIcones ? 0 : null,
        children: children,
      );
    }
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cabecalho != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(cabecalho!, style: textos.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
        ...children,
        if (rodape != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Text(rodape!, style: textos.bodySmall)),
      ],
    );
  }
}

/// Item de lista com icone, titulo, subtitulo, valor a direita e seta de abrir.
class ItemLista extends StatelessWidget {
  final Widget? inicio;
  final String titulo;
  final String? subtitulo;
  final Color? corSubtitulo;
  final String? valor;
  final Widget? fim;
  final bool seta;
  final VoidCallback? aoTocar;

  const ItemLista({
    super.key,
    this.inicio,
    required this.titulo,
    this.subtitulo,
    this.corSubtitulo,
    this.valor,
    this.fim,
    this.seta = false,
    this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      final trailing = fim ?? (seta ? const CupertinoListTileChevron() : null);
      return CupertinoListTile(
        leading: inicio,
        leadingSize: inicio == null ? 28 : 40,
        title: Text(titulo),
        subtitle: subtitulo == null
            ? null
            : Text(subtitulo!, style: corSubtitulo == null ? null : TextStyle(color: corSubtitulo)),
        additionalInfo: valor == null ? null : Text(valor!),
        trailing: trailing,
        onTap: aoTocar,
      );
    }
    return ListTile(
      leading: inicio,
      title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitulo == null
          ? null
          : Text(subtitulo!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: corSubtitulo)),
      trailing: (valor == null && !seta && fim == null)
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (valor != null) Text(valor!, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (fim != null) fim!,
                if (seta && fim == null) const Icon(Icons.chevron_right),
              ],
            ),
      onTap: aoTocar,
    );
  }
}

/// Circulo com iniciais (cliente) ou sigla (produto), como no app Contatos.
class Avatar extends StatelessWidget {
  final String texto;
  final double tamanho;
  final bool apagado;

  const Avatar(this.texto, {super.key, this.tamanho = 40, this.apagado = false});

  @override
  Widget build(BuildContext context) {
    final ios = ehIOS(context);
    final cores = Theme.of(context).colorScheme;
    // iPhone: azul do sistema bem claro (ou cinza, se "apagado"); Android: cores do Material.
    final fundo = ios
        ? (apagado
            ? CupertinoColors.systemGrey5.resolveFrom(context)
            : CupertinoColors.systemBlue.resolveFrom(context).withValues(alpha: 0.15))
        : (apagado ? cores.surfaceContainerHighest : cores.primaryContainer);
    final frente = ios
        ? (apagado
            ? CupertinoColors.secondaryLabel.resolveFrom(context)
            : CupertinoColors.systemBlue.resolveFrom(context))
        : (apagado ? cores.onSurfaceVariant : cores.onPrimaryContainer);
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fundo),
      child: Text(
        texto,
        style: TextStyle(
          color: frente,
          fontSize: tamanho * 0.36,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Formularios

/// Grupo de campos. No iPhone: secao de formulario arredondada (como editar um contato).
class SecaoFormulario extends StatelessWidget {
  final String? cabecalho;
  final String? rodape;
  final List<Widget> children;

  const SecaoFormulario({super.key, this.cabecalho, this.rodape, required this.children});

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return CupertinoFormSection.insetGrouped(
        header: cabecalho == null ? null : _textoSecao(context, cabecalho!),
        footer: rodape == null ? null : _textoSecao(context, rodape!, cabecalho: false),
        backgroundColor: fundoAgrupado(context),
        children: children,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cabecalho != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(cabecalho!, style: Theme.of(context).textTheme.titleSmall),
            ),
          for (final (i, campo) in children.indexed) ...[if (i > 0) const SizedBox(height: 12), campo],
          if (rodape != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(rodape!, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Campo de texto com validacao. No iPhone: linha de formulario com o rotulo a esquerda.
class CampoTexto extends StatelessWidget {
  final TextEditingController controle;
  final String rotulo;
  final String? dica;
  final TextInputType? teclado;
  final TextInputAction? acaoTeclado;
  final TextCapitalization maiusculas;
  final bool oculto;
  final int maxLinhas;
  final Widget? sufixo;
  final Iterable<String>? preenchimento;
  final String? Function(String texto)? validar;
  final ValueChanged<String>? aoConfirmar;

  const CampoTexto({
    super.key,
    required this.controle,
    required this.rotulo,
    this.dica,
    this.teclado,
    this.acaoTeclado,
    this.maiusculas = TextCapitalization.none,
    this.oculto = false,
    this.maxLinhas = 1,
    this.sufixo,
    this.preenchimento,
    this.validar,
    this.aoConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return FormField<String>(
        initialValue: controle.text,
        validator: validar == null ? null : (_) => validar!(controle.text),
        builder: (estado) => CupertinoFormRow(
          prefix: SizedBox(width: 96, child: Text(rotulo)),
          error: estado.hasError ? Text(estado.errorText!) : null,
          child: CupertinoTextField.borderless(
            controller: controle,
            placeholder: dica ?? rotulo,
            keyboardType: teclado,
            textInputAction: acaoTeclado,
            textCapitalization: maiusculas,
            obscureText: oculto,
            maxLines: oculto ? 1 : maxLinhas,
            minLines: 1,
            suffix: sufixo,
            autofillHints: preenchimento,
            onSubmitted: aoConfirmar,
            onChanged: (texto) {
              estado.didChange(texto);
              if (estado.hasError) estado.validate();
            },
          ),
        ),
      );
    }
    return TextFormField(
      controller: controle,
      decoration: InputDecoration(labelText: rotulo, hintText: dica, suffixIcon: sufixo),
      keyboardType: teclado,
      textInputAction: acaoTeclado,
      textCapitalization: maiusculas,
      obscureText: oculto,
      maxLines: oculto ? 1 : maxLinhas,
      autofillHints: preenchimento,
      onFieldSubmitted: aoConfirmar,
      validator: validar == null ? null : (v) => validar!(v ?? ''),
    );
  }
}

/// Escolha de uma opcao de uma lista (cliente, categoria, forma de pagamento...).
/// No iPhone: linha com o valor escolhido e seta, que abre uma lista com marcacao (como em
/// Ajustes). No Android: menu suspenso.
class Seletor<T> extends StatelessWidget {
  final String rotulo;
  final T? valor;
  final Map<T, String> opcoes;
  final ValueChanged<T> aoMudar;
  final String? Function(T? valor)? validar;

  const Seletor(
      {super.key,
      required this.rotulo,
      required this.valor,
      required this.opcoes,
      required this.aoMudar,
      this.validar});

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return FormField<T>(
        key: ValueKey('$rotulo-$valor'),
        initialValue: valor,
        validator: validar,
        builder: (estado) => CupertinoFormRow(
          error: estado.hasError ? Text(estado.errorText!) : null,
          padding: EdgeInsets.zero,
          child: CupertinoListTile(
            title: Text(rotulo),
            additionalInfo: Text(valor == null ? 'Escolher' : (opcoes[valor] ?? '')),
            trailing: const CupertinoListTileChevron(),
            onTap: () async {
              final escolhido = await Navigator.of(context).push<T>(
                CupertinoPageRoute(builder: (_) => _ListaDeEscolha<T>(titulo: rotulo, opcoes: opcoes, atual: valor)),
              );
              if (escolhido != null) {
                aoMudar(escolhido);
                estado.didChange(escolhido);
              }
            },
          ),
        ),
      );
    }
    return DropdownButtonFormField<T>(
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: rotulo),
      items: [for (final o in opcoes.entries) DropdownMenuItem(value: o.key, child: Text(o.value))],
      onChanged: (v) {
        if (v != null) aoMudar(v);
      },
      validator: validar,
    );
  }
}

class _ListaDeEscolha<T> extends StatelessWidget {
  final String titulo;
  final Map<T, String> opcoes;
  final T? atual;

  const _ListaDeEscolha({required this.titulo, required this.opcoes, required this.atual});

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: titulo,
      corpo: ListView(
        children: [
          SecaoLista(children: [
            for (final o in opcoes.entries)
              CupertinoListTile(
                title: Text(o.value),
                trailing: o.key == atual ? const Icon(CupertinoIcons.check_mark) : null,
                onTap: () => Navigator.of(context).pop(o.key),
              ),
          ]),
        ],
      ),
    );
  }
}

/// Controle segmentado (ex.: Varejo | Atacado).
class Segmentado<T extends Object> extends StatelessWidget {
  final Map<T, String> opcoes;
  final T selecionado;
  final ValueChanged<T> aoMudar;

  const Segmentado({super.key, required this.opcoes, required this.selecionado, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: selecionado,
        children: {
          for (final o in opcoes.entries)
            o.key: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(o.value))
        },
        onValueChanged: (v) {
          if (v != null) aoMudar(v);
        },
      );
    }
    return SegmentedButton<T>(
      segments: [for (final o in opcoes.entries) ButtonSegment(value: o.key, label: Text(o.value))],
      selected: {selecionado},
      onSelectionChanged: (s) => aoMudar(s.first),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Alertas, menus de acao, folhas e mensagens

/// Pergunta de confirmacao. No iPhone: alerta do iOS (acao destrutiva em vermelho).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String acao,
  String cancelar = 'Cancelar',
  bool destrutivo = true,
}) async {
  if (ehIOS(context)) {
    final resposta = await showCupertinoDialog<bool>(
      context: context,
      builder: (contexto) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          CupertinoDialogAction(
              isDefaultAction: true, onPressed: () => Navigator.pop(contexto, false), child: Text(cancelar)),
          CupertinoDialogAction(
              isDestructiveAction: destrutivo, onPressed: () => Navigator.pop(contexto, true), child: Text(acao)),
        ],
      ),
    );
    return resposta == true;
  }
  final resposta = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(onPressed: () => Navigator.pop(contexto, false), child: Text(cancelar)),
        FilledButton(
          style: destrutivo ? FilledButton.styleFrom(backgroundColor: Theme.of(contexto).colorScheme.error) : null,
          onPressed: () => Navigator.pop(contexto, true),
          child: Text(acao),
        ),
      ],
    ),
  );
  return resposta == true;
}

/// Uma opcao de um menu de acoes.
class OpcaoAcao<T> {
  final T valor;
  final String texto;
  final IconData iconeMaterial;
  final bool destrutiva;

  const OpcaoAcao(this.valor, this.texto, this.iconeMaterial, {this.destrutiva = false});
}

/// Menu de acoes. No iPhone: folha de acoes do iOS que sobe de baixo, com "Cancelar".
Future<T?> escolherAcao<T>(BuildContext context,
    {String? titulo, String? mensagem, required List<OpcaoAcao<T>> opcoes}) {
  if (ehIOS(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (contexto) => CupertinoActionSheet(
        title: titulo == null ? null : Text(titulo),
        message: mensagem == null ? null : Text(mensagem),
        actions: [
          for (final o in opcoes)
            CupertinoActionSheetAction(
              isDestructiveAction: o.destrutiva,
              onPressed: () => Navigator.pop(contexto, o.valor),
              child: Text(o.texto),
            ),
        ],
        cancelButton:
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (contexto) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titulo != null)
            ListTile(
                title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: mensagem == null ? null : Text(mensagem)),
          for (final o in opcoes)
            ListTile(
              leading: Icon(o.iconeMaterial, color: o.destrutiva ? Theme.of(contexto).colorScheme.error : null),
              title: Text(o.texto, style: o.destrutiva ? TextStyle(color: Theme.of(contexto).colorScheme.error) : null),
              onTap: () => Navigator.pop(contexto, o.valor),
            ),
        ],
      ),
    ),
  );
}

/// Abre uma folha por cima de tudo (inclusive da barra inferior). No iPhone: folha do iOS que
/// sobe e deixa a tela de tras recuada; no Android: folha inferior do Material.
Future<T?> abrirFolha<T>(BuildContext context,
    {required Widget Function(BuildContext contexto, ScrollController? rolagem) construir}) {
  if (ehIOS(context)) {
    return showCupertinoSheet<T>(
      context: context,
      scrollableBuilder: (contexto, rolagem) => construir(contexto, rolagem),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (contexto) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (contexto, rolagem) => construir(contexto, rolagem),
    ),
  );
}

/// Conteudo de uma folha: titulo, botao de fechar (e de confirmar) e o corpo rolavel.
class Folha extends StatelessWidget {
  final String titulo;
  final String fechar;
  final Widget? acao;
  final List<Widget> children;
  final ScrollController? rolagem;
  final Widget? rodape;

  /// O que fazer ao tocar em "Fechar" (padrao: fechar sem resultado).
  final VoidCallback? aoFechar;

  const Folha({
    super.key,
    required this.titulo,
    this.fechar = 'Fechar',
    this.acao,
    required this.children,
    this.rolagem,
    this.rodape,
    this.aoFechar,
  });

  @override
  Widget build(BuildContext context) {
    final lista = ListView(controller: rolagem, padding: const EdgeInsets.only(bottom: 24), children: children);
    if (ehIOS(context)) {
      return CupertinoPageScaffold(
        backgroundColor: fundoAgrupado(context),
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          middle: Text(titulo),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: aoFechar ?? () => Navigator.of(context).pop(),
            child: Text(fechar),
          ),
          trailing: acao,
        ),
        child: SafeArea(
          child: Material(
            type: MaterialType.transparency,
            textStyle: CupertinoTheme.of(context).textTheme.textStyle,
            child: Column(children: [Expanded(child: lista), if (rodape != null) rodape!]),
          ),
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(titulo,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                  if (acao != null) acao!,
                  TextButton(onPressed: aoFechar ?? () => Navigator.of(context).pop(), child: Text(fechar)),
                ],
              ),
            ),
            Expanded(child: lista),
            if (rodape != null) rodape!,
          ],
        ),
      ),
    );
  }
}

/// Mensagem rapida. No iPhone: aviso discreto que aparece e some sozinho (o iOS nao tem
/// "snackbar"); no Android: snackbar do Material.
void mostrarMensagem(BuildContext context, String mensagem) {
  if (!ehIOS(context)) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
    return;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entrada;
  entrada = OverlayEntry(builder: (_) => _Aviso(mensagem: mensagem, aoTerminar: () => entrada.remove()));
  overlay.insert(entrada);
}

class _Aviso extends StatefulWidget {
  final String mensagem;
  final VoidCallback aoTerminar;

  const _Aviso({required this.mensagem, required this.aoTerminar});

  @override
  State<_Aviso> createState() => _AvisoState();
}

class _AvisoState extends State<_Aviso> {
  bool _visivel = false;
  Timer? _tempo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visivel = true);
    });
    _tempo = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _visivel = false);
      Timer(const Duration(milliseconds: 300), widget.aoTerminar);
    });
  }

  @override
  void dispose() {
    _tempo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final escuro = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.paddingOf(context).bottom + 96,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visivel ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: (escuro ? const Color(0xFF3A3A3C) : const Color(0xFF1C1C1E)).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  widget.mensagem,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Deslizar para apagar (iPhone)

/// Linha que, ao deslizar para a esquerda, revela o botao vermelho "Apagar", como nas listas
/// do iPhone (Mail, Contatos, Notas). Tocar no botao, ou deslizar ate o fim, pede a
/// confirmacao. So uma linha fica aberta por vez, e tocar na linha aberta a fecha.
/// (O Flutter nao traz esse componente pronto; este segue o comportamento do iOS.)
class DeslizarParaApagarIOS extends StatefulWidget {
  final Future<bool> Function() aoApagar;
  final VoidCallback aoRemover;
  final Widget child;

  const DeslizarParaApagarIOS({super.key, required this.aoApagar, required this.aoRemover, required this.child});

  @override
  State<DeslizarParaApagarIOS> createState() => _DeslizarParaApagarIOSState();
}

/// Linha aberta no momento (abrir outra fecha esta).
final _linhaAberta = ValueNotifier<Object?>(null);

class _DeslizarParaApagarIOSState extends State<DeslizarParaApagarIOS> with SingleTickerProviderStateMixin {
  static const _larguraBotao = 88.0;
  late final _animacao = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  final _chave = Object();
  double _deslocamento = 0; // negativo: linha puxada para a esquerda
  double _inicioAnimacao = 0;
  double _fimAnimacao = 0;
  double _largura = 0;
  bool _apagando = false;

  @override
  void initState() {
    super.initState();
    _animacao.addListener(() {
      setState(() => _deslocamento =
          _inicioAnimacao + (_fimAnimacao - _inicioAnimacao) * Curves.easeOut.transform(_animacao.value));
    });
    _linhaAberta.addListener(_outraAbriu);
  }

  @override
  void dispose() {
    _linhaAberta.removeListener(_outraAbriu);
    if (_linhaAberta.value == _chave) _linhaAberta.value = null;
    _animacao.dispose();
    super.dispose();
  }

  void _outraAbriu() {
    if (_linhaAberta.value != _chave && _deslocamento != 0 && !_apagando) _animarPara(0);
  }

  Future<void> _animarPara(double destino) {
    _inicioAnimacao = _deslocamento;
    _fimAnimacao = destino;
    return _animacao.forward(from: 0);
  }

  void _arrastando(DragUpdateDetails d) {
    if (_apagando) return;
    setState(() => _deslocamento = (_deslocamento + d.delta.dx).clamp(-_largura, 0.0));
  }

  void _soltou(DragEndDetails d) {
    if (_apagando) return;
    final rapido = d.velocity.pixelsPerSecond.dx < -900;
    if (_deslocamento < -_largura * 0.6) {
      _apagar();
    } else if (_deslocamento < -_larguraBotao / 2 || rapido) {
      _linhaAberta.value = _chave;
      _animarPara(-_larguraBotao);
    } else {
      _animarPara(0);
    }
  }

  Future<void> _apagar() async {
    _apagando = true;
    _linhaAberta.value = _chave;
    await _animarPara(-_largura);
    final apagou = await widget.aoApagar();
    if (!mounted) return;
    _apagando = false;
    if (apagou) {
      widget.aoRemover();
    } else {
      _animarPara(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vermelho = CupertinoColors.systemRed.resolveFrom(context);
    final aberta = _deslocamento != 0;
    return LayoutBuilder(builder: (context, limites) {
      _largura = limites.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: _arrastando,
        onHorizontalDragEnd: _soltou,
        child: Stack(
          children: [
            // Botao "Apagar" atras da linha; cresce conforme a linha e puxada. Fechada, a linha
            // nao tem botao (nem para o VoiceOver).
            if (aberta)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: -_deslocamento,
                    child: Semantics(
                      button: true,
                      label: 'Apagar',
                      child: GestureDetector(
                        onTap: _apagando ? null : _apagar,
                        child: ColoredBox(
                          color: vermelho,
                          child: ClipRect(
                            child: OverflowBox(
                              maxWidth: double.infinity,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(CupertinoIcons.trash, color: CupertinoColors.white, size: 22),
                                  SizedBox(height: 2),
                                  Text('Apagar', style: TextStyle(color: CupertinoColors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(_deslocamento, 0),
              child: Stack(
                children: [
                  widget.child,
                  // Com a linha aberta, tocar nela so fecha (como no iOS).
                  if (aberta)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _animarPara(0),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------------------------
// Lista com "puxar para atualizar"

/// Lista rolavel que atualiza ao ser puxada para baixo: no iPhone, o controle do iOS (a
/// rodinha aparece no topo enquanto a lista "estica"); no Android, o indicador do Material.
class ListaAtualizavel extends StatelessWidget {
  final Future<void> Function() aoAtualizar;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const ListaAtualizavel(
      {super.key, required this.aoAtualizar, required this.children, this.padding = const EdgeInsets.only(bottom: 24)});

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: aoAtualizar),
          SliverPadding(padding: padding, sliver: SliverList(delegate: SliverChildListDelegate(children))),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: aoAtualizar,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Tipografia e cores de cada sistema

/// Estilos de texto: no iPhone, a tipografia do iOS (San Francisco, tamanhos da Apple); no
/// Android, a escala do Material 3.
// textBaseline e exigido por alguns widgets (ex.: texto selecionavel) quando inherit e false.
TextStyle _base(BuildContext c) => CupertinoTheme.of(c).textTheme.textStyle.copyWith(textBaseline: TextBaseline.alphabetic);

TextStyle estiloTituloGrande(BuildContext c) => ehIOS(c)
    ? _base(c).copyWith(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4)
    : Theme.of(c).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700);

TextStyle estiloTitulo(BuildContext c) => ehIOS(c)
    ? _base(c).copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3)
    : Theme.of(c).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600);

TextStyle estiloSubtitulo(BuildContext c) => ehIOS(c)
    ? _base(c).copyWith(fontSize: 17, fontWeight: FontWeight.w600)
    : Theme.of(c).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);

TextStyle estiloCorpo(BuildContext c) => ehIOS(c) ? _base(c) : Theme.of(c).textTheme.bodyLarge!;

TextStyle estiloSecundario(BuildContext c) => ehIOS(c)
    ? _base(c).copyWith(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(c))
    : Theme.of(c).textTheme.bodyMedium!.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant);

TextStyle estiloLegenda(BuildContext c) => ehIOS(c)
    ? _base(c).copyWith(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(c))
    : Theme.of(c).textTheme.bodySmall!;

/// Cor do sistema: a do iOS (que muda sozinha no modo escuro) ou a do Material.
Color corDoSistema(BuildContext c, CupertinoDynamicColor ios, Color material) =>
    ehIOS(c) ? ios.resolveFrom(c) : material;

Color corVerde(BuildContext c) => corDoSistema(c, CupertinoColors.systemGreen, Colors.green);
Color corVermelha(BuildContext c) => corDoSistema(c, CupertinoColors.systemRed, Theme.of(c).colorScheme.error);
Color corLaranja(BuildContext c) => corDoSistema(c, CupertinoColors.systemOrange, Colors.orange);
Color corAzul(BuildContext c) => corDoSistema(c, CupertinoColors.systemBlue, Colors.blue);
Color corIndigo(BuildContext c) => corDoSistema(c, CupertinoColors.systemIndigo, Colors.indigo);
Color corTeal(BuildContext c) => corDoSistema(c, CupertinoColors.systemTeal, Colors.teal);
Color corCinza(BuildContext c) => corDoSistema(c, CupertinoColors.systemGrey, Colors.grey);

/// Cor de destaque da marca (azul ModaMax).
Color corDestaque(BuildContext c) => ehIOS(c) ? CupertinoTheme.of(c).primaryColor : Theme.of(c).colorScheme.primary;

/// Fundo de trilhos e barras vazias.
Color corTrilho(BuildContext c) =>
    corDoSistema(c, CupertinoColors.systemGrey5, Theme.of(c).colorScheme.surfaceContainerHighest);

/// Botao so com icone (ex.: + e - da quantidade).
class BotaoIcone extends StatelessWidget {
  final IconData iconeMaterial;
  final IconData iconeIOS;
  final String dica;
  final VoidCallback? aoTocar;

  const BotaoIcone(
      {super.key, required this.iconeMaterial, required this.iconeIOS, required this.dica, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return Semantics(
        button: true,
        label: dica,
        child: CupertinoButton(
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(36, 36),
          onPressed: aoTocar,
          child: Icon(iconeIOS, size: 26),
        ),
      );
    }
    return IconButton(tooltip: dica, icon: Icon(iconeMaterial), onPressed: aoTocar);
  }
}
