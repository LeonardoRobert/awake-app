import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../calendar/calendar_screen.dart';
import '../metas/metas_screen.dart';
import '../profile/profile_screen.dart';
import '../volunteering/checkin_scanner_screen.dart';
import '../volunteering/my_qrcode_screen.dart';
import '../volunteering/shifts_screen.dart';

/// Estrutura principal do app com navegacao por abas (bottom navigation).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Erro ao carregar perfil: $err')),
      ),
      data: (profile) {
        final isLider = profile?.isLider ?? false;

        // Membro ve o proprio QR Code; lider/admin ve direto a camera
        // de check-in (e la dentro escolhe pra qual atividade e).
        final screens = [
          const CalendarScreen(),
          const ShiftsScreen(),
          isLider ? const CheckinScannerScreen() : const MyQrCodeScreen(),
          const MetasScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendário'),
              const NavigationDestination(icon: Icon(Icons.volunteer_activism), label: 'Escala'),
              NavigationDestination(
                icon: Icon(isLider ? Icons.qr_code_scanner : Icons.qr_code),
                label: isLider ? 'Check-in' : 'QR Code',
              ),
              const NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Metas'),
              const NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}