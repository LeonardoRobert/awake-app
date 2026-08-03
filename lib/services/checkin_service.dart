import 'supabase_service.dart';

class CheckinService {
  final _client = SupabaseService.client;

  /// Confirma presenca numa ESCALA (exige que a pessoa esteja inscrita
  /// naquela ocorrencia). Retorna o nome do membro confirmado.
  Future<String> checkInEscala({
    required String qrCodeId,
    required String escalaId,
    required DateTime dataOcorrencia,
  }) async {
    final result = await _client.rpc('check_in_member', params: {
      'p_qr_code_id': qrCodeId,
      'p_escala_id': escalaId,
      'p_data_ocorrencia': dataOcorrencia.toIso8601String().split('T').first,
    });
    return result as String;
  }

  /// Confirma presenca num EVENTO do calendario (nao exige inscricao
  /// previa). Retorna o nome do membro confirmado.
  Future<String> checkInEvento({
    required String qrCodeId,
    required String eventoId,
    required DateTime dataOcorrencia,
  }) async {
    final result = await _client.rpc('check_in_evento', params: {
      'p_qr_code_id': qrCodeId,
      'p_evento_id': eventoId,
      'p_data_ocorrencia': dataOcorrencia.toIso8601String().split('T').first,
    });
    return result as String;
  }

  /// Busca, pra pessoa DAQUELE QR Code, tudo que e relevante pro
  /// check-in de hoje.
  Future<({String? userId, List<String> escalaIds, List<String> eventoIdsConfirmados})>
      fetchStatusDoDia(String qrCodeId, DateTime data) async {
    final perfil = await _client
        .from('profiles')
        .select('id')
        .eq('qr_code_id', qrCodeId)
        .maybeSingle();

    if (perfil == null) {
      return (userId: null, escalaIds: <String>[], eventoIdsConfirmados: <String>[]);
    }

    final userId = perfil['id'] as String;
    final dataStr = data.toIso8601String().split('T').first;

    final inscricoes = await _client
        .from('inscricoes')
        .select('escala_id')
        .eq('user_id', userId)
        .eq('data_ocorrencia', dataStr)
        .eq('status', 'inscrito');

    final presencas = await _client
        .from('presencas_eventos')
        .select('evento_id')
        .eq('user_id', userId)
        .eq('data_ocorrencia', dataStr);

    return (
      userId: userId,
      escalaIds: (inscricoes as List)
          .map((e) => (e as Map<String, dynamic>)['escala_id'] as String)
          .toList(),
      eventoIdsConfirmados: (presencas as List)
          .map((e) => (e as Map<String, dynamic>)['evento_id'] as String)
          .toList(),
    );
  }

  /// Busca membros pelo nome -- usado como alternativa quando a camera
  /// nao consegue ler o QR Code (tela riscada, sujeira na lente, etc).
  /// Devolve nome + o proprio qr_code_id, que alimenta o mesmo fluxo de
  /// check-in usado depois de escanear normalmente.
  Future<List<({String nome, String qrCodeId})>> buscarPorNome(String query) async {
    if (query.trim().length < 2) return [];

    final data = await _client
        .from('profiles')
        .select('nome, qr_code_id')
        .ilike('nome', '%${query.trim()}%')
        .order('nome')
        .limit(20);

    return (data as List)
        .map((e) => (
              nome: (e as Map<String, dynamic>)['nome'] as String,
              qrCodeId: e['qr_code_id'] as String,
            ))
        .toList();
  }
}
