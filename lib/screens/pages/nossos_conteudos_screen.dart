import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/video_youtube_model.dart';
import '../../services/youtube_service.dart';
import '../../widgets/awake_app_bar.dart';

class NossosConteudosScreen extends StatefulWidget {
  const NossosConteudosScreen({super.key});

  @override
  State<NossosConteudosScreen> createState() => _NossosConteudosScreenState();
}

class _NossosConteudosScreenState extends State<NossosConteudosScreen> {
  late Future<List<VideoYoutube>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = YoutubeService().buscarVideosRecentes(limite: 6);
  }

  Future<void> _abrirVideo(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirCanal() async {
    await launchUrl(
      Uri.parse('https://youtube.com/@shallomonline'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Nossos Conteúdos', showQrButton: false),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _futuro = YoutubeService().buscarVideosRecentes(limite: 6));
          await _futuro;
        },
        child: FutureBuilder<List<VideoYoutube>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Não foi possível carregar os vídeos agora.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _abrirCanal,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir nosso canal no YouTube'),
                    ),
                  ),
                ],
              );
            }

            final videos = snapshot.data!;
            final destaque = videos.first;
            // Filtra pelo ID, nao so pela posicao -- assim, mesmo se a
            // API mandar o mesmo video duas vezes por algum motivo, ele
            // nunca aparece repetido em "Mais videos".
            final outros = videos.where((v) => v.id != destaque.id).take(4).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GestureDetector(
                  onTap: () => _abrirVideo(destaque.url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(destaque.thumbnailUrl, fit: BoxFit.cover),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(destaque.titulo, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  DateFormat("dd/MM/yyyy", 'pt_BR').format(destaque.publicadoEm),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (outros.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Mais vídeos', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...outros.map((video) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 100,
                              height: 60,
                              child: Image.network(video.thumbnailUrl, fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(
                            video.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            DateFormat("dd/MM/yyyy", 'pt_BR').format(video.publicadoEm),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => _abrirVideo(video.url),
                        ),
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}