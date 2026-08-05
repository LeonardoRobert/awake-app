import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_youtube_model.dart';

/// Busca os videos mais recentes do canal usando a API oficial do
/// YouTube (Data API v3) -- diferente do feed RSS, essa API e feita
/// pra ser chamada direto do navegador (envia os cabecalhos de CORS
/// certos), entao funciona tanto no app quanto na versao web/iPhone.
///
/// A chave e passada na hora de compilar (--dart-define=YOUTUBE_API_KEY=...),
/// nunca fica escrita direto no codigo.
class YoutubeService {
  static const _apiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const _channelId = 'UCJjMlNpqp4JmorV6bCLprXg';

  Future<List<VideoYoutube>> buscarVideosRecentes({int limite = 5}) async {
    if (_apiKey.isEmpty) {
      throw Exception('Chave da API do YouTube não configurada.');
    }

    final uri = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?key=$_apiKey'
      '&channelId=$_channelId'
      '&part=snippet'
      '&order=date'
      '&type=video'
      '&maxResults=$limite',
    );

    final resposta = await http.get(uri);
    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar os vídeos agora.');
    }

    final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
    final itens = (dados['items'] as List?) ?? [];

    return itens.map((item) {
      final id = item['id']['videoId'] as String;
      final snippet = item['snippet'] as Map<String, dynamic>;
      return VideoYoutube(
        id: id,
        titulo: snippet['title'] as String,
        publicadoEm: DateTime.tryParse(snippet['publishedAt'] as String) ?? DateTime.now(),
      );
    }).toList();
  }
}
