import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_area_model.dart';
import '../models/shift_model.dart';
import '../models/signup_model.dart';
import '../services/shift_service.dart';

final shiftServiceProvider = Provider<ShiftService>((ref) => ShiftService());

final serviceAreasProvider = FutureProvider.autoDispose<List<ServiceAreaModel>>((ref) {
  return ref.watch(shiftServiceProvider).listServiceAreas();
});

/// Gera as ocorrencias de todas as escalas (recorrentes ou nao) para os
/// proximos ~60 dias, ja com a contagem de vagas preenchidas.
final upcomingShiftOccurrencesProvider =
    FutureProvider.autoDispose<List<ShiftOccurrence>>((ref) async {
  final service = ref.watch(shiftServiceProvider);
  final templates = await service.listShiftTemplates();
  final counts = await service.fetchInscritosCounts();

  final now = DateTime.now();
  final rangeStart = DateTime(now.year, now.month, now.day);
  final rangeEnd = rangeStart.add(const Duration(days: 60));

  final occurrences = <ShiftOccurrence>[];
  for (final shift in templates) {
    for (final data in shift.occurrencesBetween(rangeStart, rangeEnd)) {
      final key =
          '${shift.id}_${data.toIso8601String().split('T').first}';
      occurrences.add(ShiftOccurrence(
        shift: shift,
        data: data,
        inscritosCount: counts[key] ?? 0,
      ));
    }
  }

  occurrences.sort((a, b) => a.inicioCompleto.compareTo(b.inicioCompleto));
  return occurrences;
});

final mySignupsProvider = FutureProvider.autoDispose<List<SignupModel>>((ref) {
  return ref.watch(shiftServiceProvider).listMySignups();
});

/// Lista de inscritos para uma ocorrencia especifica (uso do lider).
final signupsForOccurrenceProvider = FutureProvider.autoDispose
    .family<List<SignupModel>, ({String escalaId, DateTime data})>((ref, params) {
  return ref
      .watch(shiftServiceProvider)
      .listSignupsForOccurrence(params.escalaId, params.data);
});