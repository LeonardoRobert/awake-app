import '../models/escala_servico_model.dart' show PessoaBusca;
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

  /// Contagem de vagas preenchidas por (escala, data). Usa uma funcao do
  /// banco (contar_inscritos_geral) em vez de consultar a tabela direto,
  /// porque a tabela `inscricoes` so mostra as PROPRIAS inscricoes de
  /// cada pessoa -- a funcao devolve so o numero, sem identificar quem
  /// se inscreveu, entao todo mundo consegue ver a contagem certa.
  Future<Map<String, int>> fetchInscritosCounts() async {
    final data = await _client.rpc('contar_inscritos_geral');

    final counts = <String, int>{};
    for (final row in (data as List)) {
      final map = row as Map<String, dynamic>;
      final key = '${map['escala_id']}_${map['data_ocorrencia']}';
      counts[key] = (map['total'] as num).toInt();
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

  /// Apaga a escala inteira (inclusive futuras ocorrencias, se for
  /// recorrente). As inscricoes e checkins relacionados sao apagados
  /// junto automaticamente pelo banco.
  Future<void> deleteShiftTemplate(String id) async {
    await _client.from('escalas').delete().eq('id', id);
  }

  /// Apaga so UMA ocorrencia (data) de uma escala recorrente, mantendo
  /// as outras semanas da serie. Cancela as inscricoes so daquela data.
  Future<void> deleteShiftOccurrence(String escalaId, DateTime data) async {
    await _client.rpc('excluir_ocorrencia_escala', params: {
      'p_escala_id': escalaId,
      'p_data': data.toIso8601String().split('T').first,
    });
  }

  Future<void> signUp(String escalaId, DateTime dataOcorrencia) async {
    await _client.rpc('inscrever_em_escala', params: {
      'p_escala_id': escalaId,
      'p_data_ocorrencia': dataOcorrencia.toIso8601String().split('T').first,
    });
  }

  /// So' lider do Awake ou admin -- escala outra pessoa numa ocorrencia,
  /// mesmo que ela nao tenha se inscrito sozinha. Passa pelas mesmas
  /// checagens de inscrever_em_escala (vaga lotada, horario sobreposto,
  /// limite de domingos), so' que pra p_user_id em vez de quem chamou.
  Future<void> inscreverComoLider({
    required String userId,
    required String escalaId,
    required DateTime dataOcorrencia,
  }) async {
    await _client.rpc('inscrever_membro_como_lider', params: {
      'p_user_id': userId,
      'p_escala_id': escalaId,
      'p_data_ocorrencia': dataOcorrencia.toIso8601String().split('T').first,
    });
  }

  /// Busca por nome pra escalar manualmente -- qualquer pessoa cadastrada
  /// pode ser escalada (inscrever_em_escala tambem nao exige que a
  /// pessoa pertenca a nenhum ministerio especifico).
  Future<List<PessoaBusca>> buscarMembroPorNome(String query) async {
    if (query.trim().length < 2) return [];
    final data = await _client
        .from('profiles')
        .select('id, nome')
        .ilike('nome', '%${query.trim()}%')
        .order('nome')
        .limit(20);
    return (data as List)
        .map((e) => PessoaBusca(
              id: (e as Map<String, dynamic>)['id'] as String,
              nome: e['nome'] as String,
            ))
        .toList();
  }

  Future<void> cancelSignup(String inscricaoId) async {
    await _client.rpc('cancel_signup', params: {'p_inscricao_id': inscricaoId});
  }

  /// Ordena por data mais proxima primeiro (a escala de amanha aparece
  /// antes da escala do mes que vem).
  Future<List<SignupModel>> listMySignups() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('inscricoes')
        .select('*, escalas(*, areas_servico(*))')
        .eq('user_id', userId)
        .order('data_ocorrencia', ascending: true);

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