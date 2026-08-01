import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      floatingActionButton: isLider
          ? FloatingActionButton(
              onPressed: () => context.push('/eventos/novo'),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(upcomingEventsProvider.future),
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro ao carregar eventos: $err')),
          data: (events) {
            if (events.isEmpty) {
              return const Center(child: Text('Nenhum evento marcado ainda.'));
            }
            return ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(event.titulo),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(event.dataInicio) +
                        (event.local != null ? ' - ${event.local}' : ''),
                  ),
                  onTap: () => context.push('/eventos/${event.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
