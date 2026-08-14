import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/outdoor_model.dart';
import '../services/outdoor_service.dart';

final outdoorServiceProvider = Provider<OutdoorService>((ref) => OutdoorService());

/// Todos os outdoors que a RLS libera pra esse perfil (ja filtrados por
/// escopo/ministerio e ativo=true no banco) -- usado tanto pela tela de
/// Inicio (que ainda filtra pela janela de datas) quanto, indiretamente,
/// como base pra tela de gestao do admin (que ve tudo, inclusive
/// pausado).
final outdoorsProvider = FutureProvider.autoDispose<List<OutdoorModel>>((ref) {
  return ref.watch(outdoorServiceProvider).listar();
});

/// So os outdoors visiveis HOJE (checa a janela de datas no app, ja que
/// "hoje" muda todo dia) -- no maximo 5, mais antigos primeiro.
final outdoorsAtivosProvider = FutureProvider.autoDispose<List<OutdoorModel>>((ref) async {
  final todos = await ref.watch(outdoorsProvider.future);
  final hoje = DateTime.now();
  return todos.where((o) => o.estaVisivelEm(hoje)).take(5).toList();
});
