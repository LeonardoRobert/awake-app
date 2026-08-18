import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/escala_fluxo.dart';
import 'outdoor_form_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _diaSelecionado;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Admin escolhe entre "Criar evento" e "Criar outdoor" antes de ir
  /// pra tela certa; lider de ministerio (nao-admin) so pode criar
  /// evento, entao vai direto, sem esse passo extra.
  Future<void> _onTapCriar(bool isAdmin) async {
    // Se tem um dia selecionado no calendario, pre-preenche a data do
    // formulario com ELE (so a data -- a hora continua a atual,
    // editavel normalmente igual antes) em vez de sempre cair em
    // "agora". EventFormScreen ja aceita isso via ?data= (dataInicial).
    var rotaEvento = '/eventos/novo';
    if (_diaSelecionado != null) {
      final agora = DateTime.now();
      final dataComHoraAtual = DateTime(
        _diaSelecionado!.year,
        _diaSelecionado!.month,
        _diaSelecionado!.day,
        agora.hour,
        agora.minute,
      );
      rotaEvento =
          '/eventos/novo?data=${Uri.encodeComponent(dataComHoraAtual.toIso8601String())}';
    }

    if (!isAdmin) {
      context.push(rotaEvento);
      return;
    }

    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Criar evento'),
              onTap: () => Navigator.of(bottomSheetContext).pop('evento'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Criar outdoor'),
              subtitle: const Text('Banner no slideshow da tela de Início'),
              onTap: () => Navigator.of(bottomSheetContext).pop('outdoor'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (escolha == 'evento') {
      context.push(rotaEvento);
    } else if (escolha == 'outdoor') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OutdoorFormScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    // Diferente da Escala/Check-in (que sao coisas so do Awake), criar
    // evento no calendario e permitido pra lider de QUALQUER ministerio
    // (ou admin) -- por isso usa esse getter, nao o "isLider" comum.
    final podeGerenciarEventos =
        profileAsync.value?.ehLiderDeAlgumMinisterio ?? false;
    final isAdmin = profileAsync.value?.isAdmin ?? false;
    final ministeriosLideradosServico = (profileAsync.value?.ministerios ?? [])
        .where((m) =>
            m.ehLider && ministeriosComEscalaServico.contains(m.ministerio))
        .toList();
    final eventosIgreja = (eventsAsync.value ?? [])
        .where((e) => e.escopo == EventoEscopo.igreja)
        .toList();

    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Calendário',
        actions: [
          IconButton(
            tooltip: 'Ir para hoje',
            icon: const CircleAvatar(
              radius: 12,
              child: Icon(Icons.today, size: 14),
            ),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _diaSelecionado = null;
              });
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ministeriosLideradosServico.isNotEmpty) ...[
            FloatingActionButton.small(
              heroTag: 'fab-escala',
              tooltip: 'Escala',
              onPressed: () => abrirFluxoEscala(
                context,
                ministeriosLiderados: ministeriosLideradosServico,
                eventosIgreja: eventosIgreja,
              ),
              child: const Icon(Icons.event_note_outlined),
            ),
            const SizedBox(height: 12),
          ],
          if (podeGerenciarEventos)
            FloatingActionButton.small(
              heroTag: 'fab-calendario',
              onPressed: () => _onTapCriar(isAdmin),
              child: const Icon(Icons.add),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(upcomingEventsProvider.future),
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Center(child: Text('Erro ao carregar eventos: $err')),
          data: (events) {
            final rangeStart =
                DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
            final rangeEnd =
                DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

            final Map<DateTime, List<_Occurrence>> byDay = {};
            for (final event in events) {
              for (final occ
                  in event.occurrencesBetween(rangeStart, rangeEnd)) {
                final key = _dateOnly(occ);
                byDay.putIfAbsent(key, () => []).add(_Occurrence(event, occ));
              }
            }

            final hoje = _dateOnly(DateTime.now());
            final List<_Occurrence> listaExibida;
            final String tituloLista;

            if (_diaSelecionado == null) {
              final agora = DateTime.now();
              final fim = hoje.add(const Duration(days: 6));
              listaExibida = [];
              for (final event in events) {
                for (final occ in event.occurrencesBetween(hoje, fim)) {
                  // So entra se ainda nao passou do horario -- um
                  // evento de hoje de manha nao deve continuar
                  // aparecendo aqui a tarde.
                  if (occ.isAfter(agora)) {
                    listaExibida.add(_Occurrence(event, occ));
                  }
                }
              }
              tituloLista = 'Próximos 7 dias';
            } else {
              listaExibida = byDay[_dateOnly(_diaSelecionado!)] ?? [];
              tituloLista =
                  'Eventos de ${DateFormat("dd/MM (EEEE)", 'pt_BR').format(_diaSelecionado!)}';
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
                      _diaSelecionado != null &&
                      isSameDay(_diaSelecionado, day),
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
                      final cores =
                          eventsForDay.map((e) => e.event.cor).toSet().toList();

                      return Positioned(
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: cores
                              .take(4)
                              .map((cor) => Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5),
                                    decoration: BoxDecoration(
                                        color: cor, shape: BoxShape.circle),
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold) ??
                        const TextStyle(),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_diaSelecionado != null)
                        TextButton(
                          onPressed: () =>
                              setState(() => _diaSelecionado = null),
                          child: const Text('Ver próximos 7 dias'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: listaExibida.isEmpty
                      ? const Center(
                          child: Text('Nenhum evento neste período.'))
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
                                    DateFormat("dd/MM (EEEE) HH:mm", 'pt_BR')
                                        .format(occ.data) +
                                    (occ.event.local != null
                                        ? ' • ${occ.event.local}'
                                        : ''),
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
  final porEscopo =
      a.event.escopo.prioridade.compareTo(b.event.escopo.prioridade);
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
