class QuestionarioNovoServo {
  final String id;
  final String profileId;
  final String? nomePessoa;
  final Map<String, dynamic> respostas;
  final DateTime criadoEm;
  final bool lido;

  QuestionarioNovoServo({
    required this.id,
    required this.profileId,
    this.nomePessoa,
    required this.respostas,
    required this.criadoEm,
    required this.lido,
  });

  factory QuestionarioNovoServo.fromMap(Map<String, dynamic> map) {
    final perfil = map['profiles'] as Map<String, dynamic>?;
    return QuestionarioNovoServo(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      nomePessoa: perfil?['nome'] as String?,
      respostas: Map<String, dynamic>.from(map['respostas'] as Map? ?? {}),
      criadoEm: DateTime.parse(map['criado_em'] as String),
      lido: map['lido'] as bool? ?? false,
    );
  }
}
