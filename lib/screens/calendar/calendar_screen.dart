import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
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
            // Janela ampla o suficiente pra cobrir o mes visivel no calendario
            final rangeStart = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
            final rangeEnd = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

            final Map<DateTime, List<_Occurrence>> byDay = {};
            for (final event in events) {
              for (final occ in event.occurrencesBetween(rangeStart, rangeEnd)) {
                final key = _dateOnly(occ);
                byDay.putIfAbsent(key, () => []).add(_Occurrence(event, occ));
              }
            }

            // Semana de domingo a sabado que contem o dia selecionado.
            // DateTime.weekday: segunda=1 ... domingo=7. "% 7" transforma
            // domingo em 0, o que facilita calcular o inicio da semana.
            final diasDesdeODomingo = _selectedDay.weekday % 7;
            final weekStart =
                _dateOnly(_selectedDay).subtract(Duration(days: diasDesdeODomingo));
            final weekEnd = weekStart.add(const Duration(days: 6));

            final weekOccurrences = <_Occurrence>[];
            for (final event in events) {
              for (final occ in event.occurrencesBetween(weekStart, weekEnd)) {
                weekOccurrences.add(_Occurrence(event, occ));
              }
            }
            weekOccurrences.sort((a, b) => a.data.compareTo(b.data));

            return Column(
              children: [
                TableCalendar<_Occurrence>(
                  locale: 'pt_BR',
                  firstDay: DateTime(2020, 1, 1),
                  lastDay: DateTime(2035, 12, 31),
                  focusedDay: _focusedDay,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) => byDay[_dateOnly(day)] ?? [],
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Eventos da semana '
                      '(${DateFormat('dd/MM').format(weekStart)} a ${DateFormat('dd/MM').format(weekEnd)})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                Expanded(
                  child: weekOccurrences.isEmpty
                      ? const Center(child: Text('Nenhum evento nesta semana.'))
                      : ListView.builder(
                          itemCount: weekOccurrences.length,
                          itemBuilder: (context, index) {
                            final occ = weekOccurrences[index];
                            return ListTile(
                              leading: Icon(
                                occ.event.recorrente ? Icons.repeat : Icons.event,
                              ),
                              title: Text(occ.event.titulo),
                              subtitle: Text(
                                DateFormat("dd/MM (EEEE) HH:mm", 'pt_BR').format(occ.data) +
                                    (occ.event.local != null ? ' • ${occ.event.local}' : ''),
                              ),
                              // Passamos a data exata desta ocorrencia como `extra`,
                              // pra tela de detalhes saber qual data mostrar --
                              // sem isso, ela sempre mostrava a data original
                              // de criacao do evento recorrente.
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