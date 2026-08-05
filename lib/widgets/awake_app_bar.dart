import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// AppBar padrao do app. Se adapta sozinha a quem esta logado:
/// - Pessoa Awake: chama branca + botao de QR Code/Check-in fixo
/// - Pessoa de outro ministerio (Homens/Mulheres): pomba da Shallom,
///   sem botao de QR (esses ministerios nao tem escala/check-in)
///
/// Use `showQrButton: false` nas proprias telas de QR/Check-in, pra
/// nao mostrar o botao dentro delas mesmas.
class AwakeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showQrButton;
  final Widget? leading;

  const AwakeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showQrButton = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;
    final isLider = profile?.isLider ?? false;
    // Enquanto carrega (profile null), assume Awake pra nao "piscar"
    // pra pomba e voltar pra chama um instante depois -- a maioria de
    // quem usa o app hoje e Awake.
    final ehAwake = profile?.pertenceAwake ?? true;

    final icone = ehAwake
        ? 'assets/images/awake_flame_white.png'
        : 'assets/images/shallom_pomba_cabecalho.png';

    return AppBar(
      backgroundColor: ehAwake ? AwakeColors.navy : ShallomColors.azul,
      leading: leading,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(icone, height: 28),
          const SizedBox(width: 10),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: [
        ...?actions,
        // QR Code / Check-in so existe pro Awake.
        if (showQrButton && ehAwake)
          IconButton(
            icon: Icon(isLider ? Icons.qr_code_scanner : Icons.qr_code),
            tooltip: isLider ? 'Check-in' : 'Meu QR Code',
            onPressed: () {
              if (isLider) {
                context.push('/checkin');
              } else {
                context.push('/meu-qrcode');
              }
            },
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
