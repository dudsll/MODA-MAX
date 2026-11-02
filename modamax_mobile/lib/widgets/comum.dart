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
              Navigator.of(context).pushAndRemoveUntil(
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
        : ' Ultima sincronizacao: ${formatarData(sincronizadoEm!)} '
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
