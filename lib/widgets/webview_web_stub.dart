// Substituto "vazio" do webview_flutter, usado SOMENTE quando o app
// compila para web (onde webview_flutter nao existe de verdade).
// Isso nunca roda de fato -- e so aqui pra satisfazer o compilador,
// porque na tela de treinamentos, na versao web, usamos outro caminho
// (abrir o link do YouTube numa aba nova) em vez dessas classes.
import 'package:flutter/widgets.dart';

enum JavaScriptMode { disabled, unrestricted }

class WebViewController {
  WebViewController();

  WebViewController setJavaScriptMode(JavaScriptMode mode) => this;

  Future<void> loadRequest(Uri uri) async {}
}

class WebViewWidget extends StatelessWidget {
  final WebViewController controller;
  const WebViewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
