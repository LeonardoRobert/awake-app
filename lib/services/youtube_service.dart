import 'package:http/http.dart' as http;
import '../models/video_youtube_model.dart';

/// Busca os videos mais recentes do canal usando o feed RSS publico do
/// YouTube -- nao precisa de chave de API nem de nenhuma conta paga.
/// Canal: Shallom Online (https://youtube.com/@shallomonline)
class YoutubeService {
  static const _channelId = 'UCJjMlNpqp4JmorV6bCLprXg';
  static const _feedUrl =
      'https://www.youtube.com/feeds/videos.xml?channel_id=$_channelId';

  Future<List<VideoYoutube>> buscarVideosRecentes({int limite = 5}) async {
    final resposta = await http.get(Uri.parse(_feedUrl));
    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar os vídeos agora.');
    }

    final corpo = resposta.body;
    final entradas = RegExp(r'<entry>(.*?)</entry>', dotAll: true).allMatches(corpo);

    final videos = <VideoYoutube>[];
    for (final entrada in entradas) {
      final bloco = entrada.group(1)!;
      final idMatch = RegExp(r'<yt:videoId>(.*?)</yt:videoId>').firstMatch(bloco);
      final tituloMatch = RegExp(r'<title>(.*?)</title>').firstMatch(bloco);
      final publicadoMatch = RegExp(r'<published>(.*?)</published>').firstMatch(bloco);
      if (idMatch == null || tituloMatch == null) continue;

      videos.add(VideoYoutube(
        id: idMatch.group(1)!,
        titulo: _decodificarHtml(tituloMatch.group(1)!),
        publicadoEm: publicadoMatch != null
            ? DateTime.tryParse(publicadoMatch.group(1)!) ?? DateTime.now()
            : DateTime.now(),
      ));

      if (videos.length >= limite) break;
    }

    return videos;
  }

  String _decodificarHtml(String texto) {
    return texto
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
