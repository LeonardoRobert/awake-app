import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/erro_amigavel.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

/// Painel de calendario pensado pra uso no NAVEGADOR (tela grande) --
/// deixa o admin ver, criar, editar e excluir eventos de todos os
/// ministerios numa visao maior que a versao mobile. So admin acessa.
///
/// Acesso direto: /admin/calendario
class AdminCalendarioScreen extends ConsumerStatefulWidget {
  const AdminCalendarioScreen({super.key});

  @override
  ConsumerState<AdminCalendarioScreen> createState() =>
      _AdminCalendarioScreenState();
}

class _AdminCalendarioScreenState extends ConsumerState<AdminCalendarioScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _diaSelecionado = DateTime.now();
  _Ocorrencia? _eventoSelecionado;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;

    if (profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile == null || !profile.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Essa página é restrita a administradores.')),
      );
    }

    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Calendário'),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await context.push('/eventos/novo');
              ref.invalidate(upcomingEventsProvider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Novo evento'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar: $err')),
        data: (events) {
          final rangeStart =
              DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
          final rangeEnd = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

          final Map<DateTime, List<_Ocorrencia>> byDay = {};
          for (final event in events) {
            for (final occ in event.occurrencesBetween(rangeStart, rangeEnd)) {
              final key = _dateOnly(occ);
              byDay.putIfAbsent(key, () => []).add(_Ocorrencia(event, occ));
            }
          }

          final ocorrenciasDoDia = byDay[_dateOnly(_diaSelecionado)] ?? [];
          ocorrenciasDoDia.sort((a, b) => a.data.compareTo(b.data));

          return Row(
            children: [
              // Coluna esquerda: calendario + lista do dia
              SizedBox(
                width: 420,
                child: Column(
                  children: [
                    TableCalendar<_Ocorrencia>(
                      locale: 'pt_BR',
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2035, 12, 31),
                      focusedDay: _focusedDay,
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      selectedDayPredicate: (day) =>
                          isSameDay(_diaSelecionado, day),
                      eventLoader: (day) => byDay[_dateOnly(day)] ?? [],
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _diaSelecionado = selected;
                          _focusedDay = focused;
                          _eventoSelecionado = null;
                        });
                      },
                      onPageChanged: (focused) =>
                          setState(() => _focusedDay = focused),
                      calendarBuilders: CalendarBuilders<_Ocorrencia>(
                        markerBuilder: (context, day, eventsForDay) {
                          if (eventsForDay.isEmpty) return null;
                          final cores = eventsForDay
                              .map((e) => e.event.cor)
                              .toSet()
                              .toList();
                          return Positioned(
                            bottom: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: cores
                                  .take(4)
                                  .map((cor) => Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1.5),
                                        decoration: BoxDecoration(
                                            color: cor, shape: BoxShape.circle),
                                      ))
                                  .toList(),
                            ),
                          );
                        },
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold) ??
                            const TextStyle(),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          DateFormat("EEEE, dd 'de' MMMM", 'pt_BR')
                              .format(_diaSelecionado),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ocorrenciasDoDia.isEmpty
                          ? const Center(
                              child: Text('Nenhum evento nesse dia.'))
                          : ListView.builder(
                              itemCount: ocorrenciasDoDia.length,
                              itemBuilder: (context, index) {
                                final oc = ocorrenciasDoDia[index];
                                final selecionado =
                                    _eventoSelecionado?.event.id ==
                                            oc.event.id &&
                                        _eventoSelecionado?.data == oc.data;
                                return ListTile(
                                  selected: selecionado,
                                  leading: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: oc.event.cor,
                                        shape: BoxShape.circle),
                                  ),
                                  title: Text(oc.event.titulo),
                                  subtitle:
                                      Text(DateFormat('HH:mm').format(oc.data)),
                                  onTap: () =>
                                      setState(() => _eventoSelecionado = oc),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Coluna direita: detalhes do evento selecionado
              Expanded(
                child: _eventoSelecionado == null
                    ? const Center(
                        child: Text(
                            'Selecione um evento à esquerda para ver os detalhes.'),
                      )
                    : _PainelDetalhes(
                        ocorrencia: _eventoSelecionado!,
                        onAlterado: () {
                          setState(() => _eventoSelecionado = null);
                          ref.invalidate(upcomingEventsProvider);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ocorrencia {
  final EventModel event;
  final DateTime data;
  _Ocorrencia(this.event, this.data);
}

class _PainelDetalhes extends ConsumerWidget {
  final _Ocorrencia ocorrencia;
  final VoidCallback onAlterado;

  const _PainelDetalhes({required this.ocorrencia, required this.onAlterado});

  String _quemVe(EventModel evento) {
    if (evento.escopo == EventoEscopo.awake) {
      final grupos = evento.publicoAlvo;
      if (grupos == null || grupos.isEmpty) return 'Awake (todos os grupos)';
      final nomes = grupos.map((g) {
        switch (g) {
          case 'genesis':
            return 'Genesis';
          case 'next':
            return 'Next';
          case 'one':
            return 'One';
          default:
            return g;
        }
      }).join(', ');
      return 'Awake ($nomes)';
    }
    return evento.escopo.label;
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final evento = ocorrencia.event;

    String? escopoExclusao = 'todas';
    if (evento.recorrente) {
      escopoExclusao = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Esse evento se repete toda semana'),
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
      if (escopoExclusao == null) return;
    } else {
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Excluir evento?'),
          content: Text('Isso vai apagar "${evento.titulo}" permanentemente.'),
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
      if (confirmou != true) return;
    }

    try {
      final service = ref.read(eventServiceProvider);
      if (escopoExclusao == 'uma') {
        await service.deleteOccurrence(evento.id, ocorrencia.data);
      } else {
        await service.delete(evento.id);
      }
      onAlterado();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao excluir: ${mensagemDeErroAmigavel(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evento = ocorrencia.event;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration:
                      BoxDecoration(color: evento.cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(evento.labelCategoria,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(evento.titulo,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            // Aqui esta a informacao que o admin pediu especificamente:
            // pra quem esse evento e visivel.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Visível para: ${_quemVe(evento)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 8),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(ocorrencia.data)),
              ],
            ),
            if (evento.recorrente) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.repeat, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Repete toda ${DateFormat('EEEE', 'pt_BR').format(evento.dataInicio)}'
                    '${evento.recorrenciaFim != null ? ' até ${DateFormat('dd/MM/yyyy').format(evento.recorrenciaFim!)}' : ''}',
                  ),
                ],
              ),
            ],
            if (evento.local != null && evento.local!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place, size: 18),
                  const SizedBox(width: 8),
                  Text(evento.local!),
                ],
              ),
            ],
            if (evento.descricao != null && evento.descricao!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(evento.descricao!),
            ],
            if (evento.fotoUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(evento.fotoUrl!, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.push('/eventos/novo', extra: evento);
                    onAlterado();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _excluir(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
