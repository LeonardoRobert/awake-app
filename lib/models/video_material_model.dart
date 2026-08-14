/// Material (PDF de aula/mensagem/esboço) atrelado a um vídeo do
/// YouTube -- no máximo 1 por vídeo. O vídeo em si não é salvo no
/// banco (vem sempre ao vivo da API do YouTube, via YoutubeService);
/// aqui só guardamos o vínculo videoYoutubeId -> materialUrl.
class VideoMaterial {
  final String id;
  final String videoYoutubeId;
  final String materialUrl;
  final String? nomeArquivo;

  VideoMaterial({
    required this.id,
    required this.videoYoutubeId,
    required this.materialUrl,
    this.nomeArquivo,
  });

  factory VideoMaterial.fromMap(Map<String, dynamic> map) {
    return VideoMaterial(
      id: map['id'] as String,
      videoYoutubeId: map['video_youtube_id'] as String,
      materialUrl: map['material_url'] as String,
      nomeArquivo: map['nome_arquivo'] as String?,
    );
  }
}
