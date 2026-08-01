import '../models/service_area_model.dart';
import '../models/shift_model.dart';
import '../models/signup_model.dart';
import 'supabase_service.dart';

class ShiftService {
  final _client = SupabaseService.client;

  Future<List<ServiceAreaModel>> listServiceAreas() async {
    final data = await _client.from('areas_servico').select().order('nome');
    return (data as List)
        .map((e) => ServiceAreaModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ShiftModel>> listShiftTemplates() async {
    final data = await _client.from('escalas').select('*, areas_servico(*)');
    return (data as List)
        .map((e) => ShiftModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> fetchInscritosCounts() async {
    final data = await _client
        .from('inscricoes')
        .select('escala_id, data_ocorrencia, status')
        .inFilter('status', ['inscrito', 'check_in_feito']);

    final counts = <String, int>{};
    for (final row in (data as List)) {
      final map = row as Map<String, dynamic>;
      final key = '${map['escala_id']}_${map['data_ocorrencia']}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> createShiftTemplate({
    required String nome,
    String? areaId,
    required DateTime data,
    required String horarioInicio,
    required String horarioFim,
    required int vagas,
    required bool recorrente,
    DateTime? recorrenciaFim,
  }) async {
    await _client.from('escalas').insert({
      'nome': nome,
      'area_id': areaId,
      'data': data.toIso8601String().split('T').first,
      'horario_inicio': horarioInicio,
      'horario_fim': horarioFim,
      'vagas': vagas,
      'recorrente': recorrente,
      'recorrencia_fim': recorrenciaFim?.toIso8601String().split('T').first,
    });
  }

  Future<void> updateShiftTemplate(String id, ShiftModel shift) async {
    await _client.from('escalas').update(shift.toInsertMap()).eq('id', id);
  }

  Future<void> signUp(String escalaId, DateTime dataOcorrencia) async {
    await _client.rpc('inscrever_em_escala', params: {
      'p_escala_id': escalaId,
      'p_data_ocorrencia': dataOcorrencia.toIso8601String().split('T').first,
    });
  }

  Future<void> cancelSignup(String inscricaoId) async {
    await _client.rpc('cancel_signup', params: {'p_inscricao_id': inscricaoId});
  }

  Future<List<SignupModel>> listMySignups() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('inscricoes')
        .select('*, escalas(*, areas_servico(*))')
        .eq('user_id', userId)
        .order('data_ocorrencia', ascending: false);

    return (data as List)
        .map((e) => SignupModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Usado pelo lider: lista quem se inscreveu numa ocorrencia especifica.
  /// So mostra inscricoes ativas (inscrito / check-in feito) -- cancelamentos
  /// nao aparecem mais aqui, pra nao poluir a lista do lider.
  Future<List<SignupModel>> listSignupsForOccurrence(
    String escalaId,
    DateTime dataOcorrencia,
  ) async {
    final data = await _client
        .from('inscricoes')
        .select('*, profiles(nome)')
        .eq('escala_id', escalaId)
        .eq('data_ocorrencia', dataOcorrencia.toIso8601String().split('T').first)
        .inFilter('status', ['inscrito', 'check_in_feito'])
        .order('inscrito_em', ascending: true);

    return (data as List)
        .map((e) => SignupModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}