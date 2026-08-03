import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/event_model.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Tipos de evento que realmente contam pro check-in / metas. Eventos
/// com tipo "outro" ou "laje" (ex: Celebracao) nao aparecem na lista de
/// check-in -- so o que a gente rastreia de verdade.
const _tiposCheckinValidos = {EventTipo.ebd, EventTipo.gc, EventTipo.comunhao};

/// Tela de check-in do lider: escaneia o QR Code do membro (ou busca
/// pelo nome, se a camera nao conseguir ler), depois escolhe a qual
/// atividade de hoje aquele check-in se refere.
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

  List<String>? _escalaIdsDisponiveis;
  List<String>? _eventoIdsConfirmados;

  Future<void> _selecionarPessoa(String qrCodeId) async {
    if (_qrCodeId != null) return;

    setState(() {
      _qrCodeId = qrCodeId;
      _feedback = null;
      _escalaIdsDisponiveis = null;
      _eventoIdsConfirmados = null;
    });

    final hoje = DateTime.now();
    final status = await ref
        .read(checkinServiceProvider)
        .fetchStatusDoDia(qrCodeId, DateTime(hoje.year, hoje.month, hoje.day));

    if (mounted && _qrCodeId == qrCodeId) {
      setState(() {
        _escalaIdsDisponiveis = status.escalaIds;
        _eventoIdsConfirmados = status.eventoIdsConfirmados;
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    _selecionarPessoa(code);
  }

  void _cancelarSelecao() {
    setState(() {
      _qrCodeId = null;
      _feedback = null;
      _escalaIdsDisponiveis = null;
      _eventoIdsConfirmados = null;
    });
  }

  Future<void> _buscarPorNome() async {
    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _BuscaPorNomeDialog(),
    );
    if (resultado != null) {
      _selecionarPessoa(resultado);
    }
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
        _escalaIdsDisponiveis = null;
        _eventoIdsConfirmados = null;
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

    final carregandoStatus = _escalaIdsDisponiveis == null || _eventoIdsConfirmados == null;

    final targets = <_CheckinTarget>[];

    if (!carregandoStatus) {
      eventsAsync.whenData((events) {
        for (final event in events) {
          if (!_tiposCheckinValidos.contains(event.tipo)) continue;
          if (_eventoIdsConfirmados!.contains(event.id)) continue;

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

      shiftsAsync.whenData((shifts) {
        for (final occ in shifts) {
          final mesmoDia = occ.data.year == todayStart.year &&
              occ.data.month == todayStart.month &&
              occ.data.day == todayStart.day;
          final inscritoNessaEscala = _escalaIdsDisponiveis!.contains(occ.shift.id);
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
      appBar: AwakeAppBar(
        title: 'Check-in',
        actions: [
          if (_qrCodeId == null)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar por nome',
              onPressed: _buscarPorNome,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_qrCodeId == null) MobileScanner(onDetect: _onDetect),
          if (_qrCodeId != null)
            _TargetPicker(
              targets: targets,
              processing: _processing,
              carregando: carregandoStatus,
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

class _BuscaPorNomeDialog extends ConsumerStatefulWidget {
  const _BuscaPorNomeDialog();

  @override
  ConsumerState<_BuscaPorNomeDialog> createState() => _BuscaPorNomeDialogState();
}

class _BuscaPorNomeDialogState extends ConsumerState<_BuscaPorNomeDialog> {
  final _controller = TextEditingController();
  List<({String nome, String qrCodeId})> _resultados = [];
  bool _buscando = false;

  Future<void> _buscar(String texto) async {
    setState(() => _buscando = true);
    final resultados = await ref.read(checkinServiceProvider).buscarPorNome(texto);
    if (mounted) {
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar por nome'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Digite o nome...'),
              onChanged: _buscar,
            ),
            const SizedBox(height: 12),
            if (_buscando) const CircularProgressIndicator(),
            if (!_buscando && _resultados.isEmpty && _controller.text.length >= 2)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Ninguém encontrado.'),
              ),
            if (!_buscando)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resultados.length,
                  itemBuilder: (context, index) {
                    final pessoa = _resultados[index];
                    return ListTile(
                      title: Text(pessoa.nome),
                      onTap: () => Navigator.of(context).pop(pessoa.qrCodeId),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
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
  final bool carregando;
  final VoidCallback onCancel;
  final void Function(_CheckinTarget) onSelect;

  const _TargetPicker({
    required this.targets,
    required this.processing,
    required this.carregando,
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
                'Para qual atividade de hoje é o check-in?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (processing || carregando) const LinearProgressIndicator(),
            Expanded(
              child: carregando
                  ? const Center(child: CircularProgressIndicator())
                  : targets.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nada pendente hoje pra essa pessoa (ou já foi tudo '
                              'confirmado).',
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
                child: const Text('Cancelar / escanear outra pessoa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
