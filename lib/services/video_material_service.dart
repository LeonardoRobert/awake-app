import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/video_material_model.dart';
import 'supabase_service.dart';

class VideoMaterialService {
  final _client = SupabaseService.client;

  /// Busca os materiais ja anexados pra uma lista de IDs de video,
  /// devolvendo um mapa videoYoutubeId -> materialUrl (so entram os
  /// videos que TEM material).
  Future<Map<String, String>> buscarPorVideoIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final data = await _client
        .from('video_materiais')
        .select()
        .inFilter('video_youtube_id', ids);

    final materiais = (data as List)
        .map((e) => VideoMaterial.fromMap(e as Map<String, dynamic>))
        .toList();

    return {for (final m in materiais) m.videoYoutubeId: m.materialUrl};
  }

  /// Envia o PDF pro Storage (sempre no mesmo caminho por video, pra
  /// "substituir material" simplesmente sobrescrever o arquivo antigo)
  /// e grava/atualiza o vinculo na tabela.
  Future<void> anexar(String videoYoutubeId, Uint8List bytes, String nomeArquivo) async {
    final caminho = 'materiais/$videoYoutubeId.pdf';

    await _client.storage.from('materiais-conteudo').uploadBinary(
          caminho,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _client.storage.from('materiais-conteudo').getPublicUrl(caminho);

    await _client.from('video_materiais').upsert(
      {
        'video_youtube_id': videoYoutubeId,
        'material_url': url,
        'nome_arquivo': nomeArquivo,
        'criado_por': _client.auth.currentUser?.id,
      },
      onConflict: 'video_youtube_id',
    );
  }

  Future<void> remover(String videoYoutubeId) async {
    await _client.from('video_materiais').delete().eq('video_youtube_id', videoYoutubeId);
    await _client.storage.from('materiais-conteudo').remove(['materiais/$videoYoutubeId.pdf']);
  }
}
