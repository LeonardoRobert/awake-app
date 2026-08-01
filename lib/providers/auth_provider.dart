import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Emite o estado de autenticacao (logado / deslogado) em tempo real.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Carrega o perfil (profiles) do usuario atualmente logado.
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  // Reage a mudancas de auth (login/logout) para recarregar o perfil.
  ref.watch(authStateProvider);
  final profile = await ref.watch(authServiceProvider).fetchCurrentProfile();

  if (profile != null) {
    await NotificationService.loginUser(profile.id);
  }

  return profile;
});
