import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import 'adaptativo.dart';

/// Aneis de meta no estilo do app Atividade (Apple Watch): faturamento, pedidos e pecas.
/// Desenhados com CustomPainter, sem pacotes extras.
class AneisMeta extends StatelessWidget {
  final MetaAtual meta;

  const AneisMeta({super.key, required this.meta});

  static const cores = [Color(0xFFFA114F), Color(0xFF5EC11D), Color(0xFF00A8E8)];

  @override
  Widget build(BuildContext context) {
    final itens = [
      ('Faturamento', meta.faturamento, '${formatarMoeda(meta.faturamento.realizado)} de ${formatarMoeda(meta.faturamento.meta)}'),
      ('Pedidos', meta.pedidos, '${meta.pedidos.realizado.toStringAsFixed(0)} de ${meta.pedidos.meta.toStringAsFixed(0)}'),
      ('Peças', meta.pecas, '${meta.pecas.realizado.toStringAsFixed(0)} de ${meta.pecas.meta.toStringAsFixed(0)}'),
    ];

    return Semantics(
      label: 'Metas de ${meta.mes}: ${itens.map((i) => '${i.$1} ${i.$2.percentualExibido}%').join(', ')}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 128,
            height: 128,
            child: CustomPaint(
              painter: _PintorAneis([for (final i in itens) i.$2.percentualExibido / 100]),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var n = 0; n < itens.length; n++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: cores[n], shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(itens[n].$1, style: estiloLegenda(context)),
                              Text(itens[n].$3, style: estiloCorpo(context).copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text('${itens[n].$2.percentualExibido}%', style: estiloSubtitulo(context).copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PintorAneis extends CustomPainter {
  final List<double> progresso;

  _PintorAneis(this.progresso);

  @override
  void paint(Canvas canvas, Size size) {
    const espessura = 13.0;
    final centro = size.center(Offset.zero);
    for (var i = 0; i < progresso.length; i++) {
      final raio = size.width / 2 - espessura / 2 - i * (espessura + 3);
      final retangulo = Rect.fromCircle(center: centro, radius: raio);
      final cor = AneisMeta.cores[i];
      final trilho = Paint()
        ..color = cor.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura;
      final arco = Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(centro, raio, trilho);
      final angulo = 2 * math.pi * progresso[i].clamp(0.0, 1.0);
      if (angulo > 0) canvas.drawArc(retangulo, -math.pi / 2, angulo, false, arco);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorAneis antigo) => antigo.progresso != progresso;
}
