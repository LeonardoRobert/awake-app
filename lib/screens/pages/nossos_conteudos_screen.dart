import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/video_youtube_model.dart';
import '../../services/video_material_service.dart';
import '../../services/youtube_service.dart';
import '../../widgets/awake_app_bar.dart';

class NossosConteudosScreen extends StatefulWidget {
  const NossosConteudosScreen({super.key});

  @override
  State<NossosConteudosScreen> createState() => _NossosConteudosScreenState();
}

class _NossosConteudosScreenState extends State<NossosConteudosScreen> {
  late Future<(List<VideoYoutube>, Map<String, String>)> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  /// Busca os videos e, em seguida, os materiais atrelados a eles --
  /// junto num Future so, pra tela ter um unico estado de loading/erro.
  Future<(List<VideoYoutube>, Map<String, String>)> _carregar() async {
    final videos = await YoutubeService().buscarVideosRecentes(limite: 10);
    final materiais = await VideoMaterialService().buscarPorVideoIds(videos.map((v) => v.id).toList());
    return (videos, materiais);
  }

  Future<void> _abrirVideo(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirMaterial(String url) async {
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
          setState(() => _futuro = _carregar());
          await _futuro;
        },
        child: FutureBuilder<(List<VideoYoutube>, Map<String, String>)>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.$1.isEmpty) {
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

            final (todosVideos, materiais) = snapshot.data!;

            // Ordena e tira duplicatas -- lives geram, as vezes, uma
            // segunda entrada (a "sala" que fica offline depois),
            // com o MESMO titulo do video de verdade mas ID diferente.
            // Por isso filtramos por titulo tambem, nao so por ID.
            final titulosVistos = <String>{};
            final videosUnicos = todosVideos.where((v) {
              final jaVisto = titulosVistos.contains(v.titulo);
              titulosVistos.add(v.titulo);
              return !jaVisto;
            }).toList();

            final destaque = videosUnicos.first;
            final outros = videosUnicos.skip(1).take(9).toList();

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
                if (materiais[destaque.id] != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirMaterial(materiais[destaque.id]!),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Visualizar material'),
                    ),
                  ),
                ],
                if (outros.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Mais vídeos', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...outros.map((video) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            ListTile(
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
                            if (materiais[video.id] != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _abrirMaterial(materiais[video.id]!),
                                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                    label: const Text('Visualizar material'),
                                  ),
                                ),
                              ),
                          ],
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
