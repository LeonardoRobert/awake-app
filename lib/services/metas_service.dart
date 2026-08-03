import '../models/meta_mensal_model.dart';
import 'supabase_service.dart';

class MetasService {
  final _client = SupabaseService.client;

  String _d(DateTime d) => d.toIso8601String().split('T').first;

  /// Busca meta do mes atual + sequencia de trofeus numa unica chamada
  /// ao banco (antes eram ate 24 consultas separadas).
  Future<({MetaMensal meta, int streak})> fetchResumo() async {
    final data = await _client.rpc('metas_resumo');
    final row = (data as List).first as Map<String, dynamic>;

    final meta = MetaMensal(
      mes: DateTime.now(),
      ebd: row['mes_ebd'] as int,
      gc: row['mes_gc'] as int,
      comunhao: row['mes_comunhao'] as int,
      escala: row['mes_escala'] as int,
    );

    return (meta: meta, streak: row['streak'] as int);
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
