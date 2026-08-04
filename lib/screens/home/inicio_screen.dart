import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela de Inicio: mostra so os eventos de SEXTA-FEIRA marcados como
/// "Exclusivo Awake" (nao eventos gerais da igreja), dos proximos 7
/// dias -- com a arte do evento (se tiver) e um botao pra compartilhar
/// no WhatsApp.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Início'),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(upcomingEventsProvider.future),
        child: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro ao carregar: $err')),
          data: (events) {
            final now = DateTime.now();
            final hoje = DateTime(now.year, now.month, now.day);
            final fim = hoje.add(const Duration(days: 6));

            final eventosDaSemana = <_OcorrenciaAwake>[];
            for (final event in events) {
              if (!event.exclusivoAwake) continue;
              for (final occ in event.occurrencesBetween(hoje, fim)) {
                if (occ.weekday == DateTime.friday) {
                  eventosDaSemana.add(_OcorrenciaAwake(event, occ));
                }
              }
            }
            eventosDaSemana.sort((a, b) => a.data.compareTo(b.data));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Text('Essa semana na Awake! 🔥',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                if (eventosDaSemana.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Nenhum evento de sexta-feira da Awake essa semana.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...eventosDaSemana.map((oc) => _EventoAwakeCard(ocorrencia: oc)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OcorrenciaAwake {
  final EventModel event;
  final DateTime data;
  _OcorrenciaAwake(this.event, this.data);
}

class _EventoAwakeCard extends StatefulWidget {
  final _OcorrenciaAwake ocorrencia;
  const _EventoAwakeCard({required this.ocorrencia});

  @override
  State<_EventoAwakeCard> createState() => _EventoAwakeCardState();
}

class _EventoAwakeCardState extends State<_EventoAwakeCard> {
  bool _compartilhando = false;
  bool _compartilhandoInstagram = false;

  String _montarTexto(EventModel evento, DateTime data) {
    final dataFormatada =
        DateFormat("EEEE, dd 'de' MMMM 'às' HH:mm", 'pt_BR').format(data);
    final buffer = StringBuffer()
      ..writeln('🔥 *${evento.titulo}*')
      ..writeln()
      ..writeln('🗓️ $dataFormatada');

    if (evento.local != null && evento.local!.trim().isNotEmpty) {
      buffer.writeln('📍 ${evento.local}');
    }
    if (evento.descricao != null && evento.descricao!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(evento.descricao);
    }
    buffer
      ..writeln()
      ..writeln('Vem com a gente! 🙌');

    return buffer.toString();
  }

  Future<void> _compartilharNoWhatsApp() async {
    final evento = widget.ocorrencia.event;
    final texto = _montarTexto(evento, widget.ocorrencia.data);

    setState(() => _compartilhando = true);
    try {
      if (evento.fotoUrl != null) {
        final resposta = await http.get(Uri.parse(evento.fotoUrl!));
        final arquivo = XFile.fromData(
          resposta.bodyBytes,
          name: 'convite-awake.jpg',
          mimeType: 'image/jpeg',
        );
        // Abre o menu de compartilhar do celular com a imagem + texto
        // ja prontos -- a pessoa so precisa tocar em WhatsApp na lista.
        await Share.shareXFiles([arquivo], text: texto);
      } else {
        await Share.share(texto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível compartilhar: $e')));
      }
    } finally {
      if (mounted) setState(() => _compartilhando = false);
    }
  }

  /// Abre o menu de compartilhar do celular so com a foto formato Story
  /// -- dentro do Instagram, a pessoa encontra a opcao "Adicionar ao
  /// Stories" no proprio menu dele. Nao existe um jeito universal
  /// (Android + iPhone + navegador) de pular direto pro Stories sem
  /// passar por esse menu.
  Future<void> _compartilharNoInstagram() async {
    final evento = widget.ocorrencia.event;
    if (evento.fotoStoryUrl == null) return;

    setState(() => _compartilhandoInstagram = true);
    try {
      final resposta = await http.get(Uri.parse(evento.fotoStoryUrl!));
      final arquivo = XFile.fromData(
        resposta.bodyBytes,
        name: 'story-awake.jpg',
        mimeType: 'image/jpeg',
      );
      await Share.shareXFiles([arquivo]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível compartilhar: $e')));
      }
    } finally {
      if (mounted) setState(() => _compartilhandoInstagram = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final evento = widget.ocorrencia.event;
    final data = widget.ocorrencia.data;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(evento.titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Text(DateFormat("EEEE, dd/MM 'às' HH:mm", 'pt_BR').format(data)),
              ],
            ),
            if (evento.local != null && evento.local!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(evento.local!)),
                ],
              ),
            ],
            if (evento.fotoUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(evento.fotoUrl!, fit: BoxFit.cover),
                ),
              ),
            ],
            if (evento.descricao != null && evento.descricao!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(evento.descricao!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _compartilhando ? null : _compartilharNoWhatsApp,
              icon: _compartilhando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: Text(_compartilhando ? 'Preparando...' : 'Compartilhar no WhatsApp'),
            ),
            if (evento.fotoStoryUrl != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _compartilhandoInstagram ? null : _compartilharNoInstagram,
                icon: _compartilhandoInstagram
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _compartilhandoInstagram ? 'Preparando...' : 'Adicionar ao Instagram',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
