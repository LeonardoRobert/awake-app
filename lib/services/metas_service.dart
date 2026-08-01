import '../models/meta_mensal_model.dart';
import 'supabase_service.dart';

class MetasService {
  final _client = SupabaseService.client;

  String _d(DateTime d) => d.toIso8601String().split('T').first;

  /// Conta check-ins por categoria (ebd/gc/comunhao/laje/outro em eventos,
  /// e escala em inscricoes com check-in feito) para um usuario, num
  /// intervalo de datas.
  Future<Map<String, int>> _contarNoPeriodo(
    String userId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final presencas = await _client
        .from('presencas_eventos')
        .select('eventos(tipo)')
        .eq('user_id', userId)
        .gte('data_ocorrencia', _d(inicio))
        .lte('data_ocorrencia', _d(fim));

    final counts = <String, int>{'ebd': 0, 'gc': 0, 'comunhao': 0, 'laje': 0, 'outro': 0};
    for (final row in (presencas as List)) {
      final map = row as Map<String, dynamic>;
      final tipo = (map['eventos'] as Map<String, dynamic>?)?['tipo'] as String? ?? 'outro';
      counts[tipo] = (counts[tipo] ?? 0) + 1;
    }

    final escalas = await _client
        .from('inscricoes')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'check_in_feito')
        .gte('data_ocorrencia', _d(inicio))
        .lte('data_ocorrencia', _d(fim));
    counts['escala'] = (escalas as List).length;

    return counts;
  }

  Future<MetaMensal> fetchMetaDoMes([DateTime? referencia]) async {
    final userId = _client.auth.currentUser!.id;
    final ref = referencia ?? DateTime.now();
    final inicio = DateTime(ref.year, ref.month, 1);
    final fim = DateTime(ref.year, ref.month + 1, 0);
    final counts = await _contarNoPeriodo(userId, inicio, fim);

    return MetaMensal(
      mes: ref,
      ebd: counts['ebd'] ?? 0,
      gc: counts['gc'] ?? 0,
      comunhao: counts['comunhao'] ?? 0,
      escala: counts['escala'] ?? 0,
    );
  }

  /// Quantos meses CHEIOS e consecutivos (contando pra tras a partir do
  /// mes passado -- o mes atual ainda esta em andamento, entao nao entra
  /// nessa conta) a pessoa cumpriu a meta completa.
  Future<int> fetchStreakAtual() async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now();
    var streak = 0;

    for (var i = 1; i <= 12; i++) {
      final ref = DateTime(now.year, now.month - i, 1);
      final inicio = DateTime(ref.year, ref.month, 1);
      final fim = DateTime(ref.year, ref.month + 1, 0);
      final counts = await _contarNoPeriodo(userId, inicio, fim);

      final cumpriu = (counts['ebd'] ?? 0) >= MetasConfig.ebd &&
          (counts['gc'] ?? 0) >= MetasConfig.gc &&
          (counts['comunhao'] ?? 0) >= MetasConfig.comunhao &&
          (counts['escala'] ?? 0) >= MetasConfig.escala;

      if (cumpriu) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Ranking de participacao do mes atual -- uso do lider.
  /// Soma check-ins em eventos + check-ins em escalas, por pessoa.
  Future<List<RankingEntry>> fetchRankingDoMes() async {
    final now = DateTime.now();
    final inicio = _d(DateTime(now.year, now.month, 1));
    final fim = _d(DateTime(now.year, now.month + 1, 0));

    // Importante: presencas_eventos tem DUAS ligacoes com profiles
    // (user_id = quem participou, feito_por = quem fez o check-in).
    // Por isso precisamos dizer explicitamente qual delas usar aqui --
    // sem isso o Supabase nao sabe escolher e da erro de ambiguidade.
    final presencas = await _client
        .from('presencas_eventos')
        .select('user_id, profiles!presencas_eventos_user_id_fkey(nome, categoria)')
        .gte('data_ocorrencia', inicio)
        .lte('data_ocorrencia', fim);

    final escalas = await _client
        .from('inscricoes')
        .select('user_id, profiles(nome, categoria)')
        .eq('status', 'check_in_feito')
        .gte('data_ocorrencia', inicio)
        .lte('data_ocorrencia', fim);

    final counts = <String, int>{};
    final nomes = <String, String>{};
    final categorias = <String, String?>{};

    void processar(List rows) {
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final userId = map['user_id'] as String;
        final profile = map['profiles'] as Map<String, dynamic>?;
        nomes[userId] = profile?['nome'] as String? ?? 'Membro';
        categorias[userId] = profile?['categoria'] as String?;
        counts[userId] = (counts[userId] ?? 0) + 1;
      }
    }

    processar(presencas as List);
    processar(escalas as List);

    final entries = counts.entries
        .map((e) => RankingEntry(
              nome: nomes[e.key] ?? 'Membro',
              categoria: categorias[e.key],
              total: e.value,
            ))
        .toList();

    entries.sort((a, b) => b.total.compareTo(a.total));
    return entries;
  }

  /// Mesmo ranking, mas somado por categoria (Genesis/Next/One).
  Future<Map<String, int>> fetchRankingPorCategoria() async {
    final entries = await fetchRankingDoMes();
    final porCategoria = <String, int>{};
    for (final e in entries) {
      final cat = e.categoria ?? 'sem_categoria';
      porCategoria[cat] = (porCategoria[cat] ?? 0) + e.total;
    }
    return porCategoria;
  }
}