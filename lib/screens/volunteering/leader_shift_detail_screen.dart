import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/signup_model.dart';
import '../../providers/shift_provider.dart';

/// Tela do lider: lista quem se inscreveu numa ocorrencia (semana)
/// especifica de uma escala.
class LeaderShiftDetailScreen extends ConsumerWidget {
  final String escalaId;
  final DateTime data;

  const LeaderShiftDetailScreen({
    super.key,
    required this.escalaId,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signupsAsync =
        ref.watch(signupsForOccurrenceProvider((escalaId: escalaId, data: data)));

    return Scaffold(
      appBar: AppBar(
        title: Text('Inscritos — ${DateFormat('dd/MM/yyyy').format(data)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Fazer check-in',
            onPressed: () => context.push('/checkin'),
          ),
        ],
      ),
      body: signupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (signups) {
          if (signups.isEmpty) {
            return const Center(child: Text('Ninguém se inscreveu ainda.'));
          }
          return ListView.builder(
            itemCount: signups.length,
            itemBuilder: (context, index) {
              final signup = signups[index];
              final feito = signup.status == SignupStatus.checkInFeito;
              return ListTile(
                leading: Icon(
                  feito ? Icons.check_circle : Icons.person,
                  color: feito ? Colors.green : null,
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
