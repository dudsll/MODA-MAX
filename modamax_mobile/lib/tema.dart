import 'package:flutter/material.dart';

/// Tema do app no estilo iOS: fundo agrupado cinza-claro (ou preto no escuro), cartoes brancos
/// arredondados, titulos fortes e o azul jeans da marca como destaque. Mesmo visual da Web.
ThemeData temaModaMax(Brightness brilho) {
  final escuro = brilho == Brightness.dark;
  const azul = Color(0xFF0071E3);
  final esquema = ColorScheme.fromSeed(
    seedColor: azul,
    brightness: brilho,
    primary: escuro ? const Color(0xFF0A84FF) : azul,
    surface: escuro ? const Color(0xFF1C1C1E) : Colors.white,
  );
  final fundo = escuro ? Colors.black : const Color(0xFFF2F2F7);

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: fundo,
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
