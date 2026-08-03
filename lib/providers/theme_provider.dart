import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controla o tema do app manualmente (nao segue mais o sistema
/// automaticamente) -- comeca sempre claro, e a pessoa troca pelo
/// interruptor na tela de Perfil. Nao fica salvo entre aberturas do
/// app por enquanto (reinicia como claro sempre).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);