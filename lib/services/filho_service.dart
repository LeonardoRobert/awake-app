import '../models/filho_model.dart';
import 'supabase_service.dart';

class FilhoService {
  final _client = SupabaseService.client;

  Future<List<FilhoModel>> listarMeusFilhos() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('filhos')
        .select()
        .eq('responsavel_id', userId)
        .order('data_nascimento');

    return (data as List)
        .map((e) => FilhoModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> adicionar({required String nome, required DateTime dataNascimento}) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('filhos').insert({
      'responsavel_id': userId,
      'nome': nome,
      'data_nascimento': dataNascimento.toIso8601String().split('T').first,
    });
  }

  Future<void> remover(String id) async {
    await _client.from('filhos').delete().eq('id', id);
  }
}
