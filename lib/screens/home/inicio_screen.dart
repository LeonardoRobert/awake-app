import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/evento_semana_card.dart';

/// Tela de Inicio do Awake: mostra os eventos de SEXTA-FEIRA marcados
/// como "Exclusivo Awake" da semana, e logo abaixo os eventos GERAIS
/// da igreja (Shallom) da mesma semana.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Início'),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(upcomingEventsProvider.future),
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro ao carregar: $err')),
          data: (events) {
            final now = DateTime.now();
            final hoje = DateTime(now.year, now.month, now.day);
            final fim = hoje.add(const Duration(days: 6));

            final eventosAwake = <Ocorrencia>[];
            for (final event in events) {
              if (event.escopo != EventoEscopo.awake) continue;
              for (final occ in event.occurrencesBetween(hoje, fim)) {
                if (occ.weekday == DateTime.friday) {
                  eventosAwake.add(Ocorrencia(event, occ));
                }
              }
            }
            eventosAwake.sort(compararOcorrencias);

            final eventosShallom = <Ocorrencia>[];
            for (final event in events) {
              // "Shallom" mostra so os eventos GERAIS (escopo Igreja) --
              // eventos exclusivos de outro ministerio aparecem so na
              // tela de Inicio proprio desse ministerio.
              if (event.escopo != EventoEscopo.igreja) continue;
              for (final occ in event.occurrencesBetween(hoje, fim)) {
                eventosShallom.add(Ocorrencia(event, occ));
              }
            }
            eventosShallom.sort(compararOcorrencias);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
              children: [
                Text('Essa semana na Awake! 🔥',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                if (eventosAwake.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Nenhum evento de sexta-feira da Awake essa semana.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...eventosAwake.map((oc) => EventoSemanaCard(ocorrencia: oc)),
                const SizedBox(height: 12),
                Text('Essa semana na Shallom',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                if (eventosShallom.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Nenhum evento geral da igreja essa semana.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...eventosShallom.map((oc) => EventoSemanaCard(ocorrencia: oc)),
              ],
            );
          },
        ),
      ),
    );
  }
}
