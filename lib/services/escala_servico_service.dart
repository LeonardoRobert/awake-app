import '../models/escala_servico_model.dart';
import 'supabase_service.dart';

const ministeriosComEscalaServico = [
  'diaconos',
  'louvor',
  'danca',
  'midia',
  'multimidia',
];

class EscalaServicoService {
  final _client = SupabaseService.client;

  Future<List<FuncaoCatalogo>> listarCatalogo(String ministerio) async {
    final data = await _client
        .from('escala_servico_funcoes_catalogo')
        .select()
        .eq('ministerio', ministerio)
        .order('ordem');
    return (data as List)
        .map((e) => FuncaoCatalogo.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Acha a escala existente pra esse ministerio+evento+data, ou cria
  /// uma nova (ja populando as posicoes do catalogo, se tiver).
  Future<String> buscarOuCriarEscala({
    required String ministerio,
    required String eventoId,
    required DateTime dataOcorrencia,
  }) async {
    final dataStr = dataOcorrencia.toIso8601String().split('T').first;

    final existente = await _client
        .from('escalas_servico')
        .select('id')
        .eq('ministerio', ministerio)
        .eq('evento_id', eventoId)
        .eq('data_ocorrencia', dataStr)
        .maybeSingle();

    if (existente != null) return existente['id'] as String;

    final userId = _client.auth.currentUser!.id;
    final nova = await _client
        .from('escalas_servico')
        .insert({
          'ministerio': ministerio,
          'evento_id': eventoId,
          'data_ocorrencia': dataStr,
          'criado_por': userId,
        })
        .select('id')
        .single();

    final escalaId = nova['id'] as String;

    final catalogo = await listarCatalogo(ministerio);
    for (final item in catalogo) {
      await _client.from('escala_servico_posicoes').insert({
        'escala_id': escalaId,
        'funcao': item.funcao,
        'ordem': item.ordem,
      });
    }

    return escalaId;
  }

  /// Diferente de buscarOuCriarEscala, esse SO LE -- nao cria nada.
  /// Usado pra mostrar "quem esta escalado" pra quem so esta
  /// espiando (nao e o lider editando).
  Future<List<PosicaoEscala>> listarPosicoesSeExistir({
    required String ministerio,
    required String eventoId,
    required DateTime dataOcorrencia,
  }) async {
    final dataStr = dataOcorrencia.toIso8601String().split('T').first;
    final existente = await _client
        .from('escalas_servico')
        .select('id')
        .eq('ministerio', ministerio)
        .eq('evento_id', eventoId)
        .eq('data_ocorrencia', dataStr)
        .maybeSingle();

    if (existente == null) return [];
    return listarPosicoes(existente['id'] as String);
  }

  Future<List<PosicaoEscala>> listarPosicoes(String escalaId) async {
    final data = await _client
        .from('escala_servico_posicoes')
        .select(
          '*, '
          'profiles!escala_servico_posicoes_profile_id_fkey(nome), '
          'profiles2:profiles!escala_servico_posicoes_profile_id_2_fkey(nome)',
        )
        .eq('escala_id', escalaId)
        .order('ordem');
    return (data as List)
        .map((e) => PosicaoEscala.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> definirPessoa(String posicaoId, String? profileId) async {
    await _client
        .from('escala_servico_posicoes')
        .update({'profile_id': profileId}).eq('id', posicaoId);
  }

  /// So usado pelos Diaconos -- define a segunda pessoa do casal
  /// numa posicao.
  Future<void> definirSegundaPessoa(String posicaoId, String? profileId) async {
    await _client
        .from('escala_servico_posicoes')
        .update({'profile_id_2': profileId}).eq('id', posicaoId);
  }

  Future<void> adicionarPosicao({
    required String escalaId,
    required String funcao,
    int ordem = 99,
  }) async {
    await _client.from('escala_servico_posicoes').insert({
      'escala_id': escalaId,
      'funcao': funcao,
      'ordem': ordem,
    });
  }

  /// Igual adicionarPosicao, mas devolve o id da linha criada -- usado
  /// pelo "Colar lista de nomes" (só Dança), que precisa do id na hora
  /// pra já vincular a pessoa em seguida, sem esperar um reload.
  Future<String> adicionarPosicaoRetornandoId({
    required String escalaId,
    required String funcao,
    int ordem = 99,
  }) async {
    final inserida = await _client
        .from('escala_servico_posicoes')
        .insert({
          'escala_id': escalaId,
          'funcao': funcao,
          'ordem': ordem,
        })
        .select('id')
        .single();
    return inserida['id'] as String;
  }

  Future<void> removerPosicao(String posicaoId) async {
    await _client.from('escala_servico_posicoes').delete().eq('id', posicaoId);
  }

  Future<List<PessoaBusca>> buscarPessoasDoMinisterio(
    String ministerio,
    String busca,
  ) async {
    final data = await _client.rpc('buscar_pessoas_ministerio', params: {
      'p_ministerio': ministerio,
      'p_busca': busca,
    });
    return (data as List)
        .map((e) => PessoaBusca(
              id: (e as Map<String, dynamic>)['id'] as String,
              nome: e['nome'] as String,
            ))
        .toList();
  }

  /// Busca todas as posicoes em que EU estou escalado dentro de um
  /// periodo -- usado pra mostrar a "tarja" na tela de Inicio.
  Future<List<MinhaEscalaResumo>> buscarMinhaEscala(
    DateTime inicio,
    DateTime fim,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('escala_servico_posicoes')
        .select('funcao, escalas_servico!inner(evento_id, data_ocorrencia, ministerio)')
        .eq('profile_id', userId)
        .gte('escalas_servico.data_ocorrencia', inicio.toIso8601String().split('T').first)
        .lte('escalas_servico.data_ocorrencia', fim.toIso8601String().split('T').first);

    return (data as List).map((e) {
      final map = e as Map<String, dynamic>;
      final escala = map['escalas_servico'] as Map<String, dynamic>;
      return MinhaEscalaResumo(
        eventoId: escala['evento_id'] as String,
        dataOcorrencia: DateTime.parse(escala['data_ocorrencia'] as String),
        ministerio: escala['ministerio'] as String,
        funcao: map['funcao'] as String,
      );
    }).toList();
  }

  /// So usado pelos Diaconos -- busca o par de casal mais recentemente
  /// salvo pra essa pessoa (se houver), pra autopreencher a celula
  /// irma na grade. null se essa pessoa nunca foi pareada.
  Future<PessoaBusca?> buscarParDoCasal({
    required String ministerio,
    required String profileId,
  }) async {
    final data = await _client
        .from('escala_servico_casais')
        .select(
          'profile_id_a, profile_id_b, '
          'a:profiles!escala_servico_casais_profile_id_a_fkey(nome), '
          'b:profiles!escala_servico_casais_profile_id_b_fkey(nome)',
        )
        .eq('ministerio', ministerio)
        .or('profile_id_a.eq.$profileId,profile_id_b.eq.$profileId')
        .order('atualizado_em', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;

    if (data['profile_id_a'] == profileId) {
      final b = data['b'] as Map<String, dynamic>?;
      return PessoaBusca(
        id: data['profile_id_b'] as String,
        nome: b?['nome'] as String? ?? '',
      );
    }
    final a = data['a'] as Map<String, dynamic>?;
    return PessoaBusca(
      id: data['profile_id_a'] as String,
      nome: a?['nome'] as String? ?? '',
    );
  }

  /// So usado pelos Diaconos -- lembra (ou atualiza) o par de casal.
  /// Upsert idempotente: seguro de chamar toda vez que as duas pessoas
  /// de uma celula ficam preenchidas juntas, nunca duplica linha.
  Future<void> salvarPar({
    required String ministerio,
    required String profileIdA,
    required String profileIdB,
  }) async {
    if (profileIdA == profileIdB) return;
    final ids = [profileIdA, profileIdB]..sort();
    await _client.from('escala_servico_casais').upsert(
      {
        'ministerio': ministerio,
        'profile_id_a': ids[0],
        'profile_id_b': ids[1],
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      onConflict: 'ministerio,profile_id_a,profile_id_b',
    );
  }
}
