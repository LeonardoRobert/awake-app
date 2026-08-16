import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/erro_amigavel.dart';
import '../../models/contribuicao_model.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/contribuicao_service.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/evento_semana_card.dart';
import '../../widgets/quem_esta_escalado.dart';
import 'escala_servico_screen.dart';

/// Acha a proxima ocorrencia de um evento a partir de hoje (ou a data
/// de criacao dele, se nao houver nenhuma futura) -- usado so como
/// ultimo recurso, quando a data exata clicada nao foi informada.
DateTime _proximaOcorrencia(EventModel event) {
  final hoje = DateTime.now();
  final futuras = event.occurrencesBetween(
    DateTime(hoje.year, hoje.month, hoje.day),
    hoje.add(const Duration(days: 60)),
  );
  return futuras.isNotEmpty ? futuras.first : event.dataInicio;
}

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  final DateTime? occurrenceDate;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.occurrenceDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    // Editar/excluir um evento e permitido pro admin, ou pro lider do
    // MINISTERIO DAQUELE EVENTO especificamente (nao so lider do
    // Awake) -- mesma regra que ja vale no banco (pode_gerenciar_evento).
    bool podeEditarEsteEvento(EventModel evento) {
      final profile = profileAsync.value;
      if (profile == null) return false;
      if (profile.isAdmin) return true;
      final ministerio = evento.escopo.ministerioCorrespondente;
      if (ministerio == null) return false;
      return profile.ministerios.any((m) => m.ehLider && m.ministerio == ministerio);
    }
    final profile = profileAsync.value;
    // Admin pode criar escala de QUALQUER ministerio de servico
    // (igual ja acontece no banco) -- os demais so veem os que
    // realmente lideram.
    final ministeriosServicoLiderados = profile == null
        ? <String>[]
        : profile.isAdmin
            ? ministeriosComEscalaServico
            : profile.ministerios
                .where((m) => m.ehLider && ministeriosComEscalaServico.contains(m.ministerio))
                .map((m) => m.ministerio)
                .toList();

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Detalhes do evento', showQrButton: false),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (events) {
          final matches = events.where((e) => e.id == eventId);
          final event = matches.isEmpty ? null : matches.first;
          if (event == null) {
            return const Center(child: Text('Evento nao encontrado.'));
          }

          // Se por algum motivo a data exata da ocorrencia nao foi
          // passada (ex: acesso direto por link), NUNCA cai no
          // dataInicio puro -- pra evento recorrente isso pode ser a
          // primeira vez que ele foi criado, meses atras, o que fazia
          // a escala aparecer em branco (checava a data errada). Em
          // vez disso, acha a proxima ocorrencia real a partir de hoje.
          final dataExibida = occurrenceDate ?? _proximaOcorrencia(event);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: event.cor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(event.labelCategoria, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(event.titulo, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(dataExibida)),
                  ],
                ),
                if (event.recorrente) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.repeat, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Repete toda ${DateFormat('EEEE', 'pt_BR').format(event.dataInicio)}'
                        '${event.recorrenciaFim != null ? ' até ${DateFormat('dd/MM/yyyy').format(event.recorrenciaFim!)}' : ''}',
                      ),
                    ],
                  ),
                ],
                if (event.local != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 18),
                      const SizedBox(width: 8),
                      Text(event.local!),
                    ],
                  ),
                ],
                if (event.descricao != null) ...[
                  const SizedBox(height: 16),
                  Text(event.descricao!),
                ],
                if (event.fotoUrl != null) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      event.fotoUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(event.fotoUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Baixar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BotaoCompartilharEvento(evento: event, data: dataExibida),
                      ),
                    ],
                  ),
                ],
                if (event.ingressado) ...[
                  const SizedBox(height: 24),
                  _SecaoPagamentosEvento(evento: event),
                ],
                if (event.escopo == EventoEscopo.igreja) ...[
                  QuemEstaEscalado(eventoId: event.id, dataOcorrencia: dataExibida),
                ],
                if (event.escopo == EventoEscopo.igreja && ministeriosServicoLiderados.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ...ministeriosServicoLiderados.map((ministerio) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EscalaServicoScreen(
                              ministerio: ministerio,
                              ocorrencias: [(dataExibida, event)],
                            ),
                          )),
                          icon: const Icon(Icons.assignment_ind_outlined),
                          label: Text('Criar/editar escala de ${ministerio.labelMinisterio}'),
                        ),
                      )),
                ],
                if (podeEditarEsteEvento(event)) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editarEvento(context, event, dataExibida),
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () => _confirmarExclusao(
                            context,
                            ref,
                            eventId,
                            event.titulo,
                            event.recorrente,
                            dataExibida,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Se o evento nao for recorrente, edita normal. Se for, pergunta se
  /// e pra editar so essa data (vira um evento avulso novo, e a serie
  /// original ganha uma excecao nessa data) ou a serie inteira.
  Future<void> _editarEvento(BuildContext context, EventModel event, DateTime dataOcorrencia) async {
    if (!event.recorrente) {
      context.push('/eventos/novo', extra: event);
      return;
    }

    final escopo = await _perguntarEscopo(context, 'evento', acao: 'editar', destrutivo: false);
    if (escopo == null || !context.mounted) return;

    if (escopo == 'uma') {
      context.push(
        '/eventos/novo',
        extra: EdicaoOcorrenciaUnica(evento: event, dataOcorrencia: dataOcorrencia),
      );
    } else {
      context.push('/eventos/novo', extra: event);
    }
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String titulo,
    bool recorrente,
    DateTime dataOcorrencia,
  ) async {
    if (recorrente) {
      final escopo = await _perguntarEscopo(context, 'evento');
      if (escopo == null) return;

      if (escopo == 'uma') {
        try {
          await ref.read(eventServiceProvider).deleteOccurrence(eventId, dataOcorrencia);
          ref.invalidate(upcomingEventsProvider);
          if (context.mounted) Navigator.of(context).pop();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Erro ao excluir: ${mensagemDeErroAmigavel(e)}')));
          }
        }
        return;
      }
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir evento?'),
        content: Text(
          'Isso vai apagar "$titulo" permanentemente'
          '${recorrente ? ' (todas as ocorrências da série)' : ''}. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      await ref.read(eventServiceProvider).delete(eventId);
      ref.invalidate(upcomingEventsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }

  Future<String?> _perguntarEscopo(
    BuildContext context,
    String tipoItem, {
    String acao = 'excluir',
    bool destrutivo = true,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Esse $tipoItem se repete toda semana'),
        content: Text('O que você quer $acao?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop('uma'),
            child: const Text('Só esta data'),
          ),
          FilledButton(
            style: destrutivo ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
            onPressed: () => Navigator.of(dialogContext).pop('todas'),
            child: const Text('Toda a série'),
          ),
        ],
      ),
    );
  }
}

