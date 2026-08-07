import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../providers/event_provider.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Nomes das colunas de funcao por ministerio -- pra ministerios com
/// posicao fixa (Louvor, Multimidia), os nomes aqui precisam bater
/// EXATAMENTE com o catalogo cadastrado no banco (escala_servico_
/// funcoes_catalogo), senao o import nao vai casar certo.
List<String> _colunasFuncoes(String ministerio) {
  switch (ministerio) {
    case 'louvor':
      return [
        'Condutor',
        'Baterista',
        'Guitarrista',
        'Baixista',
        'Tecladista',
        'Backing Vocal 1',
        'Backing Vocal 2',
        'Backing Vocal 3',
        'Backing Vocal 4',
        'Backing Vocal 5',
      ];
    case 'multimidia':
      return ['Iluminação', 'Projeção/Telão', 'Letras', 'Transmissão', 'Som'];
    case 'diaconos':
      return [
        'Hall de Entrada - Pessoa 1',
        'Hall de Entrada - Pessoa 2',
        'Hall do Templo - Pessoa 1',
        'Hall do Templo - Pessoa 2',
      ];
    case 'danca':
    case 'midia':
    default:
      return List.generate(10, (i) => 'Integrante ${i + 1}');
  }
}

class EscalaMensalScreen extends ConsumerStatefulWidget {
  final String ministerio;
  final DateTime? mesInicial;
  const EscalaMensalScreen({super.key, required this.ministerio, this.mesInicial});

  @override
  ConsumerState<EscalaMensalScreen> createState() => _EscalaMensalScreenState();
}

class _EscalaMensalScreenState extends ConsumerState<EscalaMensalScreen> {
  late DateTime _mes = widget.mesInicial ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _processando = false;

  List<EventModel> _eventosIgrejaDoMes(List<EventModel> todos) {
    return todos.where((e) => e.escopo == EventoEscopo.igreja).toList();
  }

  List<(DateTime data, EventModel evento)> _ocorrenciasDoMes(List<EventModel> eventosIgreja) {
    final inicio = _mes;
    final fim = DateTime(_mes.year, _mes.month + 1, 0);
    final lista = <(DateTime, EventModel)>[];
    for (final evento in eventosIgreja) {
      for (final occ in evento.occurrencesBetween(inicio, fim)) {
        lista.add((occ, evento));
      }
    }
    lista.sort((a, b) => a.$1.compareTo(b.$1));
    return lista;
  }

  Future<void> _baixarModelo(List<(DateTime, EventModel)> ocorrencias) async {
    if (ocorrencias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há EBD/Culto de Celebração/Culto da Família nesse mês.')),
      );
      return;
    }

    final colunas = _colunasFuncoes(widget.ministerio);
    final workbook = xls.Excel.createExcel();
    final abaPadrao = workbook.getDefaultSheet()!;
    final sheet = workbook[abaPadrao];

    final cabecalho = ['Data', 'Culto', ...colunas];
    sheet.appendRow(cabecalho.map((c) => xls.TextCellValue(c)).toList());

    for (final (data, evento) in ocorrencias) {
      final linha = <xls.CellValue>[
        xls.TextCellValue(DateFormat('dd/MM/yyyy').format(data)),
        xls.TextCellValue(evento.titulo),
      ];
      for (var i = 0; i < colunas.length; i++) {
        linha.add(xls.TextCellValue(''));
      }
      sheet.appendRow(linha);
    }

    final bytes = workbook.encode();
    if (bytes == null) return;

