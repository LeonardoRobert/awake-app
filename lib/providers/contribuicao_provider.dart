import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribuicao_model.dart';
import '../services/contribuicao_service.dart';

final contribuicaoServiceProvider = Provider<ContribuicaoService>((ref) => ContribuicaoService());

final minhasContribuicoesProvider =
    FutureProvider.autoDispose<List<ContribuicaoModel>>((ref) {
  return ref.watch(contribuicaoServiceProvider).listarMinhasContribuicoes();
});
