import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/signup_model.dart';
import '../../providers/shift_provider.dart';

/// Tela do lider: lista quem se inscreveu numa escala e da acesso
/// ao scanner de check-in.
class LeaderShiftDetailScreen extends ConsumerWidget {
  final String escalaId;
  const LeaderShiftDetailScreen({super.key, required this.escalaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signupsAsync = ref.watch(signupsForShiftProvider(escalaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscritos na escala'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Fazer check-in',
            onPressed: () => context.push('/checkin/$escalaId'),
          ),
        ],
      ),
      body: signupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (signups) {
          if (signups.isEmpty) {
            return const Center(child: Text('Ninguem se inscreveu ainda.'));
          }
          return ListView.builder(
            itemCount: signups.length,
            itemBuilder: (context, index) {
              final signup = signups[index];
              return ListTile(
                leading: Icon(
                  signup.status.name == 'checkInFeito' ? Icons.check_circle : Icons.person,
                  color: signup.status.name == 'checkInFeito' ? Colors.green : null,
                ),
                title: Text(signup.userNome ?? 'Membro'),
                subtitle: Text(signup.status.label),
              );
            },
          );
        },
      ),
    );
  }
}
