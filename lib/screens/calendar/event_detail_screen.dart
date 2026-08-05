import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: event.cor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(event.labelCategoria, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
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
                if (event.fotoUrl != null) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      event.fotoUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(event.fotoUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Baixar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Share.share(
                            event.fotoUrl!,
                            subject: event.titulo,
                          ),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isLider) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/eventos/novo', extra: event),
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () => _confirmarExclusao(
                            context,
                            ref,
                            eventId,
                            event.titulo,
                            event.recorrente,
                            dataExibida,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String titulo,
    bool recorrente,
    DateTime dataOcorrencia,
  ) async {
    if (recorrente) {
      final escopo = await _perguntarEscopo(context, 'evento');
      if (escopo == null) return;

      if (escopo == 'uma') {
        try {
          await ref.read(eventServiceProvider).deleteOccurrence(eventId, dataOcorrencia);
          ref.invalidate(upcomingEventsProvider);
          if (context.mounted) Navigator.of(context).pop();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
          }
        }
        return;
      }
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir evento?'),
        content: Text(
          'Isso vai apagar "$titulo" permanentemente'
          '${recorrente ? ' (todas as ocorrências da série)' : ''}. '
          'Essa ação não pode ser desfeita.',
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

    if (confirmou != true) return;

    try {
      await ref.read(eventServiceProvider).delete(eventId);
      ref.invalidate(upcomingEventsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }

  Future<String?> _perguntarEscopo(BuildContext context, String tipoItem) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Esse $tipoItem se repete toda semana'),
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
}
