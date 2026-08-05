import '../models/contribuicao_model.dart';
import 'supabase_service.dart';

class ContribuicaoService {
  final _client = SupabaseService.client;

  Future<List<ContribuicaoModel>> listarMinhasContribuicoes() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('contribuicoes')
        .select()
        .eq('profile_id', userId)
        .order('data', ascending: false);

    return (data as List)
        .map((e) => ContribuicaoModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
