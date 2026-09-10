import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grupo_casais_model.dart';
import '../services/grupo_casais_service.dart';

final gruposCasaisAtivosProvider = FutureProvider<List<GrupoCasaisModel>>((ref) {
  return GrupoCasaisService().listarAtivos();
});
