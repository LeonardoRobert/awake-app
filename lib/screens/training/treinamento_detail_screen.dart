import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/treinamento_model.dart';

// webview_flutter so funciona em Android/iOS/macOS nativos -- na versao
// web do app, nao existe "webview dentro do navegador" (voce ja esta no
// navegador). Por isso o import e condicional: no mobile usamos o pacote
// de verdade; na web, usamos um "stub" (classe vazia so pra compilar) e
// abrimos o video numa aba nova do navegador em vez de embutir.
import 'package:webview_flutter/webview_flutter.dart'
    if (dart.library.html) '../../widgets/webview_web_stub.dart';

class TreinamentoDetailScreen extends StatefulWidget {
  final TreinamentoModel treinamento;
  const TreinamentoDetailScreen({super.key, required this.treinamento});

  @override
  State<TreinamentoDetailScreen> createState() => _TreinamentoDetailScreenState();
}

class _TreinamentoDetailScreenState extends State<TreinamentoDetailScreen> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      final id = widget.treinamento.youtubeId;
      final urlParaAbrir =
          id != null ? 'https://www.youtube.com/embed/$id' : widget.treinamento.urlVideo;

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(urlParaAbrir));
    }
  }

  Future<void> _abrirNoNavegador() async {
    final uri = Uri.parse(widget.treinamento.urlVideo);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.treinamento.titulo)),
      body: ListView(
        children: [
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.play_circle_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No navegador, o vídeo abre numa aba do YouTube.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _abrirNoNavegador,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Assistir no YouTube'),
                  ),
                ],
              ),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: WebViewWidget(controller: _controller!),
            ),
          if (widget.treinamento.descricao != null &&
              widget.treinamento.descricao!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.treinamento.descricao!),
            ),
        ],
      ),
    );
  }
}
