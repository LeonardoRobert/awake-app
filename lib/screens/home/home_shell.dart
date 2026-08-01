import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import '../volunteering/shifts_screen.dart';

/// Estrutura principal do app com navegacao por abas (bottom navigation).
///
/// Este e o ponto de entrada visual apos o login. As abas disponiveis
/// (Calendario, Voluntariado, Perfil) sao as mesmas para membro e lider;
/// a diferenca de permissao acontece dentro de cada tela (ex: botao
/// "criar evento" so aparece para lider/admin).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  static const _screens = [
    CalendarScreen(),
    ShiftsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Erro ao carregar perfil: $err')),
      ),
      data: (profile) {
        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendario'),
              NavigationDestination(icon: Icon(Icons.volunteer_activism), label: 'Voluntariado'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}
