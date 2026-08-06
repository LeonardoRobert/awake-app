class FuncaoCatalogo {
  final String ministerio;
  final String funcao;
  final int ordem;
  FuncaoCatalogo({required this.ministerio, required this.funcao, required this.ordem});

  factory FuncaoCatalogo.fromMap(Map<String, dynamic> map) => FuncaoCatalogo(
        ministerio: map['ministerio'] as String,
        funcao: map['funcao'] as String,
        ordem: map['ordem'] as int? ?? 0,
      );
}

class PosicaoEscala {
  final String id;
  final String escalaId;
  final String funcao;
  final String? profileId;
  final String? nomePessoa;
  /// So usado pelos Diaconos, que servem em casal.
  final String? profileId2;
  final String? nomePessoa2;
  final int ordem;

  PosicaoEscala({
    required this.id,
    required this.escalaId,
    required this.funcao,
    this.profileId,
    this.nomePessoa,
    this.profileId2,
    this.nomePessoa2,
    required this.ordem,
  });

  factory PosicaoEscala.fromMap(Map<String, dynamic> map) {
    final perfil = map['profiles'] as Map<String, dynamic>?;
    final perfil2 = map['profiles2'] as Map<String, dynamic>?;
    return PosicaoEscala(
      id: map['id'] as String,
      escalaId: map['escala_id'] as String,
      funcao: map['funcao'] as String,
      profileId: map['profile_id'] as String?,
      nomePessoa: perfil?['nome'] as String?,
      profileId2: map['profile_id_2'] as String?,
      nomePessoa2: perfil2?['nome'] as String?,
      ordem: map['ordem'] as int? ?? 0,
    );
  }
}

class PessoaBusca {
  final String id;
  final String nome;
  PessoaBusca({required this.id, required this.nome});
}

/// Resumo de uma posicao em que EU estou escalado, usado pra "tarja"
/// na tela de Inicio.
class MinhaEscalaResumo {
  final String eventoId;
  final DateTime dataOcorrencia;
  final String ministerio;
  final String funcao;

  MinhaEscalaResumo({
    required this.eventoId,
    required this.dataOcorrencia,
    required this.ministerio,
    required this.funcao,
  });
}
