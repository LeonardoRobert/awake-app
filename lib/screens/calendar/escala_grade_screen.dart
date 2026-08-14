import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/erro_amigavel.dart';
import '../../models/escala_servico_model.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';

const _linkBase = 'https://leonardorobert.github.io/awake-app/app/';

/// Uma linha da grade: uma ocorrencia de culto (data + evento), com o
/// estado atual de cada funcao do catalogo pra esse dia. `escalaId` fica
/// null ate a primeira edicao dessa linha -- so espiar o mes nao pode
/// criar registro nenhum no banco (ver EscalaServicoService.
/// listarPosicoesSeExistir).
class _LinhaGrade {
  final DateTime data;
  final EventModel evento;
  String? escalaId;
  final Map<String, PosicaoEscala?> porFuncao;

  _LinhaGrade({required this.data, required this.evento, required this.porFuncao});
}

/// Tela de "Escala Mensal", agora como grade editavel (Fase 2 do plano):
/// abas por mes dentro de um ano, cada celula ja e um autocomplete
/// ligado aos membros do ministerio -- sem Excel, sem import/export.
class EscalaGradeScreen extends ConsumerStatefulWidget {
  final String ministerio;
  final int? anoInicial;
  final int? mesInicial;

  const EscalaGradeScreen({
    super.key,
    required this.ministerio,
    this.anoInicial,
    this.mesInicial,
  });

  @override
  ConsumerState<EscalaGradeScreen> createState() => _EscalaGradeScreenState();
}

