import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import '../models/profile_model.dart';
import '../screens/calendar/escala_mensal_screen.dart';
import '../screens/calendar/escala_semanal_screen.dart';
import '../services/escala_servico_service.dart';

/// Abre o fluxo de "Escala" pra um lider de ministerio de servico:
/// se ele lidera mais de um ministerio, pergunta qual primeiro; depois
/// pergunta Semanal ou Mensal.
Future<void> abrirFluxoEscala(
  BuildContext context, {
  required List<MinisterioMembership> ministeriosLiderados,
  required List<EventModel> eventosIgreja,
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
    await _abrirEscalaSemanal(context, ministerio, eventosIgreja);
  } else {
    await _abrirEscalaMensal(context, ministerio);
  }
}

Future<void> _abrirEscalaSemanal(
  BuildContext context,
  String ministerio,
  List<EventModel> eventosIgreja,
) async {
  final now = DateTime.now();
  final hoje = DateTime(now.year, now.month, now.day);
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

  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => EscalaSemanalScreen(ministerio: ministerio, ocorrencias: ocorrencias),
  ));
}

Future<void> _abrirEscalaMensal(BuildContext context, String ministerio) async {
  final agora = DateTime.now();
  var mesEscolhido = DateTime(agora.year, agora.month, 1);

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
