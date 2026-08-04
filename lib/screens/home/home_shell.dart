import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../calendar/calendar_screen.dart';
import '../home/inicio_screen.dart';
import '../metas/metas_screen.dart';
import '../profile/profile_screen.dart';
import '../volunteering/shifts_screen.dart';

/// Estrutura principal do app com navegacao por abas.
/// O QR Code/Check-in nao e mais uma aba -- agora e um botao fixo no
/// canto superior direito de cada tela (ver AwakeAppBar).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _tourMostrado = false;

  void _mostrarTourSeNecessario() {
    if (_tourMostrado) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || profile.tourVisto) return;

    _tourMostrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _abrirTour();
    });
  }

  Future<void> _abrirTour() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bem-vindo(a) ao Awake! 🔥'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ItemTour(icon: Icons.home_outlined, texto: 'Início — os eventos exclusivos da Awake dessa semana, prontos pra compartilhar.'),
            _ItemTour(icon: Icons.calendar_month, texto: 'Calendário — veja os próximos eventos e a programação da semana.'),
            _ItemTour(icon: Icons.volunteer_activism, texto: 'Escala — inscreva-se para servir nos horários disponíveis.'),
            _ItemTour(icon: Icons.emoji_events, texto: 'Metas — acompanhe sua constância e seus troféus.'),
            _ItemTour(icon: Icons.person, texto: 'Perfil — seus dados e treinamentos.'),
            _ItemTour(icon: Icons.qr_code, texto: 'O ícone no topo da tela é seu QR Code (ou, se você for líder, a câmera de check-in).'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi!'),
          ),
        ],
      ),
    );

    await ref.read(authServiceProvider).marcarTourVisto();
    ref.invalidate(currentProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Erro ao carregar perfil: $err')),
      ),
      data: (profile) {
        _mostrarTourSeNecessario();

        final screens = [
          const InicioScreen(),
          const CalendarScreen(),
          const ShiftsScreen(),
          const MetasScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: ColoredBox(
            color: AwakeColors.navy,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home_outlined,
                        label: 'Início',
                        selected: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.calendar_month,
                        label: 'Calendário',
                        selected: _currentIndex == 1,
                        onTap: () => setState(() => _currentIndex = 1),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.volunteer_activism,
                        label: 'Escala',
                        selected: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                    ),
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
          ),
        );
      },
    );
  }
}

class _ItemTour extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _ItemTour({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
