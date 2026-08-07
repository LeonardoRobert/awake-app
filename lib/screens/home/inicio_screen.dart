import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/escala_servico_model.dart';
import '../../providers/event_provider.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/evento_semana_card.dart';

/// Tela de Inicio -- igual pra todo mundo (Awake, Homens, Mulheres...).
/// Mostra todos os eventos que a pessoa pode ver nos proximos 7 dias,
/// numa lista so, sem dividir por ministerio/categoria -- quem decide
/// o que aparece aqui e o banco (RLS), nao essa tela.
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

            final ocorrencias = <Ocorrencia>[];
            for (final event in events) {
              for (final occ in event.occurrencesBetween(hoje, fim)) {
                // So entra se ainda nao passou do horario de inicio --
                // um evento de hoje de manha nao deve continuar
                // aparecendo como "proximo" a tarde.
                if (occ.isAfter(now)) {
                  ocorrencias.add(Ocorrencia(event, occ));
                }
              }
            }
            ocorrencias.sort(compararOcorrencias);

            return FutureBuilder<List<MinhaEscalaResumo>>(
              future: EscalaServicoService().buscarMinhaEscala(hoje, fim),
              builder: (context, snapshotEscalas) {
                final minhasEscalas = snapshotEscalas.data ?? [];

                MinhaEscalaResumo? escalaPara(Ocorrencia oc) {
                  for (final e in minhasEscalas) {
                    if (e.eventoId == oc.event.id &&
                        e.dataOcorrencia.year == oc.data.year &&
                        e.dataOcorrencia.month == oc.data.month &&
                        e.dataOcorrencia.day == oc.data.day) {
                      return e;
                    }
                  }
                  return null;
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                  children: [
                    Text('Próximos eventos:', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    if (ocorrencias.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Nenhum evento nos próximos 7 dias.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...ocorrencias.map((oc) => EventoSemanaCard(
                            ocorrencia: oc,
                            escalaAqui: escalaPara(oc),
                          )),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}