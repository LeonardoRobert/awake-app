import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_youtube_model.dart';

/// Busca os videos mais recentes do canal usando a "playlist de
/// uploads" do canal -- diferente da busca por palavra-chave (que
/// usavamos antes), essa playlist e SEMPRE 100% cronologica (mais
/// recente primeiro), sem excecoes, e ainda gasta bem menos da cota
/// gratuita da API.
///
/// Toda playlist de uploads tem o mesmo ID do canal, so trocando o
/// prefixo "UC" por "UU" -- e uma convencao fixa do YouTube.
/// Canal: UCJjMlNpqp4JmorV6bCLprXg -> playlist: UUJjMlNpqp4JmorV6bCLprXg
class YoutubeService {
  static const _apiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const _playlistUploads = 'UUJjMlNpqp4JmorV6bCLprXg';

  Future<List<VideoYoutube>> buscarVideosRecentes({int limite = 5}) async {
    if (_apiKey.isEmpty) {
      throw Exception('Chave da API do YouTube não configurada.');
    }

    final uri = Uri.parse(
      'https://www.googleapis.com/youtube/v3/playlistItems'
      '?key=$_apiKey'
      '&playlistId=$_playlistUploads'
      '&part=snippet'
      '&maxResults=$limite',
    );

    final resposta = await http.get(uri);
    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar os vídeos agora.');
    }

    final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
    final itens = (dados['items'] as List?) ?? [];

    return itens.map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final id = snippet['resourceId']['videoId'] as String;
      return VideoYoutube(
        id: id,
        titulo: snippet['title'] as String,
        publicadoEm: DateTime.tryParse(snippet['publishedAt'] as String) ?? DateTime.now(),
      );
    }).toList();
  }
}
