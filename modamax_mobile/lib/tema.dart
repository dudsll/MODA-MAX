import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Azul jeans da marca, o mesmo da Web.
const _azul = Color(0xFF0071E3);

/// Tema do app. No iPhone, as telas usam os componentes Cupertino e este tema so completa o
/// que eles nao cobrem (fundo agrupado cinza-claro, cartoes brancos, como na Web). No Android,
/// e o Material 3 padrao do Google, com as cores geradas a partir do azul da marca.
ThemeData temaModaMax(Brightness brilho) {
  final ios = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
  return ios ? _temaIOS(brilho) : _temaAndroid(brilho);
}

ThemeData _temaAndroid(Brightness brilho) {
  // "fidelity" mantem o azul da marca no botao principal (o padrao do Material 3 o deixaria
  // acinzentado); os demais tons continuam gerados pelo sistema.
  final esquema = ColorScheme.fromSeed(
    seedColor: _azul,
    brightness: brilho,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    // Alvos de toque maiores ajudam usuarios com dificuldade motora.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Campos com contorno e rotulo que sobe ao digitar (padrao do Material 3).
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

ThemeData _temaIOS(Brightness brilho) {
  final escuro = brilho == Brightness.dark;
  final esquema = ColorScheme.fromSeed(
    seedColor: _azul,
    brightness: brilho,
    primary: escuro ? const Color(0xFF0A84FF) : _azul,
    surface: escuro ? const Color(0xFF1C1C1E) : Colors.white,
  );
  final fundo = escuro ? Colors.black : const Color(0xFFF2F2F7);

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: fundo,
    // Cores do iOS fixadas para cada modo: derivadas do tema Material, a barra de topo ficava
    // clara no modo escuro ao rolar a tela, e o texto dos botoes azuis ficava escuro.
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brilho,
      primaryColor: escuro ? const Color(0xFF0A84FF) : _azul,
      primaryContrastingColor: CupertinoColors.white,
      barBackgroundColor: escuro ? const Color(0xF01D1D1D) : const Color(0xF0F9F9F9),
    ),
    // Alvos de toque maiores ajudam usuarios com dificuldade motora.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: fundo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: escuro ? Colors.white : const Color(0xFF1D1D1F),
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: esquema.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 44)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: escuro ? const Color(0xFF2C2C2E) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: escuro ? const Color(0xF21C1C1E) : const Color(0xF2F9F9F9),
      indicatorColor: esquema.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
