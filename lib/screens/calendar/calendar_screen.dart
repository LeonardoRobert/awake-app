import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/awake_app_bar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _diaSelecionado;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    // Diferente da Escala/Check-in (que sao coisas so do Awake), criar
    // evento no calendario e permitido pra lider de QUALQUER ministerio
    // (ou admin) -- por isso usa esse getter, nao o "isLider" comum.
    final podeGerenciarEventos = profileAsync.value?.ehLiderDeAlgumMinisterio ?? false;

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Calendário'),
      floatingActionButton: podeGerenciarEventos
          ? FloatingActionButton.small(
              heroTag: 'fab-calendario',
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
            final rangeStart = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
            final rangeEnd = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

            final Map<DateTime, List<_Occurrence>> byDay = {};
            for (final event in events) {
              for (final occ in event.occurrencesBetween(rangeStart, rangeEnd)) {
                final key = _dateOnly(occ);
                byDay.putIfAbsent(key, () => []).add(_Occurrence(event, occ));
              }
            }

            final hoje = _dateOnly(DateTime.now());
            final List<_Occurrence> listaExibida;
            final String tituloLista;

            if (_diaSelecionado == null) {
              final fim = hoje.add(const Duration(days: 6));
              listaExibida = [];
              for (final event in events) {
                for (final occ in event.occurrencesBetween(hoje, fim)) {
                  listaExibida.add(_Occurrence(event, occ));
                }
              }
              tituloLista = 'Próximos 7 dias';
            } else {
              listaExibida = byDay[_dateOnly(_diaSelecionado!)] ?? [];
              tituloLista = 'Eventos de ${DateFormat("dd/MM (EEEE)", 'pt_BR').format(_diaSelecionado!)}';
            }
            listaExibida.sort(_compararOcorrencias);

            return Column(
              children: [
                TableCalendar<_Occurrence>(
                  locale: 'pt_BR',
                  firstDay: DateTime(2020, 1, 1),
                  lastDay: DateTime(2035, 12, 31),
                  focusedDay: _focusedDay,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  selectedDayPredicate: (day) =>
                      _diaSelecionado != null && isSameDay(_diaSelecionado, day),
                  eventLoader: (day) => byDay[_dateOnly(day)] ?? [],
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _diaSelecionado = selected;
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    setState(() => _focusedDay = focused);
                  },
                  calendarStyle: const CalendarStyle(),
                  calendarBuilders: CalendarBuilders<_Occurrence>(
                    // Uma bolinha colorida por CATEGORIA presente no dia
                    // (nao uma por evento) -- um dia com 3 eventos da
                    // mesma categoria mostra so 1 bolinha daquela cor.
                    markerBuilder: (context, day, eventsForDay) {
                      if (eventsForDay.isEmpty) return null;
                      final cores = eventsForDay.map((e) => e.event.cor).toSet().toList();

                      return Positioned(
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: cores
                              .take(4)
                              .map((cor) => Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                    decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tituloLista,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (_diaSelecionado != null)
                        TextButton(
                          onPressed: () => setState(() => _diaSelecionado = null),
                          child: const Text('Ver próximos 7 dias'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: listaExibida.isEmpty
                      ? const Center(child: Text('Nenhum evento neste período.'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: listaExibida.length,
                          itemBuilder: (context, index) {
                            final occ = listaExibida[index];
                            return ListTile(
                              leading: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: occ.event.cor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(occ.event.titulo),
                              subtitle: Text(
                                '${occ.event.labelCategoria} • ' +
                                    DateFormat("dd/MM (EEEE) HH:mm", 'pt_BR').format(occ.data) +
                                    (occ.event.local != null ? ' • ${occ.event.local}' : ''),
                              ),
                              trailing: occ.event.recorrente
                                  ? const Icon(Icons.repeat, size: 18)
                                  : null,
                              onTap: () => context.push(
                                '/eventos/${occ.event.id}',
                                extra: occ.data,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Occurrence {
  final EventModel event;
  final DateTime data;
  _Occurrence(this.event, this.data);
}

int _compararOcorrencias(_Occurrence a, _Occurrence b) {
  final porData = a.data.compareTo(b.data);
  if (porData != 0) return porData;
  // Empate no dia/horario: primeiro pela ordem oficial das categorias
  // (Igreja, Lideranca, Casais, Homens, Mulheres, Awake, Embaixadores
  // e Mensageiras, Criancas)...
  final porEscopo = a.event.escopo.prioridade.compareTo(b.event.escopo.prioridade);
  if (porEscopo != 0) return porEscopo;
  // ...e, se os dois forem do Awake, por subgrupo: Genesis, Next, One.
  if (a.event.escopo == EventoEscopo.awake) {
    return _prioridadeGrupo(a.event).compareTo(_prioridadeGrupo(b.event));
  }
  return 0;
}

int _prioridadeGrupo(EventModel evento) {
  final grupos = evento.publicoAlvo;
  if (grupos == null || grupos.isEmpty) return 99;
  if (grupos.contains('genesis')) return 0;
  if (grupos.contains('next')) return 1;
  if (grupos.contains('one')) return 2;
  return 99;
}