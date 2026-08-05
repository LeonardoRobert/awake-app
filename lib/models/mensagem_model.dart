class MensagemModel {
  final String id;
  final String? profileId;
  final bool anonimo;
  final String texto;
  final DateTime criadoEm;
  final bool lido;
  final String? nomeAutor;

  MensagemModel({
    required this.id,
    this.profileId,
    required this.anonimo,
    required this.texto,
    required this.criadoEm,
    required this.lido,
    this.nomeAutor,
  });

  factory MensagemModel.fromMap(Map<String, dynamic> map) {
    final perfil = map['profiles'] as Map<String, dynamic>?;
    final anonimo = map['anonimo'] as bool? ?? false;
    return MensagemModel(
      id: map['id'] as String,
      profileId: map['profile_id'] as String?,
      anonimo: anonimo,
      texto: map['texto'] as String,
      criadoEm: DateTime.parse(map['criado_em'] as String),
      lido: map['lido'] as bool? ?? false,
      // Mesmo vindo do banco, o app nunca mostra o nome se a pessoa
      // pediu pra ser anonima.
      nomeAutor: anonimo ? null : perfil?['nome'] as String?,
    );
  }
}
