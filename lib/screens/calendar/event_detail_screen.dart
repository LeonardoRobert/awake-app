import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  /// Data especifica da ocorrencia que foi tocada (relevante so para
  /// eventos recorrentes -- para eventos normais, e igual a dataInicio).
  /// Se nao vier informado (ex: acesso direto por link), cai de volta
  /// para a data original do evento.
  final DateTime? occurrenceDate;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.occurrenceDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do evento')),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (events) {
          final matches = events.where((e) => e.id == eventId);
          final event = matches.isEmpty ? null : matches.first;
          if (event == null) {
            return const Center(child: Text('Evento nao encontrado.'));
          }

          final dataExibida = occurrenceDate ?? event.dataInicio;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.titulo, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(dataExibida)),
                  ],
                ),
                if (event.recorrente) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.repeat, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Repete toda ${DateFormat('EEEE', 'pt_BR').format(event.dataInicio)}'
                        '${event.recorrenciaFim != null ? ' até ${DateFormat('dd/MM/yyyy').format(event.recorrenciaFim!)}' : ''}',
                      ),
                    ],
                  ),
                ],
                if (event.local != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 18),
                      const SizedBox(width: 8),
                      Text(event.local!),
                    ],
                  ),
                ],
                if (event.descricao != null) ...[
                  const SizedBox(height: 16),
                  Text(event.descricao!),
                ],
                if (isLider) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/eventos/novo', extra: event),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar evento'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}