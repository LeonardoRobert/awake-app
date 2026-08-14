import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/erro_amigavel.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela de criacao/edicao de evento.
///
/// O que a pessoa pode escolher em "esse evento e..." depende de quem
/// ela e: admin ve as 8 categorias; lider de ministerio so ve (e ja
/// vem pre-selecionada) a categoria do proprio ministerio.
class EventFormScreen extends ConsumerStatefulWidget {
  final EventModel? eventoParaEditar;
  final DateTime? dataInicial;
  /// Se preenchido, essa tela nao esta editando a serie inteira de
  /// [eventoParaEditar] -- esta criando um evento avulso novo so pra
  /// essa data (a serie original ganha uma excecao nela). Ver
  /// EdicaoOcorrenciaUnica.
  final DateTime? ocorrenciaUnica;
  const EventFormScreen({
    super.key,
    this.eventoParaEditar,
    this.dataInicial,
    this.ocorrenciaUnica,
  });

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _localController;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _recorrente = false;
  DateTime? _recorrenciaFim;
  final Set<int> _semanasSelecionadas = {};
  EventTipo _tipo = EventTipo.outro;
  EventoEscopo _escopo = EventoEscopo.igreja;
  bool _saving = false;
  bool _escopoInicializado = false;

  bool _paraTodos = true;
  final Set<String> _categoriasSelecionadas = {};
  bool _todosOsGeneros = true;
  final Set<String> _generosSelecionados = {};
  bool _todosOsCasais = true;
  final Set<String> _casaisSelecionados = {};

  Uint8List? _novaFotoBytes;
  String? _novaFotoNome;
  String? _fotoUrlExistente;
  bool _removerFoto = false;

  Uint8List? _novaFotoStoryBytes;
  String? _novaFotoStoryNome;
  String? _fotoStoryUrlExistente;
  bool _removerFotoStory = false;

  // ---- Evento ingressado ----
  bool _ingressado = false;
  bool _visivelSitePublico = false;
  final _valorTotalController = TextEditingController();
  final _parcelasController = TextEditingController();
  final Set<String> _metodosPagamentoSelecionados = {};

  bool get _isEdicao => widget.eventoParaEditar != null;
  bool get _ehOcorrenciaUnica => widget.ocorrenciaUnica != null;

  @override
  void initState() {
    super.initState();
    final evento = widget.eventoParaEditar;
    _tituloController = TextEditingController(text: evento?.titulo ?? '');
    _descricaoController = TextEditingController(text: evento?.descricao ?? '');
    _localController = TextEditingController(text: evento?.local ?? '');
    // Se veio de um dia clicado no calendario (criando evento novo),
    // ja pre-preenche com aquele dia -- a pessoa ainda pode alterar.
    _dataInicio = evento?.dataInicio ?? widget.dataInicial;
    _dataFim = evento?.dataFim;
    _recorrente = evento?.recorrente ?? false;
    _recorrenciaFim = evento?.recorrenciaFim;
    _semanasSelecionadas.addAll(evento?.semanasDoMes ?? const []);
    _tipo = evento?.tipo ?? EventTipo.outro;
    _escopo = evento?.escopo ?? EventoEscopo.igreja;
    _fotoUrlExistente = evento?.fotoUrl;
    _fotoStoryUrlExistente = evento?.fotoStoryUrl;

    final publicoExistente = evento?.publicoAlvo;
    if (publicoExistente != null && publicoExistente.isNotEmpty) {
      _paraTodos = false;
      _categoriasSelecionadas.addAll(publicoExistente);
    }

    final generoExistente = evento?.publicoGenero;
    if (generoExistente != null && generoExistente.isNotEmpty) {
      _todosOsGeneros = false;
      _generosSelecionados.addAll(generoExistente);
    }

    final casaisExistente = evento?.publicoCasais;
    if (casaisExistente != null && casaisExistente.isNotEmpty) {
      _todosOsCasais = false;
      _casaisSelecionados.addAll(casaisExistente);
    }

    _ingressado = evento?.ingressado ?? false;
    _visivelSitePublico = evento?.visivelSitePublico ?? false;
    _valorTotalController.text =
        evento?.valorTotal != null ? evento!.valorTotal!.toStringAsFixed(2) : '';
    _parcelasController.text = evento?.parcelasSugeridas?.toString() ?? '';
    _metodosPagamentoSelecionados.addAll(evento?.metodosPagamento ?? const []);

    // Editando so UMA ocorrencia de uma serie: pre-preenche com os
    // dados do evento original, mas essa vira um evento avulso novo
    // (nao recorrente), travado nessa data especifica.
    if (widget.ocorrenciaUnica != null) {
      _dataInicio = widget.ocorrenciaUnica;
      _recorrente = false;
      _recorrenciaFim = null;
      _semanasSelecionadas.clear();
    }
  }

