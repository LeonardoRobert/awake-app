import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/treinamento_model.dart';
import '../services/treinamento_service.dart';

final treinamentoServiceProvider = Provider<TreinamentoService>((ref) => TreinamentoService());

final treinamentosProvider = FutureProvider.autoDispose<List<TreinamentoModel>>((ref) {
  return ref.watch(treinamentoServiceProvider).listAll();
});
