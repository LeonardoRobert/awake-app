package com.example.awake_app

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CANAL_VOLUME = "awake_app/volume_buttons"
    private var interceptandoVolume = false
    private var canalVolume: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // So' usado pela tela de Contador de evento -- enquanto ativo,
        // os botoes fisicos de volume viram +1/-1 em vez de mexer no
        // volume do aparelho (ver lib/services/volume_button_service.dart).
        canalVolume = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_VOLUME)
        canalVolume?.setMethodCallHandler { call, result ->
            when (call.method) {
                "ativar" -> {
                    interceptandoVolume = true
                    result.success(null)
                }
                "desativar" -> {
                    interceptandoVolume = false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (interceptandoVolume &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            // Consome tanto ACTION_DOWN quanto ACTION_UP -- so' dispara
            // o callback pro Flutter uma vez (no DOWN), mas precisa
            // engolir o UP tambem, senao alguns aparelhos ainda mostram
            // o HUD de volume por baixo.
            if (event.action == KeyEvent.ACTION_DOWN) {
                val metodo = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) "volumeUp" else "volumeDown"
                canalVolume?.invokeMethod(metodo, null)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
