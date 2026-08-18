import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/outdoor_model.dart';

/// Slideshow de outdoors (banners) que gira sozinho, devagar -- mostrado
/// no topo da tela de Inicio. Se o outdoor tiver link, tocar nele abre
/// o link (ex: WhatsApp de um lider).
class OutdoorSlideshow extends StatefulWidget {
  final List<OutdoorModel> outdoors;
  const OutdoorSlideshow({super.key, required this.outdoors});

  @override
  State<OutdoorSlideshow> createState() => _OutdoorSlideshowState();
}

class _OutdoorSlideshowState extends State<OutdoorSlideshow> {
  final _controller = PageController();
  Timer? _timer;
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    _reiniciarTimerSeNecessario();
  }

  @override
  void didUpdateWidget(covariant OutdoorSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se a lista de outdoors mudar de tamanho depois do primeiro build
    // (ex: o provider ainda estava carregando quando o widget nasceu),
    // reconfigura o timer -- initState() so roda uma vez, entao sem
    // isso o slideshow podia nascer "mudo" pra sempre.
    if (oldWidget.outdoors.length != widget.outdoors.length) {
      _reiniciarTimerSeNecessario();
    }
  }

  void _reiniciarTimerSeNecessario() {
    _timer?.cancel();
    _timer = widget.outdoors.length > 1
        ? Timer.periodic(const Duration(seconds: 5), (_) => _avancar())
        : null;
  }

  void _avancar() {
    if (!mounted || !_controller.hasClients) return;
    final proxima = (_paginaAtual + 1) % widget.outdoors.length;
    _controller.animateToPage(
      proxima,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _abrirLink(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.outdoors.isEmpty) return const SizedBox.shrink();

    final corDestaque = Theme.of(context).colorScheme.secondary;

    return Container(
      // Moldura na cor de destaque -- mesmo esquema da tarja de evento
      // ingressado (borda + fundo suave) -- pra deixar claro que isso
      // aqui e um banner/aviso, e nao a foto de capa de um evento.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: corDestaque, width: 2),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 2,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.outdoors.length,
                onPageChanged: (i) => setState(() => _paginaAtual = i),
                itemBuilder: (context, index) {
                  final outdoor = widget.outdoors[index];
                  final clicavel = outdoor.linkUrl != null &&
                      outdoor.linkUrl!.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: clicavel
                        ? () => _abrirLink(outdoor.linkUrl!.trim())
                        : null,
                    child: Image.network(
                      outdoor.imagemUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  );
                },
              ),
              if (widget.outdoors.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.outdoors.length, (i) {
                      final ativo = i == _paginaAtual;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: ativo ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(ativo ? 0.9 : 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
