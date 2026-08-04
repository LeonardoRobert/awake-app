import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chaveTemaEscuro = 'tema_escuro';

/// Controla o tema do app manualmente. Agora guarda a escolha no
/// proprio aparelho (SharedPreferences), entao continua igual mesmo
/// depois de fechar e abrir o app de novo.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _carregarPreferencia();
  }

  Future<void> _carregarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    final escuro = prefs.getBool(_chaveTemaEscuro) ?? false;
    state = escuro ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> definir(bool escuro) async {
    state = escuro ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveTemaEscuro, escuro);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
