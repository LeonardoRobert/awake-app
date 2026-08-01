import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/shift_model.dart';
import '../../models/signup_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';

/// Tela principal do modulo de Voluntariado (Escala).
/// Membro: ve as ocorrencias futuras das escalas e se inscreve.
/// Lider: ve as mesmas ocorrencias, edita a escala e ve os inscritos.
class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  /// Classifica o horario de chegada em Manha / Tarde / Noite, so pra
  /// facilitar a leitura visual -- nao afeta nenhuma regra de negocio.
  String _periodo(String horarioInicio) {
    final hora = int.parse(horarioInicio.split(':').first);
    if (hora < 12) return 'Manhã';
    if (hora < 18) return 'Tarde';
    return 'Noite';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occurrencesAsync = ref.watch(upcomingShiftOccurrencesProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escala'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Minhas inscrições',
            onPressed: () => _showMySignups(context),
          ),
        ],
      ),
      floatingActionButton: isLider
          ? FloatingActionButton(
              onPressed: () => context.push('/escalas/nova'),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(upcomingShiftOccurrencesProvider.future),
        child: occurrencesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro ao carregar escalas: $err')),
          data: (occurrences) {
            if (occurrences.isEmpty) {
              return const Center(child: Text('Nenhuma escala programada no momento.'));
            }

            final Map<String, List<ShiftOccurrence>> byDate = {};
            for (final occ in occurrences) {
              final key = DateFormat('yyyy-MM-dd').format(occ.data);
              byDate.putIfAbsent(key, () => []).add(occ);
            }
            final orderedDateKeys = byDate.keys.toList()..sort();

            return ListView.builder(
              itemCount: orderedDateKeys.length,
              itemBuilder: (context, index) {
                final dateKey = orderedDateKeys[index];
                final dayOccurrences = byDate[dateKey]!;
                final data = dayOccurrences.first.data;

                final Map<String, List<ShiftOccurrence>> byHorario = {};
                for (final occ in dayOccurrences) {
                  byHorario.putIfAbsent(occ.shift.horarioInicio, () => []).add(occ);
                }
                final orderedHorarios = byHorario.keys.toList()..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                      child: Text(
                        DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(data),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    for (final horario in orderedHorarios) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Icon(
                              _periodo(horario) == 'Manhã'
                                  ? Icons.wb_sunny_outlined
                                  : _periodo(horario) == 'Tarde'
                                      ? Icons.wb_cloudy_outlined
                                      : Icons.nights_stay_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_periodo(horario)} • $horario',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ...byHorario[horario]!.map((occ) => Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              title: Text(occ.shift.nome),
                              subtitle: Text(
                                'até ${occ.shift.horarioFim} • '
                                '${occ.inscritosCount}/${occ.shift.vagas} vagas preenchidas'
                                '${occ.shift.recorrente ? ' • recorrente' : ''}',
                              ),
                              trailing: isLider
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'Editar escala',
                                          onPressed: () => context.push(
                                            '/escalas/nova',
                                            extra: occ.shift,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.groups),
                                          tooltip: 'Ver inscritos',
                                          onPressed: () => context.push(
                                            '/escalas/${occ.shift.id}/inscritos',
                                            extra: occ.data,
                                          ),
                                        ),
                                      ],
                                    )
                                  : FilledButton(
                                      onPressed: occ.temVaga
                                          ? () => _signUp(context, ref, occ)
                                          : null,
                                      child: Text(occ.temVaga ? 'Inscrever-se' : 'Lotado'),
                                    ),
                            ),
                          )),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _signUp(BuildContext context, WidgetRef ref, ShiftOccurrence occ) async {
    try {
      await ref.read(shiftServiceProvider).signUp(occ.shift.id, occ.data);
      ref.invalidate(upcomingShiftOccurrencesProvider);
      ref.invalidate(mySignupsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Inscrição confirmada!')));
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
              return const Center(child: Text('Você ainda não se inscreveu em nenhuma escala.'));
            }
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: signups.length,
              itemBuilder: (context, index) {
                final signup = signups[index];
                final escala = signup.escala;
                final nome = escala?['nome'] ?? 'Escala';
                final canCancel = signup.status == SignupStatus.inscrito;

                return ListTile(
                  title: Text('$nome — ${DateFormat('dd/MM/yyyy').format(signup.dataOcorrencia)}'),
                  subtitle: Text(signup.status.label),
                  trailing: canCancel
                      ? TextButton(
                          onPressed: () async {
                            await ref.read(shiftServiceProvider).cancelSignup(signup.id);
                            ref.invalidate(mySignupsProvider);
                            ref.invalidate(upcomingShiftOccurrencesProvider);
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