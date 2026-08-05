import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/filho_provider.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/evento_semana_card.dart';

/// Tela de Inicio pra quem NAO e Awake (Homens, Mulheres). Mostra
/// "Essa semana no ministério de [Nome]" pra cada ministerio da
/// pessoa, mais "Crianças" se ela tiver filho ate 12 anos cadastrado,
/// e embaixo "Essa semana na Shallom" com os eventos gerais.
class InicioShallomScreen extends ConsumerWidget {
  const InicioShallomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final filhosAsync = ref.watch(meusFilhosProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Início'),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(upcomingEventsProvider.future),
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro ao carregar: $err')),
          data: (events) {
            final profile = profileAsync.value;
            final ministerios = profile?.ministerios
                    .where((m) => m.ministerio != 'awake')
                    .map((m) => m.ministerio)
                    .toList() ??
                const <String>[];

            // Tem filho ate 12 anos cadastrado? Se sim, tambem mostra
            // a secao de Criancas, mesmo sem "pertencer" ao ministerio.
            final temFilhoAte12 = (filhosAsync.value ?? const [])
                .any((f) => f.idade <= 12);

            final now = DateTime.now();
            final hoje = DateTime(now.year, now.month, now.day);
            final fim = hoje.add(const Duration(days: 6));

            final eventosShallom = <Ocorrencia>[];
            for (final event in events) {
              if (event.escopo != EventoEscopo.igreja) continue;
              for (final occ in event.occurrencesBetween(hoje, fim)) {
                eventosShallom.add(Ocorrencia(event, occ));
              }
            }
            eventosShallom.sort(compararOcorrencias);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
              children: [
                for (final ministerio in ministerios) ...[
                  Text('Essa semana no ministério de ${ministerio.labelMinisterio}',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  ..._eventosDoEscopo(
                    events,
                    eventoEscopoFromString(ministerio),
                    ministerio.labelMinisterio,
                    hoje,
                    fim,
                  ),
                  const SizedBox(height: 12),
                ],
                if (temFilhoAte12) ...[
                  Text('Essa semana no ministério de Crianças',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  ..._eventosDoEscopo(
                    events,
                    EventoEscopo.criancas,
                    'Crianças',
                    hoje,
                    fim,
                  ),
                  const SizedBox(height: 12),
                ],
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

  List<Widget> _eventosDoEscopo(
    List<EventModel> events,
    EventoEscopo escopo,
    String nomeExibicao,
    DateTime hoje,
    DateTime fim,
  ) {
    final ocorrencias = <Ocorrencia>[];
    for (final event in events) {
      if (event.escopo != escopo) continue;
      for (final occ in event.occurrencesBetween(hoje, fim)) {
        ocorrencias.add(Ocorrencia(event, occ));
      }
    }
    ocorrencias.sort(compararOcorrencias);

    if (ocorrencias.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('Nenhum evento do ministério de $nomeExibicao essa semana.'),
        ),
      ];
    }

    return ocorrencias.map((oc) => EventoSemanaCard(ocorrencia: oc)).toList();
  }
}