/// Botão "Compartilhar" da tela de detalhes -- antes so mandava o link
/// cru da foto (Share.share(event.fotoUrl!)), sem legenda nenhuma.
/// Agora busca a foto de verdade e manda junto com o texto (título,
/// data/hora, local, descrição), mesmo padrão do card da Início
/// (EventoSemanaCard/montarTextoCompartilharEvento).
class _BotaoCompartilharEvento extends StatefulWidget {
  final EventModel evento;
  final DateTime data;
  const _BotaoCompartilharEvento({required this.evento, required this.data});

  @override
  State<_BotaoCompartilharEvento> createState() => _BotaoCompartilharEventoState();
}

class _BotaoCompartilharEventoState extends State<_BotaoCompartilharEvento> {
  bool _compartilhando = false;

  Future<void> _compartilhar() async {
    final texto = montarTextoCompartilharEvento(widget.evento, widget.data);

    setState(() => _compartilhando = true);
    try {
      if (widget.evento.fotoUrl != null) {
        final resposta = await http.get(Uri.parse(widget.evento.fotoUrl!));
        final arquivo = XFile.fromData(
          resposta.bodyBytes,
          name: 'convite.jpg',
          mimeType: 'image/jpeg',
        );
        await Share.shareXFiles([arquivo], text: texto);
      } else {
        await Share.share(texto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível compartilhar: ${mensagemDeErroAmigavel(e)}')));
      }
    } finally {
      if (mounted) setState(() => _compartilhando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _compartilhando ? null : _compartilhar,
      icon: _compartilhando
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.share_outlined),
      label: Text(_compartilhando ? 'Preparando...' : 'Compartilhar'),
    );
  }
}

/// Seção mostrada nos detalhes de um evento ingressado: valor total,
/// parcelas sugeridas, métodos de pagamento aceitos, barra de
/// progresso e histórico dos MEUS pagamentos pra esse evento.
class _SecaoPagamentosEvento extends StatefulWidget {
  final EventModel evento;
  const _SecaoPagamentosEvento({required this.evento});

  @override
  State<_SecaoPagamentosEvento> createState() => _SecaoPagamentosEventoState();
}

class _SecaoPagamentosEventoState extends State<_SecaoPagamentosEvento> {
  late Future<List<ContribuicaoModel>> _futuroPagamentos;

  @override
  void initState() {
    super.initState();
    _futuroPagamentos = ContribuicaoService().listarMeusPagamentosDoEvento(widget.evento.id);
  }

  static const _labelMetodo = {
    'pix': 'Pix',
    'cartao': 'Cartão',
    'dinheiro': 'Dinheiro',
  };

  @override
  Widget build(BuildContext context) {
    final valorTotal = widget.evento.valorTotal ?? 0;
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return FutureBuilder<List<ContribuicaoModel>>(
      future: _futuroPagamentos,
      builder: (context, snapshot) {
        final pagamentos = snapshot.data ?? [];
        final totalPago = pagamentos.fold<double>(0, (soma, p) => soma + p.valor);
        final progresso = valorTotal > 0 ? (totalPago / valorTotal).clamp(0.0, 1.0) : 0.0;
        final porcentagem = (progresso * 100).round();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.confirmation_num_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text('Inscrição', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: progresso, minHeight: 8),
                ),
                const SizedBox(height: 6),
                Text(
                  '$porcentagem% pago — ${formatoMoeda.format(totalPago)} de '
                  '${formatoMoeda.format(valorTotal)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (widget.evento.parcelasSugeridas != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Parcelas sugeridas: ${widget.evento.parcelasSugeridas}x de '
                    '${formatoMoeda.format(valorTotal / widget.evento.parcelasSugeridas!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (widget.evento.metodosPagamento != null &&
                    widget.evento.metodosPagamento!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Formas de pagamento: ${widget.evento.metodosPagamento!.map((m) => _labelMetodo[m] ?? m).join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Meus pagamentos', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ))
                else if (pagamentos.isEmpty)
                  const Text('Nenhum pagamento registrado ainda. Fale com a administração.')
                else
                  ...pagamentos.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(p.data)),
                            Text(formatoMoeda.format(p.valor),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}