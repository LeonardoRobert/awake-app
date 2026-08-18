import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/escala_servico_model.dart';
import '../../models/event_model.dart';
import '../../models/shift_model.dart';
import '../../models/signup_model.dart';
import '../../providers/contribuicao_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/outdoor_provider.dart';
import '../../services/escala_servico_service.dart';
import '../../services/shift_service.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/evento_semana_card.dart';
import '../../widgets/outdoor_slideshow.dart';

/// Tela de Inicio -- igual pra todo mundo (Awake, Homens, Mulheres...).
/// Mostra todos os eventos que a pessoa pode ver nos proximos 7 dias,
/// numa lista so, sem dividir por ministerio/categoria -- quem decide
/// o que aparece aqui e o banco (RLS), nao essa tela.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final outdoorsAsync = ref.watch(outdoorsAtivosProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Início'),
      body: RefreshIndicator(
        onRefresh: () {
          // Invalida TODAS as instancias de totalPagoEventoProvider (nao
          // sabemos ainda qual e o evento ingressado aqui em cima) --
          // sem isso a tarja nunca refaz a busca sozinha, porque a tela
          // de Inicio fica sempre viva dentro do IndexedStack e nunca
          // desmonta pra "renascer" com o valor pago atualizado.
          ref.invalidate(totalPagoEventoProvider);
          return Future.wait([
            ref.refresh(upcomingEventsProvider.future),
            ref.refresh(outdoorsAtivosProvider.future),
          ]);
        },
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

            // Evento ingressado mais proximo (ainda nao aconteceu) --
            // mostrado numa tarja, acima da lista de proximos eventos.
            final eventosIngressados = events
                .where((e) => e.ingressado && e.dataInicio.isAfter(now))
                .toList()
              ..sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
            final eventoIngressado =
                eventosIngressados.isEmpty ? null : eventosIngressados.first;

            return FutureBuilder<(List<MinhaEscalaResumo>, List<SignupModel>)>(
              future: (
                EscalaServicoService().buscarMinhaEscala(hoje, fim),
                ShiftService().listMySignups(),
              ).wait,
              builder: (context, snapshotEscalas) {
                final minhasEscalas = snapshotEscalas.data?.$1 ?? [];
                final minhasInscricoesAwake = snapshotEscalas.data?.$2 ?? [];

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

                // Escala Awake (areas_servico/escalas/inscricoes) e um
                // sistema separado dos eventos do calendario -- nao tem
                // EventoSemanaCard pra anexar a tarja, entao mostra
                // como tarjas proprias, junto com o evento ingressado.
                final escalasAwakeNaSemana = minhasInscricoesAwake.where((s) {
                  final ativa = s.status == SignupStatus.inscrito ||
                      s.status == SignupStatus.checkInFeito;
                  final dentroDaSemana = !s.dataOcorrencia.isBefore(hoje) &&
                      !s.dataOcorrencia.isAfter(fim);
                  return ativa && dentroDaSemana;
                }).toList()
                  ..sort(
                      (a, b) => a.dataOcorrencia.compareTo(b.dataOcorrencia));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                  children: [
                    if ((outdoorsAsync.value ?? []).isNotEmpty) ...[
                      // Rotulo pequeno acima do slideshow -- sem isso,
                      // o outdoor (so uma foto arredondada) ficava
                      // parecido demais com a capa de um card de
                      // evento (que tem titulo/horario/local antes da
                      // foto, e o outdoor nao tinha nada disso).
                      Text(
                        'Avisos',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      OutdoorSlideshow(outdoors: outdoorsAsync.value!),
                      const SizedBox(height: 20),
                    ],
                    if (eventoIngressado != null) ...[
                      _TarjaEventoIngressado(evento: eventoIngressado),
                      const SizedBox(height: 20),
                    ],
                    if (escalasAwakeNaSemana.isNotEmpty) ...[
                      ...escalasAwakeNaSemana.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TarjaEscalaAwake(inscricao: s),
                          )),
                      const SizedBox(height: 12),
                    ],
                    Text('Próximos eventos:',
                        style: Theme.of(context).textTheme.headlineSmall),
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

/// Tarja com o nome do evento ingressado (ex: "Conferência Awake 2026")
/// e uma barra mostrando quanto a pessoa ja pagou daquele valor total.
/// Aparece pra todo mundo que ve o evento, mesmo com 0% pago ainda --
/// a barra so anda quando o Admin Financeiro lanca um pagamento pra
/// essa pessoa vinculado a esse evento.
class _TarjaEventoIngressado extends ConsumerWidget {
  final EventModel evento;
  const _TarjaEventoIngressado({required this.evento});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valorTotal = evento.valorTotal ?? 0;
    final totalPagoAsync = ref.watch(totalPagoEventoProvider(evento.id));
    final totalPago = totalPagoAsync.value ?? 0;
    final progresso =
        valorTotal > 0 ? (totalPago / valorTotal).clamp(0.0, 1.0) : 0.0;
    final porcentagem = (progresso * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () =>
          context.push('/eventos/${evento.id}', extra: evento.dataInicio),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_num_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evento.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 8,
                backgroundColor: Colors.black.withOpacity(0.08),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              totalPagoAsync.isLoading
                  ? 'Carregando...'
                  : '$porcentagem% pago — R\$ ${totalPago.toStringAsFixed(2)} de '
                      'R\$ ${valorTotal.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarja igual, na aparencia, a "Voce esta escalado(a)" que ja aparece
/// dentro do EventoSemanaCard pros ministerios de servico -- mas essa
/// aqui e uma tarja PROPRIA (nao embutida num card de evento), porque
/// a Escala Awake (areas_servico/escalas/inscricoes) e um sistema a
/// parte, sem vinculo com a tabela eventos.
class _TarjaEscalaAwake extends StatelessWidget {
  final SignupModel inscricao;
  const _TarjaEscalaAwake({required this.inscricao});

  @override
  Widget build(BuildContext context) {
    final escala =
        inscricao.escala != null ? ShiftModel.fromMap(inscricao.escala!) : null;
    final nomeEscala = escala?.nome ?? 'Escala';
    final nomeArea = escala?.area?.nome;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Você está escalado(a): $nomeEscala (Awake)'
              '${nomeArea != null ? ' — $nomeArea' : ''} • '
              '${DateFormat("EEEE, dd/MM", 'pt_BR').format(inscricao.dataOcorrencia)}'
              '${escala != null ? ' às ${escala.horarioInicio}' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
