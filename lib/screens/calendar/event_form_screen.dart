import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';

/// Tela de criacao/edicao de evento, disponivel apenas para lider/admin.
/// Se `eventoParaEditar` for informado, a tela entra em modo de edicao.
class EventFormScreen extends ConsumerStatefulWidget {
  final EventModel? eventoParaEditar;
  const EventFormScreen({super.key, this.eventoParaEditar});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _localController;
  DateTime? _dataInicio;
  bool _recorrente = false;
  DateTime? _recorrenciaFim;
  EventTipo _tipo = EventTipo.outro;
  bool _saving = false;

  // Publico-alvo: se _paraTodos for true, publico_alvo fica null (todos
  // veem). Caso contrario, so quem for de uma das categorias marcadas
  // aqui consegue ver o evento (lideres/admin sempre veem tudo).
  bool _paraTodos = true;
  final Set<String> _categoriasSelecionadas = {};

  bool get _isEdicao => widget.eventoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final evento = widget.eventoParaEditar;
    _tituloController = TextEditingController(text: evento?.titulo ?? '');
    _descricaoController = TextEditingController(text: evento?.descricao ?? '');
    _localController = TextEditingController(text: evento?.local ?? '');
    _dataInicio = evento?.dataInicio;
    _recorrente = evento?.recorrente ?? false;
    _recorrenciaFim = evento?.recorrenciaFim;
    _tipo = evento?.tipo ?? EventTipo.outro;

    final publicoExistente = evento?.publicoAlvo;
    if (publicoExistente != null && publicoExistente.isNotEmpty) {
      _paraTodos = false;
      _categoriasSelecionadas.addAll(publicoExistente);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime:
          _dataInicio != null ? TimeOfDay.fromDateTime(_dataInicio!) : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _dataInicio = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickRecorrenciaFim() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recorrenciaFim ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date != null) setState(() => _recorrenciaFim = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _dataInicio == null) {
      if (_dataInicio == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione a data e hora do evento.')),
        );
      }
      return;
    }
    if (!_paraTodos && _categoriasSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um grupo, ou marque "Para todos".')),
      );
      return;
    }

    setState(() => _saving = true);

    final novoEvento = EventModel(
      id: widget.eventoParaEditar?.id ?? '',
      titulo: _tituloController.text.trim(),
      descricao: _descricaoController.text.trim(),
      dataInicio: _dataInicio!,
      local: _localController.text.trim(),
      recorrente: _recorrente,
      recorrenciaFim: _recorrente ? _recorrenciaFim : null,
      tipo: _tipo,
      publicoAlvo: _paraTodos ? null : _categoriasSelecionadas.toList(),
    );

    try {
      final service = ref.read(eventServiceProvider);
      if (_isEdicao) {
        await service.update(widget.eventoParaEditar!.id, novoEvento);
      } else {
        await service.create(novoEvento);
      }
      ref.invalidate(upcomingEventsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar evento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdicao ? 'Editar evento' : 'Novo evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Titulo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um titulo' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventTipo>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de evento',
                  helperText: 'Usado para contar as metas mensais dos membros',
                ),
                items: EventTipo.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v ?? EventTipo.outro),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(labelText: 'Descricao'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _localController,
                decoration: const InputDecoration(labelText: 'Local'),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data e hora'),
                  child: Text(
                    _dataInicio == null
                        ? 'Selecionar data e hora'
                        : DateFormat('dd/MM/yyyy HH:mm').format(_dataInicio!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _recorrente,
                onChanged: (v) => setState(() => _recorrente = v),
                title: const Text('Evento recorrente'),
                subtitle: Text(
                  _dataInicio == null
                      ? 'Repete toda semana, no mesmo dia e horario'
                      : 'Repete toda ${DateFormat('EEEE', 'pt_BR').format(_dataInicio!)}'
                          ' às ${DateFormat('HH:mm').format(_dataInicio!)}',
                ),
              ),
              if (_recorrente) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickRecorrenciaFim,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Repetir até (opcional)',
                      helperText: 'Deixe em branco para repetir por tempo indeterminado',
                    ),
                    child: Text(
                      _recorrenciaFim == null
                          ? 'Sem data de término'
                          : DateFormat('dd/MM/yyyy').format(_recorrenciaFim!),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text('Quem pode ver esse evento?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Todos')),
                  ButtonSegment(value: false, label: Text('Grupos específicos')),
                ],
                selected: {_paraTodos},
                onSelectionChanged: (value) => setState(() => _paraTodos = value.first),
              ),
              if (!_paraTodos) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _grupoChip('genesis', 'Genesis'),
                    _grupoChip('next', 'Next'),
                    _grupoChip('one', 'One'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Líderes e admin sempre veem todos os eventos, independente '
                  'do que for marcado aqui.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdicao ? 'Salvar alterações' : 'Salvar evento'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grupoChip(String valor, String label) {
    final selecionado = _categoriasSelecionadas.contains(valor);
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (marcado) {
        setState(() {
          if (marcado) {
            _categoriasSelecionadas.add(valor);
          } else {
            _categoriasSelecionadas.remove(valor);
          }
        });
      },
    );
  }
}
