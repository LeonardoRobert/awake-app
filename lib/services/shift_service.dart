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

  /// Lista escalas futuras usando a view `escalas_com_vagas`
  /// (ver supabase/schema.sql), que ja calcula quantas vagas
  /// estao ocupadas.
  Future<List<ShiftModel>> listUpcomingShifts() async {
    final data = await _client
        .from('escalas_com_vagas')
        .select('*, areas_servico(*)')
        .gte('data', DateTime.now().toIso8601String().split('T').first)
        .order('data', ascending: true);

    return (data as List)
        .map((e) => ShiftModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createShift({
    required String areaId,
    required DateTime data,
    required String horarioInicio,
    required String horarioFim,
    required int vagas,
  }) async {
    await _client.from('escalas').insert({
      'area_id': areaId,
      'data': data.toIso8601String().split('T').first,
      'horario_inicio': horarioInicio,
      'horario_fim': horarioFim,
      'vagas': vagas,
    });
  }

  /// Chama a funcao no banco que valida vaga disponivel e o limite de
  /// 2 domingos por mes antes de gravar a inscricao
  /// (ver supabase/schema.sql: inscrever_em_escala).
  Future<void> signUp(String escalaId) async {
    await _client.rpc('inscrever_em_escala', params: {'p_escala_id': escalaId});
  }

  /// Chama a funcao no banco que aplica a regra de cancelamento
  /// com 24h de antecedencia (ver supabase/schema.sql: cancel_signup).
  Future<void> cancelSignup(String inscricaoId) async {
    await _client.rpc('cancel_signup', params: {'p_inscricao_id': inscricaoId});
  }

  Future<List<SignupModel>> listMySignups() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('inscricoes')
        .select('*, escalas(*, areas_servico(*))')
        .eq('user_id', userId)
        .order('inscrito_em', ascending: false);

    return (data as List)
        .map((e) => SignupModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Usado pelo lider: lista quem se inscreveu em uma escala especifica.
  Future<List<SignupModel>> listSignupsForShift(String escalaId) async {
    final data = await _client
        .from('inscricoes')
        .select('*, profiles(nome)')
        .eq('escala_id', escalaId)
        .order('inscrito_em', ascending: true);

    return (data as List)
        .map((e) => SignupModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