    final nomeArquivo =
        'escala_${widget.ministerio}_${DateFormat('yyyy_MM').format(_mes)}.xlsx';
    final arquivo = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nomeArquivo,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    await Share.shareXFiles([arquivo], text: 'Modelo de escala pra preencher e devolver.');
  }

  Future<void> _importarPlanilha(List<(DateTime, EventModel)> ocorrencias) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (resultado == null || resultado.files.single.bytes == null) return;

    setState(() => _processando = true);
    final naoEncontrados = <String>[];
    var posicoesPreenchidas = 0;

    try {
      final workbook = xls.Excel.decodeBytes(resultado.files.single.bytes!);
      final sheet = workbook.tables.values.first;
      final linhas = sheet.rows;
      if (linhas.length < 2) throw Exception('Planilha vazia.');

      final cabecalho = linhas.first.map((c) => c?.value?.toString() ?? '').toList();
      final colunasFuncoes = cabecalho.sublist(2); // depois de Data e Culto

      final service = EscalaServicoService();

      for (var i = 1; i < linhas.length; i++) {
        final linha = linhas[i];
        final dataTexto = linha.isNotEmpty ? linha[0]?.value?.toString() : null;
        final cultoTexto = linha.length > 1 ? linha[1]?.value?.toString() : null;
        if (dataTexto == null || dataTexto.trim().isEmpty) continue;

        final dataLinha = DateFormat('dd/MM/yyyy').parse(dataTexto.trim());

        // Acha o evento certo: mesmo titulo/tipo E que tenha uma
        // ocorrencia exatamente nessa data.
        final correspondente = ocorrencias.where((oc) {
          final mesmaData = oc.$1.year == dataLinha.year &&
              oc.$1.month == dataLinha.month &&
              oc.$1.day == dataLinha.day;
          final mesmoCulto = cultoTexto == null || oc.$2.titulo.trim() == cultoTexto.trim();
          return mesmaData && mesmoCulto;
        }).toList();

        if (correspondente.isEmpty) continue;
        final (dataOcorrencia, evento) = correspondente.first;

        final escalaId = await service.buscarOuCriarEscala(
          ministerio: widget.ministerio,
          eventoId: evento.id,
          dataOcorrencia: dataOcorrencia,
        );
        final posicoesAtuais = await service.listarPosicoes(escalaId);

        for (var c = 0; c < colunasFuncoes.length; c++) {
          final nomeColuna = colunasFuncoes[c];
          final valorCelula = (c + 2 < linha.length) ? linha[c + 2]?.value?.toString() : null;
          if (valorCelula == null || valorCelula.trim().isEmpty) continue;

          final nomePessoa = valorCelula.trim();
          final pessoas = await service.buscarPessoasDoMinisterio(widget.ministerio, nomePessoa);
          final encontrada = pessoas
              .where((p) => p.nome.toLowerCase() == nomePessoa.toLowerCase())
              .toList();

          if (encontrada.isEmpty) {
            naoEncontrados.add('$nomePessoa ($nomeColuna, ${DateFormat('dd/MM').format(dataLinha)})');
            continue;
          }

          // Pros Diaconos, as colunas "X - Pessoa 1" / "X - Pessoa 2"
          // caem na MESMA posicao (funcao "X"), so muda o slot.
          String funcaoAlvo = nomeColuna;
          var slot = 1;
          if (widget.ministerio == 'diaconos' && nomeColuna.contains(' - Pessoa ')) {
            final partes = nomeColuna.split(' - Pessoa ');
            funcaoAlvo = partes[0];
            slot = int.tryParse(partes[1]) ?? 1;
          }

          var posicao = posicoesAtuais.where((p) => p.funcao == funcaoAlvo).toList();
          String posicaoId;
          if (posicao.isEmpty) {
            await service.adicionarPosicao(escalaId: escalaId, funcao: funcaoAlvo);
            final atualizadas = await service.listarPosicoes(escalaId);
            posicaoId = atualizadas.firstWhere((p) => p.funcao == funcaoAlvo).id;
          } else {
            posicaoId = posicao.first.id;
          }

          if (slot == 1) {
            await service.definirPessoa(posicaoId, encontrada.first.id);
          } else {
            await service.definirSegundaPessoa(posicaoId, encontrada.first.id);
          }
          posicoesPreenchidas++;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao importar: $e')));
      }
      setState(() => _processando = false);
      return;
    }

    setState(() => _processando = false);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importação concluída'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$posicoesPreenchidas posições preenchidas.'),
              if (naoEncontrados.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Esses nomes não bateram com ninguém do ministério '
                  '(confira a grafia e tenta de novo, ou escale manualmente):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...naoEncontrados.map((n) => Text('• $n')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Escala mensal — ${widget.ministerio.labelMinisterio}',
        showQrButton: false,
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (events) {
          final eventosIgreja = _eventosIgrejaDoMes(events);
          final ocorrencias = _ocorrenciasDoMes(eventosIgreja);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          setState(() => _mes = DateTime(_mes.year, _mes.month - 1, 1)),
                    ),
                    Text(
                      DateFormat("MMMM 'de' yyyy", 'pt_BR').format(_mes),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          setState(() => _mes = DateTime(_mes.year, _mes.month + 1, 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_processando) const LinearProgressIndicator(),
                if (_processando) const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _processando ? null : () => _baixarModelo(ocorrencias),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Baixar modelo do mês'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _processando ? null : () => _importarPlanilha(ocorrencias),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Importar planilha preenchida'),
                ),
                const SizedBox(height: 24),
                Text('Cultos desse mês (${ocorrencias.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: ocorrencias.isEmpty
                      ? const Center(child: Text('Nenhum culto geral nesse mês.'))
                      : ListView.builder(
                          itemCount: ocorrencias.length,
                          itemBuilder: (context, index) {
                            final (data, evento) = ocorrencias[index];
                            return ListTile(
                              dense: true,
                              title: Text(evento.titulo),
                              subtitle: Text(DateFormat("dd/MM (EEEE)", 'pt_BR').format(data)),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}