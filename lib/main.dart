import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();
  await NotificationService.initialize();
  await initializeDateFormatting('pt_BR', null);

  runApp(const ProviderScope(child: AwakeApp()));
}

class AwakeApp extends ConsumerStatefulWidget {
  const AwakeApp({super.key});

  @override
  ConsumerState<AwakeApp> createState() => _AwakeAppState();
}

class _AwakeAppState extends ConsumerState<AwakeApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Quando a pessoa clica no link de recuperacao de senha do e-mail,
    // o Supabase dispara esse evento -- a gente aproveita pra levar
    // direto pra tela de definir a nova senha.
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        ref.read(routerProvider).go('/redefinir-senha');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Awake',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Controlado manualmente pela pessoa (ver Perfil), nao segue mais
      // o tema do sistema sozinho.
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}