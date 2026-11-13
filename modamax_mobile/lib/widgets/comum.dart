import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';

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
          return const Center(child: CircularProgressIndicator());
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
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  Text('$erro', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: aoAtualizar, child: const Text('Tentar novamente')),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(onRefresh: aoAtualizar, child: construir(snapshot.data as Dados<T>));
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

    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: ListTile(
        leading: const Icon(Icons.wifi_off),
        title: const Text('Modo offline'),
        subtitle: Text('Mostrando dados salvos no aparelho.$quando'),
      ),
    );
  }
}

class CampoBusca extends StatelessWidget {
  final String dica;
  final ValueChanged<String> aoBuscar;

  const CampoBusca({super.key, required this.dica, required this.aoBuscar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: dica,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: aoBuscar,
      ),
    );
  }
}

void mostrarMensagem(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
}

/// Botao principal de cadastro no topo das listas (Produtos, Clientes, Pedidos): largura
/// total e cantos arredondados, no estilo dos apps do iPhone, em vez de botao flutuante.
class BotaoNovo extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;

  const BotaoNovo({super.key, required this.texto, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: FilledButton.icon(
        onPressed: aoTocar,
        icon: const Icon(Icons.add),
        label: Text(texto),
      ),
    );
  }
}

/// Pergunta antes de excluir; devolve true so quando o usuario confirma.
Future<bool> confirmarExclusao(BuildContext context, {required String titulo, required String mensagem}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(contexto).colorScheme.error),
          onPressed: () => Navigator.pop(contexto, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return resposta == true;
}

/// Botao vermelho de apagar no fim da tela de edicao, como "Apagar Contato" no app Contatos.
class BotaoApagar extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;

  const BotaoApagar({super.key, required this.texto, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
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
    return Dismissible(
      key: chave,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => aoApagar(),
      onDismissed: (_) => aoRemover(),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(height: 2),
            Text('Apagar', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Como uma tela de edicao terminou: salvou as alteracoes ou apagou o registro.
enum ResultadoEdicao { salvo, apagado }
