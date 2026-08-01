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
}