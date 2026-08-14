import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/erro_amigavel.dart';
import '../../models/event_model.dart';
import '../../models/outdoor_model.dart';
import '../../providers/outdoor_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela de criacao/edicao de outdoor -- so Admin acessa (a checagem de
/// quem pode entrar aqui fica no botao que abre essa tela, igual RLS
/// garante que so admin consegue de fato salvar).
class OutdoorFormScreen extends ConsumerStatefulWidget {
  final OutdoorModel? outdoorParaEditar;
  const OutdoorFormScreen({super.key, this.outdoorParaEditar});

  @override
  ConsumerState<OutdoorFormScreen> createState() => _OutdoorFormScreenState();
}

class _OutdoorFormScreenState extends ConsumerState<OutdoorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();

  OutdoorTipo _tipo = OutdoorTipo.recorrente;
  int? _semanaDoMes;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _ativo = true;
  bool _todosOsPublicos = true;
  final Set<EventoEscopo> _escoposSelecionados = {};

  Uint8List? _novaImagemBytes;
  String? _novaImagemNome;
  String? _imagemUrlExistente;

  bool _saving = false;

  bool get _isEdicao => widget.outdoorParaEditar != null;

  @override
  void initState() {
    super.initState();
    final outdoor = widget.outdoorParaEditar;
    if (outdoor != null) {
      _linkController.text = outdoor.linkUrl ?? '';
      _tipo = outdoor.tipo;
      _semanaDoMes = outdoor.semanaDoMes;
      _dataInicio = outdoor.dataInicio;
      _dataFim = outdoor.dataFim;
      _ativo = outdoor.ativo;
      _imagemUrlExistente = outdoor.imagemUrl;
      if (outdoor.escopos != null && outdoor.escopos!.isNotEmpty) {
        _todosOsPublicos = false;
        _escoposSelecionados.addAll(
          outdoor.escopos!.map(eventoEscopoFromString),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _escolherImagem() async {
    final picker = ImagePicker();
    final arquivo = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (arquivo == null) return;

    final bytes = await arquivo.readAsBytes();
    setState(() {
      _novaImagemBytes = bytes;
      _novaImagemNome = arquivo.name;
    });
  }

  Future<void> _escolherData({required bool ehInicio}) async {
    final atual = ehInicio ? _dataInicio : _dataFim;
    final data = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (data == null) return;
    setState(() {
      if (ehInicio) {
        _dataInicio = data;
      } else {
        _dataFim = data;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_novaImagemBytes == null && _imagemUrlExistente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha uma imagem pro outdoor.')),
      );
      return;
    }
    if (_tipo == OutdoorTipo.recorrente && _semanaDoMes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione qual domingo do mês.')),
      );
      return;
    }
    if (_tipo == OutdoorTipo.temporario && (_dataInicio == null || _dataFim == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data de início e de fim.')),
      );
      return;
    }
    if (_tipo == OutdoorTipo.temporario &&
        _dataInicio != null &&
        _dataFim != null &&
        _dataFim!.isBefore(_dataInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A data de fim precisa ser depois da data de início.')),
      );
      return;
    }
    if (!_todosOsPublicos && _escoposSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um público, ou marque "Todo mundo vê".')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final service = ref.read(outdoorServiceProvider);
      final outdoorId = widget.outdoorParaEditar?.id ?? const Uuid().v4();

      var imagemUrl = _imagemUrlExistente;
      if (_novaImagemBytes != null && _novaImagemNome != null) {
        imagemUrl = await service.uploadImagem(_novaImagemBytes!, _novaImagemNome!);
      }

      final novoOutdoor = OutdoorModel(
        id: outdoorId,
        imagemUrl: imagemUrl!,
        linkUrl: _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
        tipo: _tipo,
        semanaDoMes: _tipo == OutdoorTipo.recorrente ? _semanaDoMes : null,
        dataInicio: _tipo == OutdoorTipo.temporario ? _dataInicio : null,
        dataFim: _tipo == OutdoorTipo.temporario ? _dataFim : null,
        ativo: _ativo,
        escopos: !_todosOsPublicos
            ? _escoposSelecionados.map((e) => e.valorBanco).toList()
            : null,
      );

      if (_isEdicao) {
        await service.atualizar(widget.outdoorParaEditar!.id, novoOutdoor);
      } else {
        await service.criar(novoOutdoor);
      }

      ref.invalidate(outdoorsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar o outdoor: ${mensagemDeErroAmigavel(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _semanasLabel = {
    1: '1º domingo',
    2: '2º domingo',
    3: '3º domingo',
    4: '4º domingo',
    5: '5º domingo',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AwakeAppBar(title: _isEdicao ? 'Editar outdoor' : 'Criar outdoor', showQrButton: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Imagem (formato deitado, ideal 2:1 — ex.: 1600×800px)',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _escolherImagem,
              child: AspectRatio(
                aspectRatio: 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: _novaImagemBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_novaImagemBytes!, fit: BoxFit.cover),
                        )
                      : _imagemUrlExistente != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(_imagemUrlExistente!, fit: BoxFit.cover),
                            )
                          : const Center(
                              child: Icon(Icons.add_photo_alternate_outlined, size: 40),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Link (opcional)',
                hintText: 'ex.: https://wa.me/55...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            Text('Como esse outdoor aparece?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<OutdoorTipo>(
              segments: const [
                ButtonSegment(value: OutdoorTipo.sempre, label: Text('Sempre')),
                ButtonSegment(value: OutdoorTipo.recorrente, label: Text('Recorrente')),
                ButtonSegment(value: OutdoorTipo.temporario, label: Text('Temporário')),
              ],
              selected: {_tipo},
              onSelectionChanged: (v) => setState(() => _tipo = v.first),
            ),
            const SizedBox(height: 12),
            if (_tipo == OutdoorTipo.sempre) ...[
              Text(
                'Fica visível o tempo todo, sem data pra sumir — só o toggle "Ativo" liga/desliga.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (_tipo == OutdoorTipo.recorrente) ...[
              Text(
                'Aparece sempre 5 dias antes desse domingo, até o fim dele — todo mês.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _semanasLabel.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _semanaDoMes == e.key,
                          onSelected: (_) => setState(() => _semanaDoMes = e.key),
                        ))
                    .toList(),
              ),
            ] else ...[
              Text(
                'Fica visível continuamente entre as duas datas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _escolherData(ehInicio: true),
                      child: Text(_dataInicio == null
                          ? 'Data início'
                          : DateFormat('dd/MM/yyyy').format(_dataInicio!)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _escolherData(ehInicio: false),
                      child: Text(_dataFim == null
                          ? 'Data fim'
                          : DateFormat('dd/MM/yyyy').format(_dataFim!)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Quem pode ver esse outdoor?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _todosOsPublicos,
              onChanged: (v) => setState(() => _todosOsPublicos = v),
              title: const Text('Todo mundo vê'),
            ),
            if (!_todosOsPublicos) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: ordemEscopos
                    .map((escopo) => FilterChip(
                          label: Text(escopo.label),
                          selected: _escoposSelecionados.contains(escopo),
                          onSelected: (marcado) {
                            setState(() {
                              if (marcado) {
                                _escoposSelecionados.add(escopo);
                              } else {
                                _escoposSelecionados.remove(escopo);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _ativo,
              onChanged: (v) => setState(() => _ativo = v),
              title: const Text('Ativo'),
              subtitle: const Text('Desligue pra pausar sem apagar'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
