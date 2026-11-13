import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../codigo_barras.dart';
import '../widgets/adaptativo.dart';

/// Abre a camera e devolve o codigo de barras lido (EAN/GTIN com digito verificador valido).
/// Tambem permite digitar o codigo: ajuda quem nao consegue mirar a camera e funciona no emulador.
class LeitorCodigoScreen extends StatefulWidget {
  final String titulo;

  const LeitorCodigoScreen({super.key, this.titulo = 'Ler código de barras'});

  static Future<String?> abrir(BuildContext context, {String titulo = 'Ler código de barras'}) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => LeitorCodigoScreen(titulo: titulo)));

  @override
  State<LeitorCodigoScreen> createState() => _LeitorCodigoScreenState();
}

class _LeitorCodigoScreenState extends State<LeitorCodigoScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.itf],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _concluido = false;

  void _aoDetectar(BarcodeCapture captura) {
    if (_concluido) return;
    for (final barcode in captura.barcodes) {
      final codigo = normalizarCodigoBarras(barcode.rawValue);
      // Leituras parciais ou borradas falham no digito verificador e sao ignoradas.
      if (codigoBarrasValido(codigo)) {
        _concluido = true;
        Navigator.of(context).pop(codigo);
        return;
      }
    }
  }

  Future<void> _digitar() async {
    final codigo = ehIOS(context)
        ? await showCupertinoDialog<String>(context: context, builder: (_) => const _DialogoCodigo())
        : await showDialog<String>(context: context, builder: (_) => const _DialogoCodigo());
    if (codigo != null && mounted) {
      _concluido = true;
      Navigator.of(context).pop(codigo);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      titulo: widget.titulo,
      acoes: [
        BotaoTopo(
          rotulo: 'Lanterna',
          iconeMaterial: Icons.flashlight_on,
          iconeIOS: CupertinoIcons.bolt_fill,
          aoTocar: _controller.toggleTorch,
        ),
      ],
      corpo: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            MobileScanner(controller: _controller, onDetect: _aoDetectar),
            // Moldura que indica onde posicionar a etiqueta.
            Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Aponte a câmera para o código de barras da etiqueta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Botao.principal(
                      'Digitar o código',
                      iconeMaterial: Icons.keyboard,
                      iconeIOS: CupertinoIcons.keyboard,
                      aoTocar: _digitar,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoCodigo extends StatefulWidget {
  const _DialogoCodigo();

  @override
  State<_DialogoCodigo> createState() => _DialogoCodigoState();
}

class _DialogoCodigoState extends State<_DialogoCodigo> {
  final _texto = TextEditingController();
  String? _erro;

  void _confirmar() {
    final codigo = normalizarCodigoBarras(_texto.text);
    if (!codigoBarrasValido(codigo)) {
      setState(() => _erro = 'Código inválido. Confira os números da etiqueta.');
      return;
    }
    Navigator.of(context).pop(codigo);
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ehIOS(context)) {
      return CupertinoAlertDialog(
        title: const Text('Digitar código de barras'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _texto,
                autofocus: true,
                placeholder: 'EAN/GTIN',
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _confirmar(),
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_erro!, style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context), fontSize: 13)),
                ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: _confirmar, child: const Text('Buscar')),
        ],
      );
    }
    return AlertDialog(
      title: const Text('Digitar código de barras'),
      content: TextField(
        controller: _texto,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'EAN/GTIN', errorText: _erro),
        onSubmitted: (_) => _confirmar(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirmar, child: const Text('Buscar')),
      ],
    );
  }
}
