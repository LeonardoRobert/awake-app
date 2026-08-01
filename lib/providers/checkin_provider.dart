import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/checkin_service.dart';

final checkinServiceProvider = Provider<CheckinService>((ref) => CheckinService());
