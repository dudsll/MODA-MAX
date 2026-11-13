import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modamax_mobile/widgets/adaptativo.dart';

void main() {
  testWidgets('deslizar revela Apagar e tocar nele pede a confirmacao', (tester) async {
    var pediu = 0;
    var removeu = false;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: CupertinoPageScaffold(
        child: ListView(children: [
          // Duas linhas: o botao da linha fechada nao pode existir (nem para o VoiceOver).
          DeslizarParaApagarIOS(aoApagar: () async => false, aoRemover: () {}, child: const CupertinoListTile(title: Text('Outra'))),
          DeslizarParaApagarIOS(
            aoApagar: () async {
              pediu++;
              return true;
            },
            aoRemover: () => removeu = true,
            child: const CupertinoListTile(title: Text('Linha')),
          ),
        ]),
      ),
    ));
    expect(find.text('Apagar'), findsNothing);
    await tester.drag(find.text('Linha'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Apagar'), findsOneWidget);
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(pediu, 1);
    expect(removeu, isTrue);
  });
}
