import 'supabase_service.dart';

class CheckinService {
  final _client = SupabaseService.client;

  /// Chama a funcao no banco que valida o QR Code escaneado do membro
  /// e registra o check-in para a escala informada.
  /// (ver supabase/schema.sql: check_in_member)
  ///
  /// Retorna o nome do membro confirmado, para exibir feedback na tela.
  Future<String> checkInByQrCode({
    required String qrCodeId,
    required String escalaId,
  }) async {
    final result = await _client.rpc('check_in_member', params: {
      'p_qr_code_id': qrCodeId,
      'p_escala_id': escalaId,
    });
    return result as String;
  }
}
