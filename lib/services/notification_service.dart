import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../core/env.dart';

/// Encapsula a integracao com o OneSignal para push notifications.
///
/// Push e usado para: novos eventos no calendario, lembrete de escala
/// e (futuramente) conquista de trofeus.
class NotificationService {
  static Future<void> initialize() async {
    OneSignal.initialize(Env.oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Associa o usuario logado ao OneSignal, permitindo enviar
  /// notificacoes segmentadas por usuario (external_id = id do Supabase).
  static Future<void> loginUser(String supabaseUserId) async {
    await OneSignal.login(supabaseUserId);
  }

  static Future<void> logoutUser() async {
    await OneSignal.logout();
  }
}
