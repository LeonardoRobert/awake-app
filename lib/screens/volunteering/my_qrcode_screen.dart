import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Exibe o QR Code pessoal do membro, usado pelo lider para
/// fazer o check-in de presenca em uma escala ou evento.
class MyQrCodeScreen extends ConsumerWidget {
  const MyQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Meu QR Code'),
      body: Center(
        child: profileAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (err, _) => Text('Erro: $err'),
          data: (profile) {
            if (profile == null) return const Text('Perfil nao encontrado.');
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(profile.nome, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                    ],
                  ),
                  child: QrImageView(
                    data: profile.qrCodeId,
                    size: 220,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Apresente este QR Code ao lider no momento do seu turno de servico.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
