import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/event_model.dart';
import '../models/shift_model.dart';
import '../models/treinamento_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/redefinir_senha_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/termos_screen.dart';
import '../screens/calendar/admin_calendario_screen.dart';
import '../screens/financeiro/admin_financeiro_screen.dart';
import '../screens/calendar/event_detail_screen.dart';
import '../screens/calendar/event_form_screen.dart';
import '../screens/financeiro/financeiro_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/training/treinamento_detail_screen.dart';
import '../screens/training/treinamento_form_screen.dart';
import '../screens/training/treinamentos_screen.dart';
import '../screens/volunteering/checkin_scanner_screen.dart';
import '../screens/volunteering/leader_shift_detail_screen.dart';
import '../screens/volunteering/my_qrcode_screen.dart';
import '../screens/volunteering/shift_form_screen.dart';

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
          state.matchedLocation == '/cadastro' ||
          state.matchedLocation == '/redefinir-senha';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute && state.matchedLocation != '/redefinir-senha') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/cadastro', builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: '/redefinir-senha',
        builder: (context, state) => const RedefinirSenhaScreen(),
      ),
      GoRoute(path: '/termos', builder: (context, state) => const TermosScreen()),
      GoRoute(path: '/financeiro', builder: (context, state) => const FinanceiroScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/admin/calendario',
        builder: (context, state) => const AdminCalendarioScreen(),
      ),
      GoRoute(
        path: '/admin/financeiro',
        builder: (context, state) => const AdminFinanceiroScreen(),
      ),
      GoRoute(
        path: '/eventos/novo',
        builder: (context, state) =>
            EventFormScreen(eventoParaEditar: state.extra as EventModel?),
      ),
      GoRoute(
        path: '/eventos/:id',
        builder: (context, state) => EventDetailScreen(
          eventId: state.pathParameters['id']!,
          occurrenceDate: state.extra as DateTime?,
        ),
      ),
      GoRoute(
        path: '/escalas/nova',
        builder: (context, state) =>
            ShiftFormScreen(shiftParaEditar: state.extra as ShiftModel?),
      ),
      GoRoute(
        path: '/escalas/:id/inscritos',
        builder: (context, state) => LeaderShiftDetailScreen(
          escalaId: state.pathParameters['id']!,
          data: state.extra as DateTime,
        ),
      ),
      GoRoute(
        path: '/checkin',
        builder: (context, state) => const CheckinScannerScreen(),
      ),
      GoRoute(
        path: '/meu-qrcode',
        builder: (context, state) => const MyQrCodeScreen(),
      ),
      GoRoute(
        path: '/treinamentos',
        builder: (context, state) => const TreinamentosScreen(),
      ),
      GoRoute(
        path: '/treinamentos/novo',
        builder: (context, state) =>
            TreinamentoFormScreen(treinamentoParaEditar: state.extra as TreinamentoModel?),
      ),
      GoRoute(
        path: '/treinamentos/detalhe',
        builder: (context, state) =>
            TreinamentoDetailScreen(treinamento: state.extra as TreinamentoModel),
      ),
    ],
  );
});
