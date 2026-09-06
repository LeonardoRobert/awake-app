import 'package:flutter/services.dart';

/// Faz os botões físicos de volume do celular funcionarem como +1/-1
/// (usado na tela de Contador de evento), em vez de mexer no volume do
/// aparelho. Só funciona no Android -- o iOS não dá acesso público pra
/// interceptar os botões de volume fora do contexto de câmera, então lá
/// eles continuam mexendo no volume normalmente (sem workaround seguro
/// pra passar na revisão da App Store). Chame [desativar] sempre que a
/// tela que usou [ativar] sair de cena (ex: no dispose).
class VolumeButtonService {
  static const _canal = MethodChannel('awake_app/volume_buttons');

  static Future<void> ativar({
    required void Function() aoApertarMais,
    required void Function() aoApertarMenos,
  }) async {
    _canal.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') aoApertarMais();
      if (call.method == 'volumeDown') aoApertarMenos();
    });
    try {
      await _canal.invokeMethod('ativar');
    } catch (_) {
      // iOS (sem handler nativo) ou qualquer outro erro de plataforma --
      // fica silencioso, os botões só não funcionam como contador, sem
      // quebrar a tela.
    }
  }

  static Future<void> desativar() async {
    _canal.setMethodCallHandler(null);
    try {
      await _canal.invokeMethod('desativar');
    } catch (_) {}
  }
}
