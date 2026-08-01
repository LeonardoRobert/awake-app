import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_area_model.dart';
import '../models/shift_model.dart';
import '../models/signup_model.dart';
import '../services/shift_service.dart';

final shiftServiceProvider = Provider<ShiftService>((ref) => ShiftService());

final serviceAreasProvider = FutureProvider.autoDispose<List<ServiceAreaModel>>((ref) {
  return ref.watch(shiftServiceProvider).listServiceAreas();
});

final upcomingShiftsProvider = FutureProvider.autoDispose<List<ShiftModel>>((ref) {
  return ref.watch(shiftServiceProvider).listUpcomingShifts();
});

final mySignupsProvider = FutureProvider.autoDispose<List<SignupModel>>((ref) {
  return ref.watch(shiftServiceProvider).listMySignups();
});

/// Lista de inscritos para uma escala especifica (uso do lider).
final signupsForShiftProvider =
    FutureProvider.autoDispose.family<List<SignupModel>, String>((ref, escalaId) {
  return ref.watch(shiftServiceProvider).listSignupsForShift(escalaId);
});
