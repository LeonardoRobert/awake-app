import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/shift_model.dart';
import '../../providers/shift_provider.dart';

class _AreaServico {
  final String id;
  final String nome;
  _AreaServico({required this.id, required this.nome});
}

/// Valor especial usado no Dropdown pra representar "Outros" (nome
/// livre, sem vincular a nenhuma area cadastrada).
const _valorOutros = '__outros__';

/// Tela do lider para criar ou editar uma escala.
/// Se `shiftParaEditar` for informado, a tela entra em modo de edicao.
class ShiftFormScreen extends ConsumerStatefulWidget {
  final ShiftModel? shiftParaEditar;
  const ShiftFormScreen({super.key, this.shiftParaEditar});

  @override
  ConsumerState<ShiftFormScreen> createState() => _ShiftFormScreenState();
}

class _ShiftFormScreenState extends ConsumerState<ShiftFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _vagasController;
  DateTime? _data;
  TimeOfDay? _horarioInicio;
  TimeOfDay? _horarioFim;
  bool _recorrente = true;
  DateTime? _recorrenciaFim;
  bool _saving = false;

  late Future<List<_AreaServico>> _futuroAreas;
  String? _areaSelecionada; // guarda o ID, ou _valorOutros

  bool get _isEdicao => widget.shiftParaEditar != null;

  @override
  void initState() {
    super.initState();
    final shift = widget.shiftParaEditar;
    _nomeController = TextEditingController(text: shift?.nome ?? '');
    _vagasController = TextEditingController(text: (shift?.vagas ?? 1).toString());
    _data = shift?.data;
    _recorrente = shift?.recorrente ?? true;
    _recorrenciaFim = shift?.recorrenciaFim;

    if (shift != null) {
      _horarioInicio = _parseTimeOfDay(shift.horarioInicio);
      _horarioFim = _parseTimeOfDay(shift.horarioFim);
    }

    _futuroAreas = _carregarAreas();
  }

  Future<List<_AreaServico>> _carregarAreas() async {
    final resposta = await Supabase.instance.client
        .from('areas_servico')
        .select('id, nome')
        .order('nome');
    final areas = (resposta as List)
        .map((e) => _AreaServico(id: e['id'] as String, nome: e['nome'] as String))
        .toList();

    // Se ja existe uma area vinculada (edicao), pre-seleciona ela.
    final areaIdAtual = widget.shiftParaEditar?.areaId;
    if (areaIdAtual != null && areas.any((a) => a.id == areaIdAtual)) {
      _areaSelecionada = areaIdAtual;
    } else if (widget.shiftParaEditar != null) {
      // Editando uma escala antiga sem area vinculada -- cai em "Outros".
      _areaSelecionada = _valorOutros;
    }

    return areas;
  }

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final partes = hhmm.split(':');
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  Future<void> _pickData() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _data ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _data = date);
  }

  Future<void> _pickHorarioInicio() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _horarioInicio ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _horarioInicio = time);
  }

  Future<void> _pickHorarioFim() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _horarioFim ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _horarioFim = time);
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

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_data == null || _horarioInicio == null || _horarioFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha data, horário de início e de fim.')),
      );
      return;
    }
    if (_areaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a área de serviço.')),
      );
      return;
    }

    final areaIdParaSalvar = _areaSelecionada == _valorOutros ? null : _areaSelecionada;

    setState(() => _saving = true);
    try {
      final service = ref.read(shiftServiceProvider);
      if (_isEdicao) {
        final atualizado = ShiftModel(
          id: widget.shiftParaEditar!.id,
          nome: _nomeController.text.trim(),
          areaId: areaIdParaSalvar,
          data: _data!,
          horarioInicio: _formatTime(_horarioInicio!),
          horarioFim: _formatTime(_horarioFim!),
          vagas: int.parse(_vagasController.text),
          recorrente: _recorrente,
          recorrenciaFim: _recorrente ? _recorrenciaFim : null,
        );
        await service.updateShiftTemplate(widget.shiftParaEditar!.id, atualizado);
      } else {
        await service.createShiftTemplate(
          nome: _nomeController.text.trim(),
          areaId: areaIdParaSalvar,
          data: _data!,
          horarioInicio: _formatTime(_horarioInicio!),
          horarioFim: _formatTime(_horarioFim!),
          vagas: int.parse(_vagasController.text),
          recorrente: _recorrente,
          recorrenciaFim: _recorrente ? _recorrenciaFim : null,
        );
      }
      ref.invalidate(upcomingShiftOccurrencesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar escala: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdicao ? 'Editar escala' : 'Nova escala')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<List<_AreaServico>>(
                future: _futuroAreas,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final areas = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    value: _areaSelecionada,
                    decoration: const InputDecoration(labelText: 'Área de serviço'),
                    items: [
                      ...areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.nome))),
                      const DropdownMenuItem(value: _valorOutros, child: Text('Outros')),
                    ],
                    onChanged: (v) => setState(() {
                      _areaSelecionada = v;
                      // Se escolheu uma area cadastrada, ja preenche o
                      // nome da escala com o nome dela (a pessoa ainda
                      // pode editar embaixo se quiser deixar mais especifico).
                      if (v != null && v != _valorOutros) {
                        final area = areas.firstWhere((a) => a.id == v);
                        _nomeController.text = area.nome;
                      }
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome da escala',
                  hintText: _areaSelecionada == _valorOutros
                      ? 'Escreve o nome (ex: Ação Social)'
                      : 'Pode deixar mais específico, se quiser',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vagasController,
                decoration: const InputDecoration(labelText: 'Número de vagas'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1) ? 'Informe um número válido' : null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickData,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _recorrente ? 'Primeira data (dia da semana)' : 'Data',
                  ),
                  child: Text(
                    _data == null ? 'Selecionar data' : DateFormat('dd/MM/yyyy').format(_data!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickHorarioInicio,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Chegada'),
                        child: Text(_horarioInicio?.format(context) ?? 'Selecionar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _pickHorarioFim,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Saída'),
                        child: Text(_horarioFim?.format(context) ?? 'Selecionar'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Escalas com o mesmo dia e o mesmo horário de chegada são tratadas '
                  'como o mesmo culto — a pessoa só pode se inscrever em uma delas.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _recorrente,
                onChanged: (v) => setState(() => _recorrente = v),
                title: const Text('Escala recorrente'),
                subtitle: const Text('Repete toda semana, no mesmo dia e horário'),
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
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdicao ? 'Salvar alterações' : 'Salvar escala'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}