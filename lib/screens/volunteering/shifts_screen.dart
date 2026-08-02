import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shift_model.dart';
import '../../models/signup_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela principal do modulo de Voluntariado (Escala).
/// Membro: ve as ocorrencias do mes atual e se inscreve.
/// Lider: ve as mesmas ocorrencias, edita a escala e ve os inscritos.
class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key});

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  // Guarda quais ocorrencias estao com uma inscricao em andamento, pra
  // impedir clique duplo (que causava varias mensagens de erro empilhadas).
  final Set<String> _processando = {};

  String _periodo(String horarioInicio) {
    final hora = int.parse(horarioInicio.split(':').first);
    if (hora < 12) return 'Manhã';
    if (hora < 18) return 'Tarde';
    return 'Noite';
  }

  String _chave(String escalaId, DateTime data) =>
      '${escalaId}_${DateFormat('yyyy-MM-dd').format(data)}';

  @override
  Widget build(BuildContext context) {
    final occurrencesAsync = ref.watch(upcomingShiftOccurrencesProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final mySignupsAsync = ref.watch(mySignupsProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    // Conjunto de "escalaId_data" das inscricoes ativas do proprio
    // usuario, pra saber em quais ocorrencias mostrar "Inscrito" em vez
    // de "Inscrever-se".
    final minhasInscricoesAtivas = <String>{};
    mySignupsAsync.whenData((signups) {
      for (final s in signups) {
        if (s.status == SignupStatus.inscrito || s.status == SignupStatus.checkInFeito) {
          minhasInscricoesAtivas.add(_chave(s.escalaId, s.dataOcorrencia));
        }
      }
    });

    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Escala',
        actions: [
          if (!isLider)
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'Minhas inscrições',
              onPressed: () => _showMySignups(context),
            ),
        ],
      ),
      floatingActionButton: isLider
          ? FloatingActionButton.small(
              heroTag: 'fab-escala',
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
              return const Center(child: Text('Nenhuma escala programada neste mês.'));
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
                      ...byHorario[horario]!.map((occ) {
                        final chave = _chave(occ.shift.id, occ.data);
                        final jaInscrito = minhasInscricoesAtivas.contains(chave);
                        final processando = _processando.contains(chave);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text(occ.shift.nome),
                            subtitle: Text(
                              'até ${occ.shift.horarioFim} • '
                              '${occ.inscritosCount}/${occ.shift.vagas} vagas preenchidas'
                              '${occ.shift.recorrente ? ' • recorrente' : ''}',
                            ),
                            trailing: isLider
                                ? PopupMenuButton<String>(
                                    onSelected: (opcao) {
                                      switch (opcao) {
                                        case 'editar':
                                          context.push('/escalas/nova', extra: occ.shift);
                                          break;
                                        case 'inscritos':
                                          context.push(
                                            '/escalas/${occ.shift.id}/inscritos',
                                            extra: occ.data,
                                          );
                                          break;
                                        case 'excluir':
                                          _confirmarExclusaoEscala(context, occ.shift, occ.data);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'editar',
                                        child: ListTile(
                                          leading: Icon(Icons.edit),
                                          title: Text('Editar'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'inscritos',
                                        child: ListTile(
                                          leading: Icon(Icons.groups),
                                          title: Text('Ver inscritos'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'excluir',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline, color: Colors.red),
                                          title: Text('Excluir', style: TextStyle(color: Colors.red)),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  )
                                : jaInscrito
                                    ? OutlinedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Inscrito'),
                                      )
                                    : FilledButton(
                                        onPressed: (occ.temVaga && !processando)
                                            ? () => _signUp(context, occ)
                                            : null,
                                        child: processando
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : Text(occ.temVaga ? 'Inscrever-se' : 'Lotado'),
                                      ),
                          ),
                        );
                      }),
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

  Future<void> _signUp(BuildContext context, ShiftOccurrence occ) async {
    final chave = _chave(occ.shift.id, occ.data);
    if (_processando.contains(chave)) return; // ja tem uma tentativa em andamento

    setState(() => _processando.add(chave));

    try {
      await ref.read(shiftServiceProvider).signUp(occ.shift.id, occ.data);
      ref.invalidate(upcomingShiftOccurrencesProvider);
      ref.invalidate(mySignupsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Inscrição confirmada!')));
      }
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      final mensagem = _mensagemAmigavel(e.message);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível se inscrever. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processando.remove(chave));
    }
  }

  /// Traduz os erros mais comuns vindos do banco em mensagens claras,
  /// em vez de mostrar o texto tecnico bruto pro membro.
  String _mensagemAmigavel(String erroOriginal) {
    if (erroOriginal.contains('limite_domingos')) {
      return 'Você já atingiu o limite de 2 domingos neste mês. '
          'Cancele uma inscrição de domingo para liberar uma vaga.';
    }
    if (erroOriginal.contains('ja esta inscrito em outra escala')) {
      return 'Você já está inscrito em outra escala nesse mesmo horário.';
    }
    if (erroOriginal.contains('lotada')) {
      return 'Essa escala acabou de lotar. Escolha outro horário.';
    }
    return 'Não foi possível se inscrever no momento.';
  }

  Future<void> _confirmarExclusaoEscala(
    BuildContext context,
    ShiftModel shift,
    DateTime dataOcorrencia,
  ) async {
    if (shift.recorrente) {
      final escopo = await _perguntarEscopo(context, 'escala');
      if (escopo == null) return;

      if (escopo == 'uma') {
        try {
          await ref.read(shiftServiceProvider).deleteShiftOccurrence(shift.id, dataOcorrencia);
          ref.invalidate(upcomingShiftOccurrencesProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Ocorrência excluída.')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
          }
        }
        return;
      }
      // escopo == 'todas' -> segue pro fluxo normal de confirmação abaixo
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir escala?'),
        content: Text(
          'Isso vai apagar "${shift.nome}" permanentemente'
          '${shift.recorrente ? ' (toda a série)' : ''}. '
          'Quem já estava inscrito perde a inscrição. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;

    try {
      await ref.read(shiftServiceProvider).deleteShiftTemplate(shift.id);
      ref.invalidate(upcomingShiftOccurrencesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Escala excluída.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }

  /// Pergunta se e pra excluir so uma ocorrencia ou a serie toda.
  /// Retorna 'uma', 'todas', ou null se cancelou.
  Future<String?> _perguntarEscopo(BuildContext context, String tipoItem) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Essa $tipoItem se repete toda semana'),
        content: const Text('O que você quer excluir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop('uma'),
            child: const Text('Só esta data'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop('todas'),
            child: const Text('Toda a série'),
          ),
        ],
      ),
    );
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
          data: (todasSignups) {
            // So mostra inscricoes ativas -- cancelamentos ficam de fora
            // pra nao poluir a lista (o membro ja sabe que cancelou).
            final signups = todasSignups
                .where((s) =>
                    s.status == SignupStatus.inscrito ||
                    s.status == SignupStatus.checkInFeito)
                .toList();

            if (signups.isEmpty) {
              return const Center(child: Text('Você não tem inscrições ativas no momento.'));
            }

            // Agrupa por dia, na mesma ordem que ja vem (mais proxima primeiro)
            final Map<String, List<SignupModel>> byDate = {};
            final ordemDatas = <String>[];
            for (final s in signups) {
              final key = DateFormat('yyyy-MM-dd').format(s.dataOcorrencia);
              if (!byDate.containsKey(key)) ordemDatas.add(key);
              byDate.putIfAbsent(key, () => []).add(s);
            }

            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: ordemDatas.length,
              itemBuilder: (context, index) {
                final dateKey = ordemDatas[index];
                final doDia = byDate[dateKey]!;
                final data = doDia.first.dataOcorrencia;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text(
                        DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(data),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...doDia.map((signup) {
                      final escala = signup.escala;
                      final nome = escala?['nome'] ?? 'Escala';
                      final canCancel = signup.status == SignupStatus.inscrito;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(nome),
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
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}