  /// Escopos que essa pessoa pode escolher, na ordem oficial.
  List<EventoEscopo> _escoposPermitidos(bool isAdmin, List<MinisterioMembership> ministerios) {
    if (isAdmin) return ordemEscopos;

    final ministeriosLiderados =
        ministerios.where((m) => m.ehLider).map((m) => m.ministerio).toSet();

    return ordemEscopos.where((escopo) {
      final ministerio = escopo.ministerioCorrespondente;
      return ministerio != null && ministeriosLiderados.contains(ministerio);
    }).toList();
  }

  void _garantirEscopoValido(List<EventoEscopo> permitidos) {
    if (_escopoInicializado) return;
    if (permitidos.isNotEmpty && !permitidos.contains(_escopo)) {
      _escopo = permitidos.first;
    }
    _escopoInicializado = true;
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

  /// Data de termino do evento (opcional) -- pra eventos que duram
  /// mais de um dia, tipo retiro/conferencia (sexta a domingo).
  Future<void> _pickDataFim() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dataFim ?? _dataInicio ?? DateTime.now(),
      firstDate: _dataInicio ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date == null) return;
    // So a data importa aqui (nao a hora) -- mantem consistente com o
    // fim de dia, entao "vai ate domingo" cobre o domingo inteiro.
    setState(() => _dataFim = DateTime(date.year, date.month, date.day, 23, 59));
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

  Future<void> _escolherFoto({required bool ehStory}) async {
    final picker = ImagePicker();
    final arquivo = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: ehStory ? 1080 : 1600,
      imageQuality: 85,
    );
    if (arquivo == null) return;

