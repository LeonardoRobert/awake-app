import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../calendar/calendar_screen.dart';
import '../financeiro/financeiro_screen.dart';
import '../home/inicio_screen.dart';
import '../pages/nossos_conteudos_screen.dart';
import '../metas/metas_screen.dart';
import '../profile/profile_screen.dart';
import '../volunteering/shifts_screen.dart';

/// Estrutura principal do app com navegacao por abas.
///
/// Quem pertence ao Awake (mesmo que tambem pertenca a outro
/// ministerio) usa a navegacao Awake de 5 abas. Quem NAO pertence ao
/// Awake (so Homens e/ou Mulheres) usa a navegacao Shallom, de 4 abas
/// (sem Escala/Metas/QR, que sao coisas exclusivas do Awake).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _tourMostrado = false;

  void _mostrarTourSeNecessario(bool ehAwake) {
    if (_tourMostrado) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || profile.tourVisto) return;

    _tourMostrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _abrirTour(ehAwake);
    });
  }

  Future<void> _abrirTour(bool ehAwake) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bem-vindo(a)! ${ehAwake ? "🔥" : ""}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ehAwake
              ? const [
                  _ItemTour(icon: Icons.home_outlined, texto: 'Início — seus próximos eventos da semana, prontos pra compartilhar.'),
                  _ItemTour(icon: Icons.calendar_month, texto: 'Calendário — veja os próximos eventos e a programação da semana.'),
                  _ItemTour(icon: Icons.volunteer_activism, texto: 'Escala — inscreva-se para servir nos horários disponíveis.'),
                  _ItemTour(icon: Icons.emoji_events, texto: 'Metas — acompanhe sua constância e seus troféus.'),
                  _ItemTour(icon: Icons.person, texto: 'Perfil — seus dados e treinamentos.'),
                  _ItemTour(icon: Icons.qr_code, texto: 'O ícone no topo da tela é seu QR Code (ou, se você for líder, a câmera de check-in).'),
                ]
              : const [
                  _ItemTour(icon: Icons.home_outlined, texto: 'Início — seus próximos eventos da semana, prontos pra compartilhar.'),
                  _ItemTour(icon: Icons.calendar_month, texto: 'Calendário — veja os próximos eventos e a programação da semana.'),
                  _ItemTour(icon: Icons.volunteer_activism, texto: 'Contribua — dízimos, ofertas e como ajudar.'),
                  _ItemTour(icon: Icons.person, texto: 'Perfil — seus dados e treinamentos.'),
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
        final ehAwake = profile?.pertenceAwake ?? true;
        _mostrarTourSeNecessario(ehAwake);

        final screens = ehAwake
            ? const [
                InicioScreen(),
                CalendarScreen(),
                ShiftsScreen(),
                MetasScreen(),
                ProfileScreen(),
              ]
            : const [
                InicioScreen(),
                CalendarScreen(),
                NossosConteudosScreen(),
                FinanceiroScreen(),
                ProfileScreen(),
              ];

        final itensAwake = [
          (Icons.home_outlined, 'Início'),
          (Icons.calendar_month, 'Calendário'),
          (Icons.volunteer_activism, 'Escala'),
          (Icons.emoji_events, 'Metas'),
          (Icons.person, 'Perfil'),
        ];
        final itensShallom = [
          (Icons.home_outlined, 'Início'),
          (Icons.calendar_month, 'Calendário'),
          (Icons.ondemand_video_outlined, 'Conteúdos'),
          (Icons.attach_money, 'Contribua'),
          (Icons.person, 'Perfil'),
        ];
        final itens = ehAwake ? itensAwake : itensShallom;
        final corFundo = ehAwake ? AwakeColors.navy : ShallomColors.azul;
        // No Awake, o item selecionado fica amarelo sobre fundo navy.
        // Na Shallom, o fundo ja e o azul -- entao o selecionado vira
        // navy solido (bem mais forte que o azul de fundo), e o resto
        // fica branco, do mesmo jeito que aparece no material da marca.
        final corSelecionada = ehAwake ? AwakeColors.yellow : AwakeColors.navy;
        final corNaoSelecionada = AwakeColors.offWhite;

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: ColoredBox(
            color: corFundo,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: List.generate(itens.length, (index) {
                    final (icon, label) = itens[index];
                    return Expanded(
                      child: _NavItem(
                        icon: icon,
                        label: label,
                        selected: _currentIndex == index,
                        corSelecionada: corSelecionada,
                        corNaoSelecionada: corNaoSelecionada,
                        onTap: () => setState(() => _currentIndex = index),
                      ),
                    );
                  }),
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
  final Color corSelecionada;
  final Color corNaoSelecionada;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.corSelecionada,
    required this.corNaoSelecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? corSelecionada : corNaoSelecionada;
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
