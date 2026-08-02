import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../core/env.dart';

/// Encapsula a integracao com o OneSignal para push notifications.
///
/// Push e usado para: novos eventos no calendario, lembrete de escala
/// e (futuramente) conquista de trofeus.
///
/// NOTA WEB: o SDK do OneSignal usado aqui e voltado para Android/iOS
/// nativos. Na versao web do app (PWA), ele e simplesmente desligado por
/// enquanto -- push notification no navegador (Web Push) e uma
/// configuracao a parte, que podemos implementar depois se for
/// necessario.
class NotificationService {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    OneSignal.initialize(Env.oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);
  }

  static Future<void> loginUser(String supabaseUserId) async {
    if (kIsWeb) return;
    await OneSignal.login(supabaseUserId);
  }

  static Future<void> logoutUser() async {
    if (kIsWeb) return;
    await OneSignal.logout();
  }
}
