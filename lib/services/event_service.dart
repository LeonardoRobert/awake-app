import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import 'supabase_service.dart';

class EventService {
  final _client = SupabaseService.client;

  Future<List<EventModel>> listUpcoming() async {
    final data = await _client
        .from('eventos')
        .select()
        .order('data_inicio', ascending: true);

    return (data as List)
        .map((e) => EventModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(EventModel event) async {
    await _client.from('eventos').insert(event.toInsertMap());
  }

  Future<void> update(String id, EventModel event) async {
    await _client.from('eventos').update(event.toInsertMap()).eq('id', id);
  }

  /// Apaga o evento inteiro (todas as ocorrencias, se for recorrente).
  Future<void> delete(String id) async {
    await _client.from('eventos').delete().eq('id', id);
  }

  /// Apaga so UMA ocorrencia (data) de um evento recorrente, mantendo
  /// as outras semanas da serie.
  Future<void> deleteOccurrence(String eventId, DateTime data) async {
    await _client.rpc('excluir_ocorrencia_evento', params: {
      'p_evento_id': eventId,
      'p_data': data.toIso8601String().split('T').first,
    });
  }

  /// Envia uma foto do evento pro Storage e devolve a URL publica dela.
  /// `sufixo` diferencia a foto de capa da foto formato Story.
  Future<String> uploadFotoEvento(
    Uint8List bytes,
    String nomeArquivo,
    String eventoId, {
    String sufixo = 'capa',
  }) async {
    final extensao = nomeArquivo.contains('.') ? nomeArquivo.split('.').last : 'jpg';
    final caminho =
        'eventos/$eventoId-$sufixo-${DateTime.now().millisecondsSinceEpoch}.$extensao';

    await _client.storage.from('eventos-fotos').uploadBinary(
          caminho,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('eventos-fotos').getPublicUrl(caminho);
  }
}
