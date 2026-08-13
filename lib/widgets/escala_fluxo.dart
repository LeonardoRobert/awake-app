import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../models/profile_model.dart';
import '../screens/calendar/escala_grade_screen.dart';
import '../screens/calendar/escala_servico_screen.dart';
import '../services/escala_servico_service.dart';

/// Abre o fluxo de "Escala" pra um lider de ministerio de servico:
/// se ele lidera mais de um ministerio, pergunta qual primeiro; depois
/// pergunta Semanal ou Mensal.
Future<void> abrirFluxoEscala(
  BuildContext context, {
  required List<MinisterioMembership> ministeriosLiderados,
  required List<EventModel> eventosIgreja,
  DateTime? diaSelecionado,
}) async {
  final ministeriosServico = ministeriosLiderados
      .where((m) => m.ehLider && ministeriosComEscalaServico.contains(m.ministerio))
      .map((m) => m.ministerio)
      .toList();

  if (ministeriosServico.isEmpty) return;

  String ministerio;
  if (ministeriosServico.length == 1) {
    ministerio = ministeriosServico.first;
  } else {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      builder: (dialogContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Escala de qual ministério?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...ministeriosServico.map((m) => ListTile(
                  title: Text(m.labelMinisterio),
                  onTap: () => Navigator.of(dialogContext).pop(m),
                )),
          ],
        ),
      ),
    );
    if (escolhido == null) return;
    ministerio = escolhido;
  }

  if (!context.mounted) return;

  final tipo = await showModalBottomSheet<String>(
    context: context,
    builder: (dialogContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Escala semanal ou mensal?', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Semanal'),
            subtitle: const Text('Escolhe pessoa por pessoa, culto a culto'),
            onTap: () => Navigator.of(dialogContext).pop('semanal'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Mensal'),
            subtitle: const Text('Baixa/importa uma planilha do mês inteiro'),
            onTap: () => Navigator.of(dialogContext).pop('mensal'),
          ),
        ],
      ),
    ),
  );

  if (tipo == null || !context.mounted) return;

  if (tipo == 'semanal') {
    await _abrirEscalaSemanal(context, ministerio, eventosIgreja, diaSelecionado);
  } else {
    await _abrirEscalaMensal(context, ministerio, diaSelecionado);
  }
}

Future<void> _abrirEscalaSemanal(
  BuildContext context,
  String ministerio,
  List<EventModel> eventosIgreja,
  DateTime? diaSelecionado,
) async {
  // Se veio de um dia clicado no calendario, comeca a busca dali --
  // senao, comeca de hoje, como sempre foi.
  final now = DateTime.now();
  final hoje = diaSelecionado != null
      ? DateTime(diaSelecionado.year, diaSelecionado.month, diaSelecionado.day)
      : DateTime(now.year, now.month, now.day);
  final fim = hoje.add(const Duration(days: 7));

  final ocorrencias = <(DateTime, EventModel)>[];
  for (final evento in eventosIgreja) {
    for (final occ in evento.occurrencesBetween(hoje, fim)) {
      ocorrencias.add((occ, evento));
    }
  }
  ocorrencias.sort((a, b) => a.$1.compareTo(b.$1));

  if (ocorrencias.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nenhum culto geral nos próximos 7 dias.')),
    );
    return;
  }

  // Mostra todos os cultos da semana de uma vez na mesma tela (EBD,
  // Culto de Celebracao, Culto da Familia etc.), sem precisar escolher
  // um por um -- ver EscalaServicoScreen.
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => EscalaServicoScreen(
      ministerio: ministerio,
      ocorrencias: ocorrencias,
    ),
  ));
}

Future<void> _abrirEscalaMensal(
  BuildContext context,
  String ministerio,
  DateTime? diaSelecionado,
) async {
  // A propria grade ja tem abas de mes (e seta de ano) -- entao abre
  // direto nela, ja no mes do dia clicado (ou no mes atual), sem
  // precisar de um seletor de mes separado antes.
  final base = diaSelecionado ?? DateTime.now();
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => EscalaGradeScreen(
      ministerio: ministerio,
      anoInicial: base.year,
      mesInicial: base.month,
    ),
  ));
}