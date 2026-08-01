import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/treinamento_model.dart';

class TreinamentoDetailScreen extends StatefulWidget {
  final TreinamentoModel treinamento;
  const TreinamentoDetailScreen({super.key, required this.treinamento});

  @override
  State<TreinamentoDetailScreen> createState() => _TreinamentoDetailScreenState();
}

class _TreinamentoDetailScreenState extends State<TreinamentoDetailScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final id = widget.treinamento.youtubeId;
    final urlParaAbrir =
        id != null ? 'https://www.youtube.com/embed/$id' : widget.treinamento.urlVideo;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(urlParaAbrir));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.treinamento.titulo)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: _controller),
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