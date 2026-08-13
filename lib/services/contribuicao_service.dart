import '../models/contribuicao_model.dart';
import 'supabase_service.dart';

class PessoaResumo {
  final String id;
  final String nome;
  const PessoaResumo({required this.id, required this.nome});
}

class ContribuicaoService {
  final _client = SupabaseService.client;

  Future<List<ContribuicaoModel>> listarMinhasContribuicoes() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('contribuicoes')
        .select()
        .eq('profile_id', userId)
        .order('data', ascending: false);

    return (data as List)
        .map((e) => ContribuicaoModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------
  // A partir daqui, so o Admin Financeiro tem permissao (RLS garante
  // isso no banco -- se alguem sem esse cargo chamar, da erro).
  // ---------------------------------------------------------------

  Future<List<PessoaResumo>> listarPessoas() async {
    final data = await _client.from('profiles').select('id, nome').order('nome');
    return (data as List)
        .map((e) => PessoaResumo(
              id: (e as Map<String, dynamic>)['id'] as String,
              nome: e['nome'] as String? ?? '(sem nome)',
            ))
        .toList();
  }

  Future<List<ContribuicaoModel>> listarPorPessoa(String profileId) async {
    final data = await _client
        .from('contribuicoes')
        .select('*, profiles(nome)')
        .eq('profile_id', profileId)
        .order('data', ascending: false);

    return (data as List)
        .map((e) => ContribuicaoModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ContribuicaoModel>> listarTodasRecentes({int limite = 100}) async {
    final data = await _client
        .from('contribuicoes')
        .select('*, profiles(nome)')
        .order('data', ascending: false)
        .limit(limite);

    return (data as List)
        .map((e) => ContribuicaoModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> lancar({
    required String profileId,
    required DateTime data,
    String? horario,
    required double valor,
    required MeioPagamento meioPagamento,
    String? observacao,
    String? eventoId,
    TipoContribuicao? tipo,
  }) async {
    await _client.from('contribuicoes').insert({
      'profile_id': profileId,
      'data': data.toIso8601String().split('T').first,
      'horario': horario,
      'valor': valor,
      'meio_pagamento': meioPagamento.valorBanco,
      'observacao': observacao,
      'lancado_por': _client.auth.currentUser!.id,
      'evento_id': eventoId,
      'tipo': tipo?.valorBanco,
    });
  }

  /// Meus proprios pagamentos vinculados a um evento ingressado
  /// especifico -- usado na tela de detalhes do evento.
  Future<List<ContribuicaoModel>> listarMeusPagamentosDoEvento(String eventoId) async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('contribuicoes')
        .select()
        .eq('profile_id', userId)
        .eq('evento_id', eventoId)
        .order('data', ascending: false);

    return (data as List)
        .map((e) => ContribuicaoModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Quanto a pessoa logada ja pagou de um evento ingressado especifico
  /// -- usado na tarja de progresso da tela de Inicio.
  Future<double> totalPagoEvento(String eventoId) async {
    final userId = _client.auth.currentUser!.id;
    final resultado = await _client.rpc('total_pago_evento', params: {
      'p_profile_id': userId,
      'p_evento_id': eventoId,
    });
    return (resultado as num?)?.toDouble() ?? 0;
  }

  Future<void> editar({
    required String id,
    required DateTime data,
    String? horario,
    required double valor,
    required MeioPagamento meioPagamento,
    String? observacao,
  }) async {
    await _client.from('contribuicoes').update({
      'data': data.toIso8601String().split('T').first,
      'horario': horario,
      'valor': valor,
      'meio_pagamento': meioPagamento.valorBanco,
      'observacao': observacao,
    }).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _client.from('contribuicoes').delete().eq('id', id);
  }
}