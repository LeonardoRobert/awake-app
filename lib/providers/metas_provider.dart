import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meta_mensal_model.dart';
import '../services/metas_service.dart';

final metasServiceProvider = Provider<MetasService>((ref) => MetasService());

final metaDoMesProvider = FutureProvider.autoDispose<MetaMensal>((ref) {
  return ref.watch(metasServiceProvider).fetchMetaDoMes();
});

final streakAtualProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(metasServiceProvider).fetchStreakAtual();
});

final rankingDoMesProvider = FutureProvider.autoDispose<List<RankingEntry>>((ref) {
  return ref.watch(metasServiceProvider).fetchRankingDoMes();
});

final rankingPorCategoriaProvider = FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.watch(metasServiceProvider).fetchRankingPorCategoria();
});