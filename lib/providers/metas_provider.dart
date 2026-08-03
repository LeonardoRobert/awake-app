import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meta_mensal_model.dart';
import '../services/metas_service.dart';

final metasServiceProvider = Provider<MetasService>((ref) => MetasService());

/// Meta do mes + sequencia de trofeus, buscados juntos numa unica
/// chamada ao banco.
final metasResumoProvider =
    FutureProvider.autoDispose<({MetaMensal meta, int streak})>((ref) {
  return ref.watch(metasServiceProvider).fetchResumo();
});

final rankingDoMesProvider = FutureProvider.autoDispose<List<RankingEntry>>((ref) {
  return ref.watch(metasServiceProvider).fetchRankingDoMes();
});

final rankingPorCategoriaProvider = FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.watch(metasServiceProvider).fetchRankingPorCategoria();
});
