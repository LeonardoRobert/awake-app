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

/// Escuta o Realtime do Supabase na PROPRIA linha de profiles da pessoa
/// logada -- quando um admin edita o perfil dela em outro lugar (ex:
/// gestao.html), essa mudanca chega sozinha, sem precisar de pull-to-
/// refresh manual. So essa tabela, so a propria linha (escopo minimo
/// de proposito): e' aditivo, nao substitui currentProfileProvider (que
/// continua buscando via REST normal) -- so passa a invalida-lo sozinho
/// quando alguem de fora mexe no perfil. Se a conexao cair, o app
/// continua funcionando exatamente como hoje, so sem a atualizacao
/// instantanea.
///
/// Precisa ficar "watched" em algum lugar sempre montado durante a
/// sessao (HomeShell) pra subscription nao morrer.
final profileRealtimeProvider = Provider.autoDispose<void>((ref) {
  // So reage a login/logout (nao a currentProfileProvider -- watcher
  // nele criaria um loop de re-inscrever o canal a cada invalidacao
  // disparada por esse mesmo provider).
  ref.watch(authStateProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  final canal = Supabase.instance.client
      .channel('profile-realtime-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: userId),
        callback: (_) => ref.invalidate(currentProfileProvider),
      )
      .subscribe();

  ref.onDispose(() => Supabase.instance.client.removeChannel(canal));
});
