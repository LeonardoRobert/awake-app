import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import '../models/profile_model.dart';
import '../screens/calendar/escala_mensal_screen.dart';
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

  final escolhida = await showModalBottomSheet<(DateTime, EventModel)>(
    context: context,
    builder: (dialogContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Qual culto?', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ...ocorrencias.map((oc) => ListTile(
                title: Text(oc.$2.titulo),
                subtitle: Text(DateFormat("dd/MM (EEEE) HH:mm", 'pt_BR').format(oc.$1)),
                onTap: () => Navigator.of(dialogContext).pop(oc),
              )),
        ],
      ),
    ),
  );

  if (escolhida == null || !context.mounted) return;

  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => EscalaServicoScreen(
      ministerio: ministerio,
      eventoId: escolhida.$2.id,
      eventoTitulo: escolhida.$2.titulo,
      dataOcorrencia: escolhida.$1,
    ),
  ));
}

Future<void> _abrirEscalaMensal(
  BuildContext context,
  String ministerio,
  DateTime? diaSelecionado,
) async {
  final base = diaSelecionado ?? DateTime.now();
  var mesEscolhido = DateTime(base.year, base.month, 1);

  final confirmado = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Escala de qual mês?'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setDialogState(() =>
                  mesEscolhido = DateTime(mesEscolhido.year, mesEscolhido.month - 1, 1)),
            ),
            Text(
              DateFormat("MMMM 'de' yyyy", 'pt_BR').format(mesEscolhido),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setDialogState(() =>
                  mesEscolhido = DateTime(mesEscolhido.year, mesEscolhido.month + 1, 1)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(mesEscolhido),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ),
  );

  if (confirmado == null || !context.mounted) return;

  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => EscalaMensalScreen(ministerio: ministerio, mesInicial: confirmado),
  ));
}