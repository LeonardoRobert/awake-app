import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/signup_model.dart';
import '../../providers/shift_provider.dart';

/// Tela principal do modulo de Voluntariado.
/// Membro: ve escalas disponiveis e se inscreve.
/// Lider: ve as mesmas escalas e pode abrir a lista de inscritos / check-in.
class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(upcomingShiftsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voluntariado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Meu QR Code',
            onPressed: () => context.push('/meu-qrcode'),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Minhas inscricoes',
            onPressed: () => _showMySignups(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(upcomingShiftsProvider.future),
        child: shiftsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro ao carregar escalas: $err')),
          data: (shifts) {
            if (shifts.isEmpty) {
              return const Center(child: Text('Nenhuma escala disponivel no momento.'));
            }
            return ListView.builder(
              itemCount: shifts.length,
              itemBuilder: (context, index) {
                final shift = shifts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(shift.area?.nome ?? 'Area'),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy').format(shift.data)} - '
                      '${shift.horarioInicio} as ${shift.horarioFim}\n'
                      '${shift.inscritosCount}/${shift.vagas} vagas preenchidas',
                    ),
                    isThreeLine: true,
                    trailing: isLider
                        ? IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'Ver inscritos / check-in',
                            onPressed: () => context.push('/escalas/${shift.id}/inscritos'),
                          )
                        : FilledButton(
                            onPressed: shift.temVaga
                                ? () => _signUp(context, ref, shift.id)
                                : null,
                            child: Text(shift.temVaga ? 'Inscrever-se' : 'Lotado'),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _signUp(BuildContext context, WidgetRef ref, String shiftId) async {
    try {
      await ref.read(shiftServiceProvider).signUp(shiftId);
      ref.invalidate(upcomingShiftsProvider);
      ref.invalidate(mySignupsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Inscricao confirmada!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao se inscrever: $e')));
      }
    }
  }

  void _showMySignups(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MySignupsSheet(),
    );
  }
}

class _MySignupsSheet extends ConsumerWidget {
  const _MySignupsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signupsAsync = ref.watch(mySignupsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return signupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro: $err')),
          data: (signups) {
            if (signups.isEmpty) {
              return const Center(child: Text('Voce ainda nao se inscreveu em nenhuma escala.'));
            }
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: signups.length,
              itemBuilder: (context, index) {
                final signup = signups[index];
                final escala = signup.escala;
                final area = escala?['areas_servico']?['nome'] ?? 'Area';
                final data = escala?['data'] ?? '';
                final canCancel = signup.status.name == 'inscrito';

                return ListTile(
                  title: Text('$area - $data'),
                  subtitle: Text(signup.status.label),
                  trailing: canCancel
                      ? TextButton(
                          onPressed: () async {
                            await ref.read(shiftServiceProvider).cancelSignup(signup.id);
                            ref.invalidate(mySignupsProvider);
                            ref.invalidate(upcomingShiftsProvider);
                          },
                          child: const Text('Cancelar'),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}
