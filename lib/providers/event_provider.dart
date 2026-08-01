import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

final eventServiceProvider = Provider<EventService>((ref) => EventService());

final upcomingEventsProvider = FutureProvider.autoDispose<List<EventModel>>((ref) {
  return ref.watch(eventServiceProvider).listUpcoming();
});
