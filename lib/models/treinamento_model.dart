class TreinamentoModel {
  final String id;
  final String titulo;
  final String? descricao;
  final String urlVideo;
  final DateTime criadoEm;

  TreinamentoModel({
    required this.id,
    required this.titulo,
    this.descricao,
    required this.urlVideo,
    required this.criadoEm,
  });

  factory TreinamentoModel.fromMap(Map<String, dynamic> map) {
    return TreinamentoModel(
      id: map['id'] as String,
      titulo: map['titulo'] as String,
      descricao: map['descricao'] as String?,
      urlVideo: map['url_video'] as String,
      criadoEm: DateTime.parse(map['criado_em'] as String),
    );
  }

  /// Extrai o ID do video a partir de varios formatos de link do YouTube
  /// (youtube.com/watch?v=..., youtu.be/..., youtube.com/embed/...).
  String? get youtubeId {
    final uri = Uri.tryParse(urlVideo);
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    if (uri.pathSegments.contains('embed')) {
      final idx = uri.pathSegments.indexOf('embed');
      if (idx + 1 < uri.pathSegments.length) return uri.pathSegments[idx + 1];
    }
    return null;
  }
}
