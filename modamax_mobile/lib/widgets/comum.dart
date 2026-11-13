import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import 'adaptativo.dart';

export 'adaptativo.dart';

/// Mostra carregamento, erro (com botao de tentar de novo) ou o conteudo,
/// e permite puxar a lista para baixo para sincronizar com a API.
class CarregarDados<T> extends StatelessWidget {
  final Future<Dados<T>> futuro;
  final Future<void> Function() aoAtualizar;
  final Widget Function(Dados<T> dados) construir;

  const CarregarDados({super.key, required this.futuro, required this.aoAtualizar, required this.construir});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Dados<T>>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snapshot.hasError) {
          final erro = snapshot.error;
          if (erro is ApiException && erro.naoAutorizado) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await ApiService.instancia.logout();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            });
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone(context, material: Icons.cloud_off, ios: CupertinoIcons.wifi_slash), size: 48),
                  const SizedBox(height: 12),
                  Text('$erro', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Botao.secundario('Tentar novamente', aoTocar: aoAtualizar),
                ],
              ),
            ),
          );
        }

        // Quem usa monta a lista com ListaAtualizavel (puxar para atualizar de cada sistema).
        return construir(snapshot.data as Dados<T>);
      },
    );
  }
}

class AvisoOffline extends StatelessWidget {
  final DateTime? sincronizadoEm;

  const AvisoOffline({super.key, this.sincronizadoEm});

  @override
  Widget build(BuildContext context) {
    final quando = sincronizadoEm == null
        ? ''
        : ' Última sincronização: ${formatarData(sincronizadoEm!)} '
            '${sincronizadoEm!.hour.toString().padLeft(2, '0')}:${sincronizadoEm!.minute.toString().padLeft(2, '0')}.';

    return SecaoLista(children: [
      ItemLista(
        inicio: Icon(icone(context, material: Icons.wifi_off, ios: CupertinoIcons.wifi_slash), color: corLaranja(context)),
        titulo: 'Modo offline',
        subtitulo: 'Mostrando dados salvos no aparelho.$quando',
      ),
    ]);
  }
}

/// Campo de busca no padrao do iPhone (cinza, arredondado, lupa e "x" para limpar).
/// Busca ao confirmar no teclado; limpar o campo volta a lista completa.
class CampoBusca extends StatefulWidget {
  final String dica;
  final ValueChanged<String> aoBuscar;

  /// Busca atual: a lista recarrega a cada busca e o campo e recriado; sem isto ele voltaria
  /// vazio com a lista ainda filtrada.
  final String? texto;

  const CampoBusca({super.key, required this.dica, required this.aoBuscar, this.texto});

  @override
  State<CampoBusca> createState() => _CampoBuscaState();
}

class _CampoBuscaState extends State<CampoBusca> {
  late final _controle = TextEditingController(text: widget.texto);

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ehIOS(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SearchBar(
          controller: _controle,
          hintText: widget.dica,
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          onSubmitted: widget.aoBuscar,
          onChanged: (texto) {
            if (texto.isEmpty) widget.aoBuscar('');
          },
          trailing: [
            IconButton(
              tooltip: 'Limpar busca',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controle.clear();
                widget.aoBuscar('');
              },
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: CupertinoSearchTextField(
        controller: _controle,
        placeholder: widget.dica,
        onSubmitted: widget.aoBuscar,
        onSuffixTap: () {
          _controle.clear();
          widget.aoBuscar('');
        },
        onChanged: (texto) {
          if (texto.isEmpty) widget.aoBuscar('');
        },
      ),
    );
  }
}

/// Botao principal de cadastro no topo das listas (Produtos, Clientes, Pedidos): largura
/// total e cantos arredondados, no estilo dos apps do iPhone, em vez de botao flutuante.
class BotaoNovo extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;

  const BotaoNovo({super.key, required this.texto, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    // Mesma margem das secoes de lista (20 no iPhone, 16 no Android).
    final margem = ehIOS(context) ? 20.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(margem, 4, margem, 8),
      child: Botao.principal(texto, iconeMaterial: Icons.add, iconeIOS: CupertinoIcons.add, aoTocar: aoTocar),
    );
  }
}

/// Pergunta antes de excluir; devolve true so quando o usuario confirma.
Future<bool> confirmarExclusao(BuildContext context, {required String titulo, required String mensagem}) =>
    confirmar(context, titulo: titulo, mensagem: mensagem, acao: 'Apagar');

/// Botao vermelho de apagar no fim da tela de edicao, como "Apagar Contato" no app Contatos.
class BotaoApagar extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;

  const BotaoApagar({super.key, required this.texto, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return SecaoLista(children: [
        CupertinoListTile(
          title: Text(texto, style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context))),
          onTap: aoTocar,
        ),
      ]);
    }
    final cores = Theme.of(context).colorScheme;
    return Material(
      color: cores.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(texto, style: TextStyle(color: cores.error, fontSize: 17)),
        ),
      ),
    );
  }
}

/// Item de lista que pode ser apagado arrastando para a esquerda (aparece a lixeira vermelha).
/// [aoApagar] pede a confirmacao e chama a API; devolve true se apagou.
class ArrastarParaApagar extends StatelessWidget {
  final Key chave;
  final bool permitido;
  final Future<bool> Function() aoApagar;
  final VoidCallback aoRemover;
  final Widget child;

  const ArrastarParaApagar({
    super.key,
    required this.chave,
    required this.permitido,
    required this.aoApagar,
    required this.aoRemover,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!permitido) return child;
    // iPhone: deslizar revela o botao "Apagar" (padrao do iOS). Android: arrastar e soltar.
    if (ehIOS(context)) {
      return DeslizarParaApagarIOS(key: chave, aoApagar: aoApagar, aoRemover: aoRemover, child: child);
    }
    return Dismissible(
      key: chave,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => aoApagar(),
      onDismissed: (_) => aoRemover(),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone(context, material: Icons.delete_outline, ios: CupertinoIcons.trash), color: Colors.white),
            const SizedBox(height: 2),
            const Text('Apagar', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Como uma tela de edicao terminou: salvou as alteracoes ou apagou o registro.
enum ResultadoEdicao { salvo, apagado }
