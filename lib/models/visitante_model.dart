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
      // .toLocal() e' essencial aqui -- criado_em e' timestamptz de
      // verdade (UTC correto), mas DateTime.parse() sozinho mantem os
      // campos (.day/.hour/etc) em UTC. Sem converter, um cadastro
      // feito a noite (ex: 21h30 de quarta em Brasilia = 00h30 de
      // quinta em UTC) aparecia com a data de quinta em qualquer
      // DateFormat/agrupamento por dia (ver admin_visitantes_screen.dart).
      criadoEm: DateTime.parse(map['criado_em'] as String).toLocal(),
      lido: map['lido'] as bool? ?? false,
    );
  }
}
