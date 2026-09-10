import 'supabase_service.dart';

/// Check-in em massa pros lideres dos ministerios que NAO sao Awake --
/// 100% separado do sistema de Escala de Servico e do contador geral
/// (contagem_manual_eventos/presencas_eventos), que continuam intocados.
/// Ver supabase/sql/2026_checkin_ministerio.sql.
class MinisterioPresencaService {
  final _client = SupabaseService.client;

  /// Catalogo fixo de tipos de ocasiao (Ensaio, Reunião, etc) daquele
  /// ministerio -- o lider escolhe um pra HOJE antes de colar a lista
  /// de nomes.
  Future<List<String>> listarCatalogo(String ministerio) async {
    final data = await _client
        .from('ocasioes_ministerio_catalogo')
        .select('nome')
        .eq('ministerio', ministerio)
        .order('ordem');
    return (data as List).map((e) => (e as Map<String, dynamic>)['nome'] as String).toList();
  }

  /// Cria (ou reaproveita) a ocasiao de HOJE pra esse ministerio+tipo e
  /// registra presenca de cada pessoa em [profileIds] -- so' conta
  /// quem realmente e' membro do ministerio (a funcao confere de novo
  /// no banco, mesmo que a busca do app ja filtre isso).
  Future<void> checkinEmMassa({
    required String ministerio,
    required String tipoOcasiao,
    required List<String> profileIds,
  }) async {
    await _client.rpc('checkin_em_massa_ministerio', params: {
      'p_ministerio': ministerio,
      'p_tipo_ocasiao': tipoOcasiao,
      'p_profile_ids': profileIds,
    });
  }
}
