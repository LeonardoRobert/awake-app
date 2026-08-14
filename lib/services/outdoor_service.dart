import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/outdoor_model.dart';
import 'supabase_service.dart';

class OutdoorService {
  final _client = SupabaseService.client;

  Future<List<OutdoorModel>> listar() async {
    final data = await _client.from('outdoors').select().order('criado_em', ascending: true);
    return (data as List).map((e) => OutdoorModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> criar(OutdoorModel outdoor) async {
    await _client.from('outdoors').insert({
      ...outdoor.toInsertMap(),
      'criado_por': _client.auth.currentUser?.id,
    });
  }

  Future<void> atualizar(String id, OutdoorModel outdoor) async {
    await _client.from('outdoors').update(outdoor.toInsertMap()).eq('id', id);
  }

  Future<void> apagar(String id) async {
    await _client.from('outdoors').delete().eq('id', id);
  }

  /// Envia a imagem do outdoor pro Storage e devolve a URL publica dela.
  Future<String> uploadImagem(Uint8List bytes, String nomeArquivo) async {
    final extensao = nomeArquivo.contains('.') ? nomeArquivo.split('.').last : 'jpg';
    final caminho = 'outdoors/${DateTime.now().millisecondsSinceEpoch}.$extensao';

    await _client.storage.from('outdoors').uploadBinary(
          caminho,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('outdoors').getPublicUrl(caminho);
  }
}
