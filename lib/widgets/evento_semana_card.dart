import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/erro_amigavel.dart';
import '../models/escala_servico_model.dart';
import '../models/event_model.dart';
import '../models/profile_model.dart';

class Ocorrencia {
  final EventModel event;
  final DateTime data;
  Ocorrencia(this.event, this.data);
}

/// Mesma regra de desempate do calendario: por escopo, e dentro do
/// Awake, por subgrupo (Genesis, Next, One).
int prioridadeGrupo(EventModel evento) {
  final grupos = evento.publicoAlvo;
  if (grupos == null || grupos.isEmpty) return 99;
  if (grupos.contains('genesis')) return 0;
  if (grupos.contains('next')) return 1;
  if (grupos.contains('one')) return 2;
  return 99;
}

int compararOcorrencias(Ocorrencia a, Ocorrencia b) {
  final porData = a.data.compareTo(b.data);
  if (porData != 0) return porData;
  final porEscopo = a.event.escopo.prioridade.compareTo(b.event.escopo.prioridade);
  if (porEscopo != 0) return porEscopo;
  return prioridadeGrupo(a.event).compareTo(prioridadeGrupo(b.event));
}

/// Monta o texto padrao de compartilhamento (titulo, data/hora, local,
/// descricao) -- usado tanto pelo card da Inicio quanto pelo botao
/// "Compartilhar" da tela de detalhes do evento, pra ficarem iguais.
String montarTextoCompartilharEvento(EventModel evento, DateTime data) {
  final dataFormatada = DateFormat("EEEE, dd 'de' MMMM 'às' HH:mm", 'pt_BR').format(data);
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

/// Card usado nas telas de Inicio (Awake e Shallom) pra mostrar um
/// evento da semana, com a arte (se tiver) e os botoes de
/// compartilhar no WhatsApp / Instagram.
class EventoSemanaCard extends StatefulWidget {
  final Ocorrencia ocorrencia;
  /// Se a pessoa logada estiver escalada nesse evento, isso vem
  /// preenchido -- mostra a "tarja" no topo do card.
  final MinhaEscalaResumo? escalaAqui;
  const EventoSemanaCard({super.key, required this.ocorrencia, this.escalaAqui});

  @override
  State<EventoSemanaCard> createState() => _EventoSemanaCardState();
}

class _EventoSemanaCardState extends State<EventoSemanaCard> {
  bool _compartilhando = false;
  bool _compartilhandoInstagram = false;

  Future<void> _compartilharNoWhatsApp() async {
    final evento = widget.ocorrencia.event;
    final texto = montarTextoCompartilharEvento(evento, widget.ocorrencia.data);

    setState(() => _compartilhando = true);
    try {
      if (evento.fotoUrl != null) {
        final resposta = await http.get(Uri.parse(evento.fotoUrl!));
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

  Future<void> _compartilharNoInstagram() async {
    final evento = widget.ocorrencia.event;
    if (evento.fotoStoryUrl == null) return;

    setState(() => _compartilhandoInstagram = true);
    try {
      final resposta = await http.get(Uri.parse(evento.fotoStoryUrl!));
      final arquivo = XFile.fromData(
        resposta.bodyBytes,
        name: 'story.jpg',
        mimeType: 'image/jpeg',
      );
      await Share.shareXFiles([arquivo]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível compartilhar: ${mensagemDeErroAmigavel(e)}')));
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.escalaAqui != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.withOpacity(0.85),
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Você está escalado(a): ${widget.escalaAqui!.funcao} '
                      '(${widget.escalaAqui!.ministerio.labelMinisterio})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
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
    ],
      ),
    );
  }
}
