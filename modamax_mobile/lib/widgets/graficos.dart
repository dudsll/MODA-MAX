import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import 'adaptativo.dart';

/// Grafico de barras feito so com widgets do Flutter (sem pacote externo).
/// Cada barra tem um rotulo de acessibilidade com o valor, lido pelo leitor de tela.
class GraficoBarras extends StatelessWidget {
  final String titulo;
  final List<PontoGrafico> pontos;
  final String Function(double valor) formatar;
  final bool horizontal;

  const GraficoBarras({
    super.key,
    required this.titulo,
    required this.pontos,
    required this.formatar,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final maximo = pontos.fold<double>(0, (m, p) => p.valor > m ? p.valor : m);

    // Sem cartao proprio: quem usa decide o fundo (cartao do painel no iPhone e no Android).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: estiloSubtitulo(context)),
        const SizedBox(height: 16),
        if (pontos.isEmpty || maximo == 0)
          const Text('Sem dados no período.')
        else if (horizontal)
          ...pontos.map((p) => _barraHorizontal(context, p, maximo))
        else
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: pontos.map((p) => Expanded(child: _barraVertical(context, p, maximo))).toList(),
            ),
          ),
      ],
    );
  }

  Widget _barraVertical(BuildContext context, PontoGrafico p, double maximo) {
    return Semantics(
      label: '${p.rotulo}: ${formatar(p.valor)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: (p.valor / maximo).clamp(0.02, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: corDestaque(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(p.rotulo, style: estiloLegenda(context).copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _barraHorizontal(BuildContext context, PontoGrafico p, double maximo) {
    return Semantics(
      label: '${p.rotulo}: ${formatar(p.valor)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(formatar(p.valor), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.valor / maximo,
                minHeight: 10,
                color: corDoSistema(context, CupertinoColors.systemIndigo, Theme.of(context).colorScheme.tertiary),
                backgroundColor: corTrilho(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
