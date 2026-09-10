import '../models/grupo_casais_model.dart';
import 'supabase_service.dart';

class GrupoCasaisService {
  final _client = SupabaseService.client;

  Future<List<GrupoCasaisModel>> listarAtivos() async {
    final data = await _client
        .from('grupos_casais_catalogo')
        .select('slug, nome')
        .eq('ativo', true)
        .order('nome');
    return (data as List)
        .map((e) => GrupoCasaisModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