class _EscalaGradeScreenState extends ConsumerState<EscalaGradeScreen>
    with SingleTickerProviderStateMixin {
  final _service = EscalaServicoService();
  late int _ano = widget.anoInicial ?? DateTime.now().year;
  late final TabController _tabController;

  List<FuncaoCatalogo>? _colunas;
  final _linhasPorMes = <String, List<_LinhaGrade>>{};
  final _carregandoMes = <String, bool>{};
  final _erroPorMes = <String, String>{};

  bool get _ehDiaconos => widget.ministerio == 'diaconos';

  @override
  void initState() {
    super.initState();
    final mesInicial = (widget.mesInicial ?? DateTime.now().month).clamp(1, 12);
    _tabController = TabController(length: 12, vsync: this, initialIndex: mesInicial - 1);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        _carregarMesSeNecessario(_tabController.index + 1);
      }
    });
    _carregarColunas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarColunas() async {
    final colunas = await _service.listarCatalogo(widget.ministerio);
    if (!mounted) return;
    setState(() => _colunas = colunas);
    _carregarMesSeNecessario(_tabController.index + 1);
  }

  String _chave(int mes) => '$_ano-$mes';

  Future<void> _carregarMesSeNecessario(int mes) async {
    if (_colunas == null) return;
    final chave = _chave(mes);
    if (_linhasPorMes.containsKey(chave) || _carregandoMes[chave] == true) return;
    setState(() {
      _carregandoMes[chave] = true;
      _erroPorMes.remove(chave);
    });

    try {
      final eventos = await ref.read(upcomingEventsProvider.future);
      final eventosIgreja = eventos.where((e) => e.escopo == EventoEscopo.igreja).toList();

      final inicio = DateTime(_ano, mes, 1);
      final fim = DateTime(_ano, mes + 1, 0);
      final ocorrencias = <(DateTime, EventModel)>[];
      for (final evento in eventosIgreja) {
        for (final occ in evento.occurrencesBetween(inicio, fim)) {
          ocorrencias.add((occ, evento));
        }
      }
      ocorrencias.sort((a, b) => a.$1.compareTo(b.$1));

      final linhas = await Future.wait(ocorrencias.map((oc) async {
        final (data, evento) = oc;
        final posicoes = await _service.listarPosicoesSeExistir(
          ministerio: widget.ministerio,
          eventoId: evento.id,
          dataOcorrencia: data,
        );
        final porFuncao = <String, PosicaoEscala?>{for (final c in _colunas!) c.funcao: null};
        for (final p in posicoes) {
          porFuncao[p.funcao] = p;
        }
        return _LinhaGrade(data: data, evento: evento, porFuncao: porFuncao);
      }));

      if (!mounted) return;
      setState(() => _linhasPorMes[chave] = linhas);
    } catch (e) {
      // Sem isso, qualquer falha aqui deixava a aba desse mes presa em
      // "carregando" pra sempre, sem nenhum aviso.
      if (mounted) setState(() => _erroPorMes[chave] = mensagemDeErroAmigavel(e));
    } finally {
      if (mounted) setState(() => _carregandoMes[chave] = false);
    }
  }

  void _trocarAno(int delta) {
    setState(() {
      _ano += delta;
      // Simplifica: troca de ano recarrega tudo do zero (nao mantem
      // cache entre anos, evita crescer memoria indefinidamente).
      _linhasPorMes.clear();
      _carregandoMes.clear();
    });
    _carregarMesSeNecessario(_tabController.index + 1);
  }

  /// Ponto de entrada chamado pela UI: grava a celula e, so pros
  /// Diaconos, cuida do autopreenchimento/memoria de casal (Fase 4).
  /// Apagar uma celula (pessoa == null) nunca dispara efeito de casal
  /// nenhum -- so a gravacao crua.
  Future<void> _definirPessoaNaCelula({
    required _LinhaGrade linha,
    required String funcao,
    required PessoaBusca? pessoa,
    required int slot,
  }) async {
    try {
      await _gravarCelula(linha: linha, funcao: funcao, pessoa: pessoa, slot: slot);

      if (!_ehDiaconos || pessoa == null) return;

      // Pode ficar null se a funcao nao existir mais no catalogo (ver
      // _gravarCelula) -- nesse caso so nao tem o que fazer aqui, sem
      // travar com erro de null.
      final posicaoAtual = linha.porFuncao[funcao];
      if (posicaoAtual == null) return;
      final slotIrmaoVazio =
          slot == 1 ? posicaoAtual.profileId2 == null : posicaoAtual.profileId == null;

      if (slotIrmaoVazio) {
        final par = await _service.buscarParDoCasal(
          ministerio: widget.ministerio,
          profileId: pessoa.id,
        );
        if (par != null) {
          await _gravarCelula(
            linha: linha,
            funcao: funcao,
            pessoa: par,
            slot: slot == 1 ? 2 : 1,
          );
        }
      }

      // Se os dois slots dessa celula ficaram preenchidos (por autofill
      // ou escolha manual), lembra/atualiza o par -- upsert idempotente,
      // seguro de chamar toda vez que a celula "fecha" com os dois nomes.
      final posicaoFinal = linha.porFuncao[funcao];
      if (posicaoFinal != null && posicaoFinal.profileId != null && posicaoFinal.profileId2 != null) {
        await _service.salvarPar(
          ministerio: widget.ministerio,
          profileIdA: posicaoFinal.profileId!,
          profileIdB: posicaoFinal.profileId2!,
        );
      }
    } catch (e) {
      // Sem isso, uma falha aqui (ex: RLS, rede) deixava a celula
      // silenciosamente sem salvar, sem nenhum aviso -- forcamos um
      // reload da linha pra refletir o estado real do banco, e avisamos.
      // Inclui o id de quem esta logado no proprio erro -- serve pra
      // diagnosticar problema de sessao sem precisar abrir o DevTools.
      final meuId = Supabase.instance.client.auth.currentUser?.id ?? '(ninguém logado)';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar (logado como $meuId): $e')),
        );
      }
      rethrow;
    }
  }

  /// Grava a escolha de uma celula, sem nenhum efeito de casal. So cria
  /// a escala/posicoes no banco na primeira edicao daquela linha
  /// (buscarOuCriarEscala) -- espiar o mes sem editar nunca escreve nada.
  Future<void> _gravarCelula({
    required _LinhaGrade linha,
    required String funcao,
    required PessoaBusca? pessoa,
    required int slot,
  }) async {
    linha.escalaId ??= await _service.buscarOuCriarEscala(
      ministerio: widget.ministerio,
      eventoId: linha.evento.id,
      dataOcorrencia: linha.data,
    );

    var posicao = linha.porFuncao[funcao];
    if (posicao == null) {
      // Ou o catalogo mudou depois da escala existir, ou (caso comum)
      // essa e a 1a edicao dessa linha -- buscarOuCriarEscala acabou de
      // semear as posicoes, entao relista tudo de uma vez e atualiza o
      // cache local inteiro (evita reconsultar de novo pras outras
      // colunas dessa mesma linha).
      final posicoes = await _service.listarPosicoes(linha.escalaId!);
      for (final p in posicoes) {
        linha.porFuncao[p.funcao] = p;
      }
      posicao = linha.porFuncao[funcao];
      if (posicao == null) return; // funcao nao existe mais no catalogo
    }

    final novoId = pessoa?.id;
    if (slot == 1) {
      await _service.definirPessoa(posicao.id, novoId);
    } else {
      await _service.definirSegundaPessoa(posicao.id, novoId);
    }

    linha.porFuncao[funcao] = PosicaoEscala(
      id: posicao.id,
      escalaId: posicao.escalaId,
      funcao: posicao.funcao,
      ordem: posicao.ordem,
      profileId: slot == 1 ? novoId : posicao.profileId,
      nomePessoa: slot == 1 ? pessoa?.nome : posicao.nomePessoa,
      profileId2: slot == 2 ? novoId : posicao.profileId2,
      nomePessoa2: slot == 2 ? pessoa?.nome : posicao.nomePessoa2,
    );
    if (mounted) setState(() {});
  }

  /// Monta o texto da aba de mes atualmente aberta, pronto pra colar
  /// num grupo do WhatsApp (*asterisco* vira negrito la sozinho).
  void _copiarParaWhatsApp(BuildContext context) {
    final mes = _tabController.index + 1;
    final linhas = _linhasPorMes[_chave(mes)];
    if (linhas == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera a aba desse mês carregar antes de copiar.')),
      );
      return;
    }
    if (linhas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum culto nesse mês pra copiar.')),
      );
      return;
    }

    final buffer = StringBuffer(
      '*Escala de ${widget.ministerio.labelMinisterio} — ${_nomeMes(mes)}/$_ano*',
    );
    for (final linha in linhas) {
      buffer.writeln();
      buffer.writeln();
      buffer.writeln(
        '*${DateFormat("EEEE, dd/MM", 'pt_BR').format(linha.data)}* — ${linha.evento.titulo}',
      );
      for (final coluna in _colunas!) {
        final posicao = linha.porFuncao[coluna.funcao];
        final quem = _ehDiaconos
            ? _formatarCasal(posicao?.nomePessoa, posicao?.nomePessoa2)
            : (posicao?.nomePessoa ?? '—');
        buffer.writeln('${coluna.funcao}: $quem');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escala copiada! Já pode colar no grupo do WhatsApp.')),
    );
  }

  String _formatarCasal(String? nome1, String? nome2) {
    if (nome1 == null && nome2 == null) return '—';
    if (nome1 != null && nome2 != null) return '$nome1 e $nome2';
    return nome1 ?? nome2!;
  }

  void _copiarLink(BuildContext context) {
    final mes = _tabController.index + 1;
    final link = '$_linkBase#/escala-grade/${widget.ministerio}?ano=$_ano&mes=$mes';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado!')),
    );
  }

  String _nomeMes(int mes) {
    final nome = DateFormat('MMM', 'pt_BR').format(DateTime(2000, mes, 1));
    return nome[0].toUpperCase() + nome.substring(1);
  }

  Widget _celula(_LinhaGrade linha, FuncaoCatalogo coluna) {
    final posicao = linha.porFuncao[coluna.funcao];
    Future<List<PessoaBusca>> buscar(String texto) =>
        _service.buscarPessoasDoMinisterio(widget.ministerio, texto);

    if (_ehDiaconos) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CelulaAutocomplete(
            // Chave ligada ao valor atual: forca remontar (e reaplicar
            // initialValue) quando o autofill de casal preenche essa
            // celula por fora de uma interacao direta com ela.
            key: ValueKey('${linha.data}-${coluna.funcao}-1-${posicao?.profileId}'),
            valorAtual: posicao?.nomePessoa,
            temPessoa: posicao?.profileId != null,
            buscar: buscar,
            onSelecionado: (pessoa) => _definirPessoaNaCelula(
              linha: linha,
              funcao: coluna.funcao,
              pessoa: pessoa,
              slot: 1,
            ),
          ),
          const SizedBox(height: 4),
          _CelulaAutocomplete(
            key: ValueKey('${linha.data}-${coluna.funcao}-2-${posicao?.profileId2}'),
            valorAtual: posicao?.nomePessoa2,
            temPessoa: posicao?.profileId2 != null,
            buscar: buscar,
            onSelecionado: (pessoa) => _definirPessoaNaCelula(
              linha: linha,
              funcao: coluna.funcao,
              pessoa: pessoa,
              slot: 2,
            ),
          ),
        ],
      );
    }

    return _CelulaAutocomplete(
      key: ValueKey('${linha.data}-${coluna.funcao}-1-${posicao?.profileId}'),
      valorAtual: posicao?.nomePessoa,
      temPessoa: posicao?.profileId != null,
      buscar: buscar,
      onSelecionado: (pessoa) => _definirPessoaNaCelula(
        linha: linha,
        funcao: coluna.funcao,
        pessoa: pessoa,
        slot: 1,
      ),
    );
  }

  Widget _corpoDoMes(int mes) {
    final chave = _chave(mes);
    final erro = _erroPorMes[chave];
    if (erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erro ao carregar esse mês: $erro', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _carregarMesSeNecessario(mes),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    final linhas = _linhasPorMes[chave];
    if (linhas == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (linhas.isEmpty) {
      return const Center(child: Text('Nenhum culto geral nesse mês.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          dataRowMinHeight: _ehDiaconos ? 96 : 56,
          dataRowMaxHeight: _ehDiaconos ? 120 : 56,
          columns: [
            const DataColumn(label: Text('Culto')),
            for (final c in _colunas!) DataColumn(label: Text(c.funcao)),
          ],
          rows: [
            for (final linha in linhas)
              DataRow(cells: [
                DataCell(SizedBox(
                  width: 130,
                  child: Text(
                    "${DateFormat("dd/MM (EEE)", 'pt_BR').format(linha.data)}\n${linha.evento.titulo}",
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
                for (final c in _colunas!) DataCell(_celula(linha, c)),
              ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;

    if (profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final podeEditar = profile != null &&
        (profile.isAdmin ||
            profile.ministerios.any((m) => m.ehLider && m.ministerio == widget.ministerio));

    if (!podeEditar) {
      return Scaffold(
        appBar: AwakeAppBar(
          title: 'Escala mensal — ${widget.ministerio.labelMinisterio}',
          showQrButton: false,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Essa página é restrita à liderança desse ministério.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Escala mensal — ${widget.ministerio.labelMinisterio}',
        showQrButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copiar pro WhatsApp',
            onPressed: () => _copiarParaWhatsApp(context),
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Copiar link',
            onPressed: () => _copiarLink(context),
          ),
        ],
      ),
      body: _colunas == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Ano anterior',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _trocarAno(-1),
                      ),
                      Text('$_ano', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        tooltip: 'Próximo ano',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _trocarAno(1),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: List.generate(12, (i) => Tab(text: _nomeMes(i + 1))),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) => _corpoDoMes(_tabController.index + 1),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Celula editavel da grade: autocomplete ligado a busca de membros do
/// ministerio, so permite selecionar quem existe de verdade (resolve a
/// melhoria de "sem digitar nome errado" por construcao).
class _CelulaAutocomplete extends StatelessWidget {
  final String? valorAtual;
  final bool temPessoa;
  final Future<List<PessoaBusca>> Function(String texto) buscar;
  final ValueChanged<PessoaBusca?> onSelecionado;

  const _CelulaAutocomplete({
    super.key,
    required this.valorAtual,
    required this.temPessoa,
    required this.buscar,
    required this.onSelecionado,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Autocomplete<PessoaBusca>(
        initialValue: TextEditingValue(text: valorAtual ?? ''),
        displayStringForOption: (p) => p.nome,
        optionsBuilder: (texto) => buscar(texto.text),
        onSelected: onSelecionado,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: const OutlineInputBorder(),
              hintText: '—',
              suffixIcon: temPessoa
                  ? IconButton(
                      tooltip: 'Limpar seleção',
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () {
                        controller.clear();
                        onSelecionado(null);
                      },
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
