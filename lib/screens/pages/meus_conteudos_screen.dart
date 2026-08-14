import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/erro_amigavel.dart';
import '../../models/video_youtube_model.dart';
import '../../services/video_material_service.dart';
import '../../services/youtube_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela do Admin pra anexar/substituir/remover o PDF (aula, mensagem,
/// esboço...) atrelado a cada vídeo do YouTube -- o vídeo que ganha
/// material passa a mostrar "Visualizar material" em Nossos Conteúdos.
class MeusConteudosScreen extends StatefulWidget {
  const MeusConteudosScreen({super.key});

  @override
  State<MeusConteudosScreen> createState() => _MeusConteudosScreenState();
}

class _MeusConteudosScreenState extends State<MeusConteudosScreen> {
  late Future<(List<VideoYoutube>, Map<String, String>)> _futuro;
  final Set<String> _processando = {};

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<(List<VideoYoutube>, Map<String, String>)> _carregar() async {
    final videos = await YoutubeService().buscarVideosRecentes(limite: 10);
    final materiais = await VideoMaterialService().buscarPorVideoIds(videos.map((v) => v.id).toList());
    return (videos, materiais);
  }

  Future<void> _anexarMaterial(VideoYoutube video) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final arquivo = resultado?.files.single;
    final bytes = arquivo?.bytes;
    if (arquivo == null || bytes == null) return;

    setState(() => _processando.add(video.id));
    try {
      await VideoMaterialService().anexar(video.id, bytes, arquivo.name);
      setState(() => _futuro = _carregar());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar o material: ${mensagemDeErroAmigavel(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _processando.remove(video.id));
    }
  }

  Future<void> _removerMaterial(VideoYoutube video) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover material'),
        content: Text('Remover o material anexado a "${video.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    setState(() => _processando.add(video.id));
    try {
      await VideoMaterialService().remover(video.id);
      setState(() => _futuro = _carregar());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível remover o material: ${mensagemDeErroAmigavel(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _processando.remove(video.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Meus Conteúdos', showQrButton: false),
      body: FutureBuilder<(List<VideoYoutube>, Map<String, String>)>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Erro ao carregar vídeos: ${snapshot.error}'));
          }

          final (videos, materiais) = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              final materialUrl = materiais[video.id];
              final processando = _processando.contains(video.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 100,
                              height: 60,
                              child: Image.network(video.thumbnailUrl, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video.titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat("dd/MM/yyyy", 'pt_BR').format(video.publicadoEm),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (processando)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (materialUrl == null)
                        OutlinedButton.icon(
                          onPressed: () => _anexarMaterial(video),
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Anexar material'),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _anexarMaterial(video),
                              icon: const Icon(Icons.sync, size: 18),
                              label: const Text('Substituir material'),
                            ),
                            TextButton.icon(
                              onPressed: () => _removerMaterial(video),
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              label: const Text('Remover', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
