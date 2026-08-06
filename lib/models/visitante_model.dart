class VisitanteModel {
  final String id;
  final String? registradoPor;
  final String? nomeRegistrador;
  final Map<String, dynamic> dados;
  final DateTime criadoEm;
  final bool lido;

  VisitanteModel({
    required this.id,
    this.registradoPor,
    this.nomeRegistrador,
    required this.dados,
    required this.criadoEm,
    required this.lido,
  });

  factory VisitanteModel.fromMap(Map<String, dynamic> map) {
    final perfil = map['profiles'] as Map<String, dynamic>?;
    return VisitanteModel(
      id: map['id'] as String,
      registradoPor: map['registrado_por'] as String?,
      nomeRegistrador: perfil?['nome'] as String?,
      dados: Map<String, dynamic>.from(map['dados'] as Map? ?? {}),
      criadoEm: DateTime.parse(map['criado_em'] as String),
      lido: map['lido'] as bool? ?? false,
    );
  }
}
