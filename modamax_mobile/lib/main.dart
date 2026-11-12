import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ModaMaxApp());
}

class ModaMaxApp extends StatelessWidget {
  const ModaMaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ModaMax',
      debugShowCheckedModeBanner: false,
      theme: temaModaMax(Brightness.light),
      darkTheme: temaModaMax(Brightness.dark),
      home: const _Inicio(),
    );
  }
}

/// Decide a primeira tela: se ja existe um token salvo, vai direto ao painel.
class _Inicio extends StatelessWidget {
  const _Inicio();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService.instancia.restaurarSessao(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
