import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribuicao_model.dart';
import '../services/contribuicao_service.dart';

final contribuicaoServiceProvider = Provider<ContribuicaoService>((ref) => ContribuicaoService());

final minhasContribuicoesProvider =
    FutureProvider.autoDispose<List<ContribuicaoModel>>((ref) {
  return ref.watch(contribuicaoServiceProvider).listarMinhasContribuicoes();
});

/// Total ja pago de um evento ingressado, por id. Usado na tarja da
/// tela de Inicio -- antes essa busca vivia num FutureProvider "cru"
/// (late Future setado uma vez no initState), que nunca refazia a
/// consulta sozinho porque a tela de Inicio fica sempre viva dentro do
/// IndexedStack da navegacao (nunca desmonta pra "renascer" com dado
/// novo). Como provider de verdade, o puxar-pra-atualizar consegue
/// invalidar e forcar a busca de novo.
final totalPagoEventoProvider =
    FutureProvider.family.autoDispose<double, String>((ref, eventoId) {
  return ref.watch(contribuicaoServiceProvider).totalPagoEvento(eventoId);
});
