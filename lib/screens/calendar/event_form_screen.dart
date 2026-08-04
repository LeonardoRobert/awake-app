import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';

/// Tela de criacao/edicao de evento, disponivel apenas para lider/admin.
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

  bool _paraTodos = true;
  final Set<String> _categoriasSelecionadas = {};
  bool _exclusivoAwake = false;

  // Foto opcional
  Uint8List? _novaFotoBytes;
  String? _novaFotoNome;
  String? _fotoUrlExistente;
  bool _removerFoto = false;

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
    _fotoUrlExistente = evento?.fotoUrl;
    _exclusivoAwake = evento?.exclusivoAwake ?? false;

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

  Future<void> _escolherFoto() async {
    final picker = ImagePicker();
    final arquivo = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (arquivo == null) return;

    final bytes = await arquivo.readAsBytes();
    setState(() {
      _novaFotoBytes = bytes;
      _novaFotoNome = arquivo.name;
      _removerFoto = false;
    });
  }

  void _removerFotoSelecionada() {
    setState(() {
      _novaFotoBytes = null;
      _novaFotoNome = null;
      _removerFoto = true;
    });
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

    try {
      final service = ref.read(eventServiceProvider);
      final eventoId = widget.eventoParaEditar?.id ?? const Uuid().v4();

      String? fotoUrl = _removerFoto ? null : _fotoUrlExistente;
      if (_novaFotoBytes != null && _novaFotoNome != null) {
        fotoUrl = await service.uploadFotoEvento(_novaFotoBytes!, _novaFotoNome!, eventoId);
      }

      final novoEvento = EventModel(
        id: eventoId,
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        dataInicio: _dataInicio!,
        local: _localController.text.trim(),
        recorrente: _recorrente,
        recorrenciaFim: _recorrente ? _recorrenciaFim : null,
        tipo: _tipo,
        publicoAlvo: _paraTodos ? null : _categoriasSelecionadas.toList(),
        fotoUrl: fotoUrl,
        exclusivoAwake: _exclusivoAwake,
      );

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
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventTipo>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de evento',
                  helperText: 'Define a cor no calendário e conta para as metas mensais',
                ),
                items: EventTipo.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: t.cor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(t.label),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v ?? EventTipo.outro),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(labelText: 'Descrição'),
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
              const Text('Esse evento é...', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Eventos exclusivos da Awake às sextas aparecem na tela de Início',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Da igreja')),
                  ButtonSegment(value: true, label: Text('Exclusivo Awake')),
                ],
                selected: {_exclusivoAwake},
                onSelectionChanged: (value) => setState(() => _exclusivoAwake = value.first),
              ),
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
              ],
              const SizedBox(height: 24),
              const Text('Foto do evento (opcional)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildFotoPreview(),
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

  Widget _buildFotoPreview() {
    final temFotoNova = _novaFotoBytes != null;
    final temFotoExistente = _fotoUrlExistente != null && !_removerFoto && !temFotoNova;

    if (!temFotoNova && !temFotoExistente) {
      return OutlinedButton.icon(
        onPressed: _escolherFoto,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Adicionar foto'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: temFotoNova
                ? Image.memory(_novaFotoBytes!, fit: BoxFit.cover)
                : Image.network(_fotoUrlExistente!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _escolherFoto,
                icon: const Icon(Icons.edit),
                label: const Text('Trocar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _removerFotoSelecionada,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover'),
              ),
            ),
          ],
        ),
      ],
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