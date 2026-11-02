import 'package:flutter/foundation.dart';

/// Endereco da API ModaMax.
///
/// Pode ser trocado na execucao:
///   flutter run --dart-define=API_URL=https://modamax.azurewebsites.net
///
/// Sem o parametro, usa a API local (dotnet run, porta 5248). O emulador
/// Android enxerga o computador pelo IP especial 10.0.2.2.
String get apiBaseUrl {
  const definida = String.fromEnvironment('API_URL');
  if (definida.isNotEmpty) return definida;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5248';
  }
  return 'http://localhost:5248';
}
