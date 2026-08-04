import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// AppBar padrao do app: chama + titulo, e um botao fixo de QR Code /
/// Check-in no canto superior direito (antes isso era uma aba na barra
/// de baixo -- agora fica sempre visivel, em qualquer tela).
///
/// Use `showQrButton: false` nas proprias telas de QR/Check-in, pra nao
/// mostrar o botao dentro delas mesmas.
class AwakeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showQrButton;

  const AwakeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showQrButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/awake_flame_white.png', height: 20),
          const SizedBox(width: 10),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: [
        ...?actions,
        if (showQrButton)
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
