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
}