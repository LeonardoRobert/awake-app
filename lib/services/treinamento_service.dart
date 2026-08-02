import '../models/treinamento_model.dart';
import 'supabase_service.dart';

class TreinamentoService {
  final _client = SupabaseService.client;

  Future<List<TreinamentoModel>> listAll() async {
    final data = await _client
        .from('treinamentos')
        .select()
        .order('criado_em', ascending: false);

    return (data as List)
        .map((e) => TreinamentoModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String titulo,
    String? descricao,
    required String urlVideo,
  }) async {
    await _client.from('treinamentos').insert({
      'titulo': titulo,
      'descricao': descricao,
      'url_video': urlVideo,
    });
  }

  Future<void> update(
    String id, {
    required String titulo,
    String? descricao,
    required String urlVideo,
  }) async {
    await _client.from('treinamentos').update({
      'titulo': titulo,
      'descricao': descricao,
      'url_video': urlVideo,
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('treinamentos').delete().eq('id', id);
  }
}