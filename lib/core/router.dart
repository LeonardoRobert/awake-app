import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/calendar/event_detail_screen.dart';
import '../screens/calendar/event_form_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/volunteering/checkin_scanner_screen.dart';
import '../screens/volunteering/leader_shift_detail_screen.dart';
import '../screens/volunteering/my_qrcode_screen.dart';

/// Ouvinte simples que permite ao GoRouter reagir a mudancas
/// no estado de autenticacao do Supabase.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final session = ref.read(authStateProvider).value?.session;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/cadastro';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/cadastro', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/eventos/novo',
        builder: (context, state) => const EventFormScreen(),
      ),
      GoRoute(
        path: '/eventos/:id',
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/meu-qrcode',
        builder: (context, state) => const MyQrCodeScreen(),
      ),
      GoRoute(
        path: '/escalas/:id/inscritos',
        builder: (context, state) =>
            LeaderShiftDetailScreen(escalaId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/checkin/:escalaId',
        builder: (context, state) =>
            CheckinScannerScreen(escalaId: state.pathParameters['escalaId']!),
      ),
    ],
  );
});
