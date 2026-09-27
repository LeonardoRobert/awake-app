import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/outdoor_model.dart';
import 'supabase_service.dart';

class OutdoorService {
  final _client = SupabaseService.client;

  Future<List<OutdoorModel>> listar() async {
    final data = await _client.from('outdoors').select().order('ordem', ascending: true);
    return (data as List).map((e) => OutdoorModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> criar(OutdoorModel outdoor) async {
    // Novo outdoor sempre entra no FIM da fila (nao usa outdoor.ordem,
    // que e' so o valor padrao do construtor) -- reordenar depois e'
    // manual, ver salvarOrdem().
    final maiorOrdemAtual = await _client
        .from('outdoors')
        .select('ordem')
        .order('ordem', ascending: false)
        .limit(1)
        .maybeSingle();
    final proximaOrdem = ((maiorOrdemAtual?['ordem'] as int?) ?? 0) + 1;

    await _client.from('outdoors').insert({
      ...outdoor.toInsertMap(),
      'criado_por': _client.auth.currentUser?.id,
      'ordem': proximaOrdem,
    });
  }

  Future<void> atualizar(String id, OutdoorModel outdoor) async {
    await _client.from('outdoors').update(outdoor.toInsertMap()).eq('id', id);
  }

  /// Grava a nova ordem de exibicao -- [idsEmOrdem] e' a lista de ids
  /// JA na ordem final desejada (o indice de cada um vira o valor de
  /// "ordem" gravado).
  Future<void> salvarOrdem(List<String> idsEmOrdem) async {
    for (var i = 0; i < idsEmOrdem.length; i++) {
      await _client.from('outdoors').update({'ordem': i}).eq('id', idsEmOrdem[i]);
    }
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
