import '../models/questionario_model.dart';
import 'supabase_service.dart';

class QuestionarioService {
  final _client = SupabaseService.client;

  /// Ja preencheu o questionario alguma vez?
  Future<bool> jaRespondeu() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return true; // por seguranca, nao insiste
    final data = await _client
        .from('questionarios_novo_servo')
        .select('id')
        .eq('profile_id', userId)
        .maybeSingle();
    return data != null;
  }

  /// Ja se inscreveu em pelo menos uma escala do Awake alguma vez?
  Future<bool> jaSeInscreveuEmAlgumaEscala() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final data = await _client
        .from('inscricoes')
        .select('id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
    return data != null;
  }

  Future<void> enviar(Map<String, dynamic> respostas) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('questionarios_novo_servo').insert({
      'profile_id': userId,
      'respostas': respostas,
    });
  }

  Future<List<QuestionarioNovoServo>> listarTodos() async {
    final data = await _client
        .from('questionarios_novo_servo')
        .select('*, profiles(nome)')
        .order('criado_em', ascending: false);
    return (data as List)
        .map((e) => QuestionarioNovoServo.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarComoLido(String id) async {
    await _client.from('questionarios_novo_servo').update({'lido': true}).eq('id', id);
  }
}