    final bytes = await arquivo.readAsBytes();
    setState(() {
      if (ehStory) {
        _novaFotoStoryBytes = bytes;
        _novaFotoStoryNome = arquivo.name;
        _removerFotoStory = false;
      } else {
        _novaFotoBytes = bytes;
        _novaFotoNome = arquivo.name;
        _removerFoto = false;
      }
    });
  }

  void _removerFotoSelecionada({required bool ehStory}) {
    setState(() {
      if (ehStory) {
        _novaFotoStoryBytes = null;
        _novaFotoStoryNome = null;
        _removerFotoStory = true;
      } else {
        _novaFotoBytes = null;
        _novaFotoNome = null;
        _removerFoto = true;
      }
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
    if (_dataFim != null && _dataFim!.isBefore(_dataInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A data de término precisa ser depois da data de início.')),
      );
      return;
    }

    final usaSubgrupos = _escopo == EventoEscopo.awake;
    final usaGenero = _escopo == EventoEscopo.awake || _escopo == EventoEscopo.coral;
    if (usaSubgrupos && !_paraTodos && _categoriasSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um grupo, ou marque "Para todos".')),
      );
      return;
    }
    if (usaGenero && !_todosOsGeneros && _generosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione meninos e/ou meninas, ou marque "Meninos e meninas".')),
      );
      return;
    }
    final usaCasais = _escopo == EventoEscopo.casais;
    if (usaCasais && !_todosOsCasais && _casaisSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione pelo menos um grupo, ou marque "Todos os casais".')),
      );
      return;
    }

    double? valorTotal;
    if (_ingressado) {
      valorTotal = double.tryParse(_valorTotalController.text.replaceAll(',', '.'));
      if (valorTotal == null || valorTotal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o valor total do evento ingressado.')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final service = ref.read(eventServiceProvider);
      // Editando so uma ocorrencia: NAO reaproveita o id do evento
      // original -- isso vira um evento avulso novo e independente,
      // com id proprio (a serie original so ganha uma excecao nessa
      // data, ela continua existindo do jeito que estava).
      final eventoId = _ehOcorrenciaUnica
          ? const Uuid().v4()
          : (widget.eventoParaEditar?.id ?? const Uuid().v4());

      String? fotoUrl = _removerFoto ? null : _fotoUrlExistente;
      if (_novaFotoBytes != null && _novaFotoNome != null) {
        fotoUrl = await service.uploadFotoEvento(_novaFotoBytes!, _novaFotoNome!, eventoId);
      }

      String? fotoStoryUrl = _removerFotoStory ? null : _fotoStoryUrlExistente;
      if (_novaFotoStoryBytes != null && _novaFotoStoryNome != null) {
        fotoStoryUrl = await service.uploadFotoEvento(
          _novaFotoStoryBytes!,
          _novaFotoStoryNome!,
          eventoId,
          sufixo: 'story',
        );
      }

      final novoEvento = EventModel(
        id: eventoId,
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        dataInicio: _dataInicio!,
        dataFim: _dataFim,
        local: _localController.text.trim(),
        recorrente: _recorrente,
        recorrenciaFim: _recorrente ? _recorrenciaFim : null,
        semanasDoMes: _recorrente && _semanasSelecionadas.isNotEmpty
            ? (_semanasSelecionadas.toList()..sort())
            : null,
        tipo: _tipo,
        escopo: _escopo,
        // O sub-filtro de Genesis/Next/One so faz sentido dentro do
        // Awake -- pros demais escopos, a visibilidade ja e cuidada
        // inteiramente pelo escopo em si.
        publicoAlvo: usaSubgrupos && !_paraTodos ? _categoriasSelecionadas.toList() : null,
        publicoGenero:
            usaGenero && !_todosOsGeneros ? _generosSelecionados.toList() : null,
        publicoCasais: usaCasais && !_todosOsCasais ? _casaisSelecionados.toList() : null,
        fotoUrl: fotoUrl,
        fotoStoryUrl: fotoStoryUrl,
        ingressado: _ingressado,
        valorTotal: _ingressado ? valorTotal : null,
        parcelasSugeridas: _ingressado ? int.tryParse(_parcelasController.text) : null,
        metodosPagamento: _ingressado && _metodosPagamentoSelecionados.isNotEmpty
            ? _metodosPagamentoSelecionados.toList()
            : null,
        visivelSitePublico: _visivelSitePublico,
      );

      if (_ehOcorrenciaUnica) {
        // Marca a data original como excecao na serie (ela para de
        // gerar essa ocorrencia) e cria o evento avulso novo, editado,
        // so pra esse dia.
        await service.deleteOccurrence(widget.eventoParaEditar!.id, widget.ocorrenciaUnica!);
        await service.create(novoEvento);
      } else if (_isEdicao) {
        await service.update(widget.eventoParaEditar!.id, novoEvento);
      } else {
        await service.create(novoEvento);
      }
      ref.invalidate(upcomingEventsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar evento: ${mensagemDeErroAmigavel(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;
    final isAdmin = profile?.isAdmin ?? false;
    final permitidos = _escoposPermitidos(isAdmin, profile?.ministerios ?? const []);
    _garantirEscopoValido(permitidos);

    final tiposDisponiveis = switch (_escopo) {
      EventoEscopo.igreja => tiposDoEscopoIgreja,
      EventoEscopo.awake => tiposDoEscopoAwake,
      _ => const <EventTipo>[],
    };

    return Scaffold(
      appBar: AwakeAppBar(
        title: _ehOcorrenciaUnica
            ? 'Editar esta data'
            : (_isEdicao ? 'Editar evento' : 'Novo evento'),
        showQrButton: false,
      ),
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
              const Text('Esse evento é...', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (permitidos.isEmpty)
                const Text(
                  'Você não tem permissão pra criar eventos em nenhuma categoria.',
                  style: TextStyle(color: Colors.red),
                )
              else if (permitidos.length == 1)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: permitidos.first.corReferencia.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: permitidos.first.corReferencia, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(permitidos.first.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<EventoEscopo>(
                  value: _escopo,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: permitidos
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration:
                                      BoxDecoration(color: e.corReferencia, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(e.label),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _escopo = v ?? _escopo;
                    _tipo = EventTipo.outro;
                  }),
                ),
              if (tiposDisponiveis.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<EventTipo>(
                  value: tiposDisponiveis.contains(_tipo) ? _tipo : tiposDisponiveis.first,
                  decoration: const InputDecoration(labelText: 'Tipo de evento'),
                  items: tiposDisponiveis
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _tipo = v ?? EventTipo.outro),
                ),
              ],
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
              InkWell(
                onTap: _pickDataFim,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data de término (opcional)',
                    helperText: 'Pra eventos que duram mais de um dia, tipo retiro (sexta a domingo)',
                    suffixIcon: _dataFim == null
                        ? null
                        : IconButton(
                            tooltip: 'Remover data de término',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _dataFim = null),
                          ),
                  ),
                  child: Text(
                    _dataFim == null ? 'Sem data de término' : DateFormat('dd/MM/yyyy').format(_dataFim!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_ehOcorrenciaUnica) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Editando só esta data. As outras ocorrências da série continuam '
                    'do jeito que estavam.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ] else ...[
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
              ],
              if (_recorrente && !_ehOcorrenciaUnica) ...[
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
                const SizedBox(height: 16),
                const Text('Repetir em quais semanas do mês?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  _semanasSelecionadas.isEmpty
                      ? 'Toda semana (padrão)'
                      : 'Só nas semanas marcadas — ex: 1ª e 3ª = quinzenal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3, 4, 5].map((numero) {
                    final selecionada = _semanasSelecionadas.contains(numero);
                    return FilterChip(
                      label: Text('${numero}ª semana'),
                      selected: selecionada,
                      onSelected: (marcado) {
                        setState(() {
                          if (marcado) {
                            _semanasSelecionadas.add(numero);
                          } else {
                            _semanasSelecionadas.remove(numero);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (_escopo == EventoEscopo.awake) ...[
                const SizedBox(height: 24),
                const Text('Quem dentro do Awake pode ver esse evento?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Todos do Awake')),
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
              ],
              if (_escopo == EventoEscopo.awake || _escopo == EventoEscopo.coral) ...[
                const SizedBox(height: 20),
                Text(
                  _escopo == EventoEscopo.coral
                      ? 'Masculino, feminino, ou os dois?'
                      : 'Meninos, meninas, ou os dois?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _escopo == EventoEscopo.coral
                      ? 'Usa o "Sexo" que a pessoa já preencheu no cadastro'
                      : 'Funciona junto com o filtro de grupo acima — ex: '
                          '"Genesis" + "Meninas" mostra só pras garotas do Genesis',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Todos')),
                    ButtonSegment(value: false, label: Text('Só um dos dois')),
                  ],
                  selected: {_todosOsGeneros},
                  onSelectionChanged: (value) => setState(() => _todosOsGeneros = value.first),
                ),
                if (!_todosOsGeneros) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _generoChip('masculino', _escopo == EventoEscopo.coral ? 'Masculino' : 'Meninos'),
                      _generoChip('feminino', _escopo == EventoEscopo.coral ? 'Feminino' : 'Meninas'),
                    ],
                  ),
                ],
              ],
              if (_escopo == EventoEscopo.casais) ...[
                const SizedBox(height: 24),
                const Text('Quem pode ver esse evento?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Todos os casais')),
                    ButtonSegment(value: false, label: Text('Grupo específico')),
                  ],
                  selected: {_todosOsCasais},
                  onSelectionChanged: (value) => setState(() => _todosOsCasais = value.first),
                ),
                if (!_todosOsCasais) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _casalChip('one', 'One (Awake)'),
                      _casalChip('henrique_patricia', 'Henrique e Patrícia'),
                      _casalChip('ivaldo_sonja', 'Ivaldo e Sonja'),
                      _casalChip('marcelo_andreia', 'Marcelo e Andréia'),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _visivelSitePublico,
                onChanged: (v) => setState(() => _visivelSitePublico = v),
                title: const Text('Mostrar no site público'),
                subtitle: const Text('Aparece na agenda de leonardorobert.github.io/awake-app, sem precisar de login'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _ingressado,
                onChanged: (v) => setState(() => _ingressado = v),
                title: const Text('Evento ingressado'),
                subtitle: const Text('Tem valor de inscrição (ex: retiro, conferência)'),
              ),
              if (_ingressado) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valorTotalController,
                  decoration: const InputDecoration(
                    labelText: 'Valor total',
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _parcelasController,
                  decoration: const InputDecoration(
                    labelText: 'Parcelas sugeridas (opcional)',
                    helperText: 'Ex: 3 — vira só uma sugestão pra pessoa se organizar',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const Text('Métodos de pagamento aceitos',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _metodoChip('pix', 'Pix'),
                    _metodoChip('cartao', 'Cartão'),
                    _metodoChip('dinheiro', 'Dinheiro'),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'A partir de agora, os pagamentos dessa pessoa pra esse evento são '
                    'lançados no Painel Financeiro (igual dízimo/oferta), vinculando ao '
                    'evento. A barra de progresso na tela de Início atualiza sozinha.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 24),
                const Text('Foto do evento (opcional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Aparece na tela de Início e nos detalhes do evento',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _buildFotoPreview(
                  ehStory: false,
                  aspectRatio: 16 / 9,
                  novaFotoBytes: _novaFotoBytes,
                  fotoUrlExistente: _fotoUrlExistente,
                  removida: _removerFoto,
                ),
                const SizedBox(height: 24),
                const Text('Foto formato Story (opcional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Vertical (tipo Stories) — usada no botão "Adicionar ao Instagram"',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _buildFotoPreview(
                  ehStory: true,
                  aspectRatio: 9 / 16,
                  novaFotoBytes: _novaFotoStoryBytes,
                  fotoUrlExistente: _fotoStoryUrlExistente,
                  removida: _removerFotoStory,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_saving || permitidos.isEmpty) ? null : _submit,
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

  Widget _buildFotoPreview({
    required bool ehStory,
    required double aspectRatio,
    required Uint8List? novaFotoBytes,
    required String? fotoUrlExistente,
    required bool removida,
  }) {
    final temFotoNova = novaFotoBytes != null;
    final temFotoExistente = fotoUrlExistente != null && !removida && !temFotoNova;

    if (!temFotoNova && !temFotoExistente) {
      return OutlinedButton.icon(
        onPressed: () => _escolherFoto(ehStory: ehStory),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Adicionar foto'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ehStory ? 200 : double.infinity),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: temFotoNova
                    ? Image.memory(novaFotoBytes, fit: BoxFit.cover)
                    : Image.network(fotoUrlExistente!, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _escolherFoto(ehStory: ehStory),
                icon: const Icon(Icons.edit),
                label: const Text('Trocar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _removerFotoSelecionada(ehStory: ehStory),
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

  Widget _generoChip(String valor, String label) {
    final selecionado = _generosSelecionados.contains(valor);
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (marcado) {
        setState(() {
          if (marcado) {
            _generosSelecionados.add(valor);
          } else {
            _generosSelecionados.remove(valor);
          }
        });
      },
    );
  }

  Widget _casalChip(String valor, String label) {
    final selecionado = _casaisSelecionados.contains(valor);
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (marcado) {
        setState(() {
          if (marcado) {
            _casaisSelecionados.add(valor);
          } else {
            _casaisSelecionados.remove(valor);
          }
        });
      },
    );
  }

  Widget _metodoChip(String valor, String label) {
    final selecionado = _metodosPagamentoSelecionados.contains(valor);
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (marcado) {
        setState(() {
          if (marcado) {
            _metodosPagamentoSelecionados.add(valor);
          } else {
            _metodosPagamentoSelecionados.remove(valor);
          }
        });
      },
    );
  }
}

/// Cor de referencia pra mostrar no seletor de categoria (sem depender
/// do tipo, ja que aqui a pessoa ainda esta escolhendo o escopo).
extension _CorReferenciaEscopo on EventoEscopo {
  Color get corReferencia => corDoEvento(EventTipo.outro, this);
}
