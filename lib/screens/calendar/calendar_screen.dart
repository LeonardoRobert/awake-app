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

  // null = mostrando a visao padrao "proximos 7 dias". Quando a pessoa
  // toca num dia especifico do calendario, isso vira aquele dia, e a
  // lista abaixo passa a mostrar so os eventos daquele dia.
  DateTime? _diaSelecionado;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Calendário'),
      floatingActionButton: isLider
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
              // Visao padrao: proximos 7 dias a partir de hoje
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
            listaExibida.sort((a, b) => a.data.compareTo(b.data));

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
                  calendarStyle: const CalendarStyle(
                    markersMaxCount: 3,
                    markerDecoration: BoxDecoration(
                      color: Color(0xFFFFD21F),
                      shape: BoxShape.circle,
                    ),
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
                          itemCount: listaExibida.length,
                          itemBuilder: (context, index) {
                            final occ = listaExibida[index];
                            return ListTile(
                              leading: Icon(
                                occ.event.recorrente ? Icons.repeat : Icons.event,
                              ),
                              title: Text(occ.event.titulo),
                              subtitle: Text(
                                DateFormat("dd/MM (EEEE) HH:mm", 'pt_BR').format(occ.data) +
                                    (occ.event.local != null ? ' • ${occ.event.local}' : ''),
                              ),
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