import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela de check-in do lider: escaneia o QR Code do membro primeiro,
/// depois escolhe a qual atividade de hoje (evento do calendario ou
/// escala de voluntariado) aquele check-in se refere.
///
/// Eventos do dia aparecem todos (nao exigem inscricao previa). Ja as
/// escalas so mostram as que a PESSOA ESCANEADA especificamente esta
/// inscrita naquele dia -- nao todas as escalas do dia.
class CheckinScannerScreen extends ConsumerStatefulWidget {
  const CheckinScannerScreen({super.key});

  @override
  ConsumerState<CheckinScannerScreen> createState() => _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends ConsumerState<CheckinScannerScreen> {
  String? _qrCodeId;
  bool _processing = false;
  String? _feedback;
  bool _feedbackIsError = false;

  // null enquanto ainda esta buscando; lista vazia = pessoa nao esta
  // inscrita em nenhuma escala hoje.
  List<String>? _escalaIdsPermitidos;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_qrCodeId != null) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _qrCodeId = code;
      _feedback = null;
      _escalaIdsPermitidos = null; // dispara o "carregando" no picker
    });

    final hoje = DateTime.now();
    final ids = await ref
        .read(checkinServiceProvider)
        .fetchEscalaIdsInscritosNaData(code, DateTime(hoje.year, hoje.month, hoje.day));

    if (mounted && _qrCodeId == code) {
      setState(() => _escalaIdsPermitidos = ids);
    }
  }

  void _cancelarSelecao() {
    setState(() {
      _qrCodeId = null;
      _feedback = null;
      _escalaIdsPermitidos = null;
    });
  }

  Future<void> _confirmarCheckin(_CheckinTarget target) async {
    setState(() => _processing = true);
    try {
      final service = ref.read(checkinServiceProvider);
      final String nome;
      if (target.tipo == _TipoAlvo.escala) {
        nome = await service.checkInEscala(
          qrCodeId: _qrCodeId!,
          escalaId: target.id,
          dataOcorrencia: target.data,
        );
      } else {
        nome = await service.checkInEvento(
          qrCodeId: _qrCodeId!,
          eventoId: target.id,
          dataOcorrencia: target.data,
        );
      }
      setState(() {
        _feedback = 'Check-in confirmado: $nome em "${target.label}"';
        _feedbackIsError = false;
      });
    } catch (e) {
      setState(() {
        _feedback = 'Não foi possível confirmar: $e';
        _feedbackIsError = true;
      });
    } finally {
      setState(() {
        _processing = false;
        _qrCodeId = null;
        _escalaIdsPermitidos = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final shiftsAsync = ref.watch(upcomingShiftOccurrencesProvider);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(hours: 23, minutes: 59));

    final targets = <_CheckinTarget>[];

    // Eventos: todos os de hoje aparecem, sem restricao (nao exigem
    // inscricao previa).
    eventsAsync.whenData((events) {
      for (final event in events) {
        for (final occ in event.occurrencesBetween(todayStart, todayEnd)) {
          targets.add(_CheckinTarget(
            tipo: _TipoAlvo.evento,
            id: event.id,
            label: event.titulo,
            horario: DateFormat('HH:mm').format(occ),
            data: DateTime(occ.year, occ.month, occ.day),
          ));
        }
      }
    });

    // Escalas: so entram na lista se a pessoa escaneada estiver
    // inscrita nelas (filtro por _escalaIdsPermitidos).
    if (_escalaIdsPermitidos != null) {
      shiftsAsync.whenData((shifts) {
        for (final occ in shifts) {
          final mesmoDia = occ.data.year == todayStart.year &&
              occ.data.month == todayStart.month &&
              occ.data.day == todayStart.day;
          final inscritoNessaEscala = _escalaIdsPermitidos!.contains(occ.shift.id);
          if (mesmoDia && inscritoNessaEscala) {
            targets.add(_CheckinTarget(
              tipo: _TipoAlvo.escala,
              id: occ.shift.id,
              label: occ.shift.nome,
              horario: occ.shift.horarioInicio,
              data: occ.data,
            ));
          }
        }
      });
    }

    targets.sort((a, b) => a.horario.compareTo(b.horario));

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Check-in'),
      body: Stack(
        children: [
          if (_qrCodeId == null) MobileScanner(onDetect: _onDetect),
          if (_qrCodeId != null)
            _TargetPicker(
              targets: targets,
              processing: _processing,
              carregandoEscalas: _escalaIdsPermitidos == null,
              onCancel: _cancelarSelecao,
              onSelect: _confirmarCheckin,
            ),
          if (_feedback != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                color: _feedbackIsError ? Colors.red.shade100 : Colors.green.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_feedback!, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _TipoAlvo { escala, evento }

class _CheckinTarget {
  final _TipoAlvo tipo;
  final String id;
  final String label;
  final String horario;
  final DateTime data;

  _CheckinTarget({
    required this.tipo,
    required this.id,
    required this.label,
    required this.horario,
    required this.data,
  });
}

class _TargetPicker extends StatelessWidget {
  final List<_CheckinTarget> targets;
  final bool processing;
  final bool carregandoEscalas;
  final VoidCallback onCancel;
  final void Function(_CheckinTarget) onSelect;

  const _TargetPicker({
    required this.targets,
    required this.processing,
    required this.carregandoEscalas,
    required this.onCancel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'QR Code lido. Para qual atividade de hoje é o check-in?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (processing || carregandoEscalas) const LinearProgressIndicator(),
            Expanded(
              child: carregandoEscalas
                  ? const Center(child: CircularProgressIndicator())
                  : targets.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nenhum evento hoje, e essa pessoa não está inscrita '
                              'em nenhuma escala hoje.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: targets.length,
                          itemBuilder: (context, index) {
                            final target = targets[index];
                            return ListTile(
                              leading: Icon(
                                target.tipo == _TipoAlvo.escala
                                    ? Icons.volunteer_activism
                                    : Icons.event,
                              ),
                              title: Text(target.label),
                              subtitle: Text(
                                target.tipo == _TipoAlvo.escala
                                    ? 'Escala • ${target.horario}'
                                    : 'Evento • ${target.horario}',
                              ),
                              onTap: processing ? null : () => onSelect(target),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: processing ? null : onCancel,
                child: const Text('Cancelar / escanear outro QR Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}