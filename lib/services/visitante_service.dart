import '../models/visitante_model.dart';
import 'supabase_service.dart';

class VisitanteService {
  final _client = SupabaseService.client;

  /// So quem esta escalado na area "Primeira Vez" pode registrar.
  Future<bool> podeRegistrarVisitante() async {
    if (_client.auth.currentUser == null) return false;
    return await _client.rpc('esta_na_escala_primeira_vez') as bool;
  }

  Future<void> registrar(Map<String, dynamic> dados) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('visitantes_primeira_vez').insert({
      'registrado_por': userId,
      'dados': dados,
    });
  }

  Future<List<VisitanteModel>> listarTodos() async {
    final data = await _client
        .from('visitantes_primeira_vez')
        .select('*, profiles(nome)')
        .order('criado_em', ascending: false);
    return (data as List)
        .map((e) => VisitanteModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarComoLido(String id) async {
    await _client.from('visitantes_primeira_vez').update({'lido': true}).eq('id', id);
  }
}
