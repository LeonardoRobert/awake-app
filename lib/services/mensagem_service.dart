import '../models/mensagem_model.dart';
import 'supabase_service.dart';

/// Serve tanto pra Pedidos de Oracao quanto pra Testemunhos -- as duas
/// tabelas tem exatamente a mesma estrutura, so muda o nome.
class MensagemService {
  final String tabela; // 'pedidos_oracao' ou 'testemunhos'
  MensagemService(this.tabela);

  final _client = SupabaseService.client;

  Future<void> enviar({required String texto, required bool anonimo}) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from(tabela).insert({
      'profile_id': userId,
      'anonimo': anonimo,
      'texto': texto.trim(),
    });
  }

  /// So admin consegue ver tudo (RLS garante isso) -- pra qualquer
  /// outra pessoa, so retorna as proprias mensagens.
  Future<List<MensagemModel>> listarTodas() async {
    final data = await _client
        .from(tabela)
        .select('*, profiles(nome)')
        .order('criado_em', ascending: false);

    return (data as List)
        .map((e) => MensagemModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarComoLida(String id) async {
    await _client.from(tabela).update({'lido': true}).eq('id', id);
  }

  Future<void> apagar(String id) async {
    await _client.from(tabela).delete().eq('id', id);
  }
}
