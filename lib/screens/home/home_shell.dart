import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../calendar/calendar_screen.dart';
import '../metas/metas_screen.dart';
import '../profile/profile_screen.dart';
import '../volunteering/checkin_scanner_screen.dart';
import '../volunteering/my_qrcode_screen.dart';
import '../volunteering/shifts_screen.dart';

/// Estrutura principal do app com navegacao por abas.
/// O botao central (QR Code / Check-in) fica elevado, projetando pra
/// fora da barra -- e a acao mais usada no dia a dia do lider.
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

        final screens = [
          const CalendarScreen(),
          const ShiftsScreen(),
          isLider ? const CheckinScannerScreen() : const MyQrCodeScreen(),
          const MetasScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(
            onPressed: () => setState(() => _currentIndex = 2),
            shape: const CircleBorder(),
            elevation: 4,
            child: Icon(isLider ? Icons.qr_code_scanner : Icons.qr_code, size: 28),
          ),
          bottomNavigationBar: BottomAppBar(
            color: AwakeColors.navy,
            shape: const CircularNotchedRectangle(),
            notchMargin: 10,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 64,
              // Cada um dos 4 itens ocupa uma fatia de largura IDENTICA
              // (Expanded com flex igual), nao importa o tamanho do texto.
              // O vao do meio tem largura fixa. Isso garante simetria
              // visual de verdade, nao so matematica.
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.calendar_month,
                      label: 'Calendário',
                      selected: _currentIndex == 0,
                      onTap: () => setState(() => _currentIndex = 0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.volunteer_activism,
                      label: 'Escala',
                      selected: _currentIndex == 1,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                  ),
                  const SizedBox(width: 56), // espaco reservado pro botao central
                  Expanded(
                    child: _NavItem(
                      icon: Icons.emoji_events,
                      label: 'Metas',
                      selected: _currentIndex == 3,
                      onTap: () => setState(() => _currentIndex = 3),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person,
                      label: 'Perfil',
                      selected: _currentIndex == 4,
                      onTap: () => setState(() => _currentIndex = 4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AwakeColors.yellow : AwakeColors.offWhite;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      customBorder: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}