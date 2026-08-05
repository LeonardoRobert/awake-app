class VideoYoutube {
  final String id;
  final String titulo;
  final DateTime publicadoEm;

  VideoYoutube({required this.id, required this.titulo, required this.publicadoEm});

  String get thumbnailUrl => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  String get url => 'https://www.youtube.com/watch?v=$id';
}
