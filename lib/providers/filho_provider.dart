import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filho_model.dart';
import '../services/filho_service.dart';

final filhoServiceProvider = Provider<FilhoService>((ref) => FilhoService());

final meusFilhosProvider = FutureProvider.autoDispose<List<FilhoModel>>((ref) {
  return ref.watch(filhoServiceProvider).listarMeusFilhos();
});
