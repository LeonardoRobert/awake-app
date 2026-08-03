enum UserRole { membro, lider, admin }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (e) => e.name == value,
    orElse: () => UserRole.membro,
  );
}

enum EstadoCivil { solteiro, namorando, noivo, casado, outro }

EstadoCivil? estadoCivilFromString(String? value) {
  if (value == null) return null;
  return EstadoCivil.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EstadoCivil.outro,
  );
}

/// Genesis (13-16, solteiro/namorando), Next (17+, solteiro/namorando),
/// One (noivo ou casado, qualquer idade). Calculado automaticamente
/// no banco (ver supabase/schema.sql: calcular_categoria) — aqui so
/// refletimos o valor para exibir na tela.
enum Categoria { genesis, next, one }

Categoria? categoriaFromString(String? value) {
  if (value == null) return null;
  return Categoria.values.firstWhere(
    (e) => e.name == value,
    orElse: () => Categoria.genesis,
  );
}

extension CategoriaLabel on Categoria {
  String get label {
    switch (this) {
      case Categoria.genesis:
        return 'Genesis';
      case Categoria.next:
        return 'Next';
      case Categoria.one:
        return 'One';
    }
  }
}

class ProfileModel {
  final String id;
  final String nome;
  final String? telefone;
  final String? endereco;
  final DateTime? dataNascimento;
  final String? tempoParticipacao;
  final EstadoCivil? estadoCivil;
  final Categoria? categoria;
  final UserRole papel;
  final String qrCodeId;
  final bool ativo;
  final bool tourVisto;
  final DateTime criadoEm;

  ProfileModel({
    required this.id,
    required this.nome,
    this.telefone,
    this.endereco,
    this.dataNascimento,
    this.tempoParticipacao,
    this.estadoCivil,
    this.categoria,
    required this.papel,
    required this.qrCodeId,
    required this.ativo,
    this.tourVisto = false,
    required this.criadoEm,
  });

  bool get isLider => papel == UserRole.lider || papel == UserRole.admin;
  bool get isAdmin => papel == UserRole.admin;

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      nome: map['nome'] as String? ?? '',
      telefone: map['telefone'] as String?,
      endereco: map['endereco'] as String?,
      dataNascimento: map['data_nascimento'] != null
          ? DateTime.parse(map['data_nascimento'] as String)
          : null,
      tempoParticipacao: map['tempo_participacao'] as String?,
      estadoCivil: estadoCivilFromString(map['estado_civil'] as String?),
      categoria: categoriaFromString(map['categoria'] as String?),
      papel: userRoleFromString(map['papel'] as String? ?? 'membro'),
      qrCodeId: map['qr_code_id'] as String,
      ativo: map['ativo'] as bool? ?? true,
      tourVisto: map['tour_visto'] as bool? ?? false,
      criadoEm: DateTime.parse(map['criado_em'] as String),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'nome': nome,
      'telefone': telefone,
      'endereco': endereco,
      'data_nascimento': dataNascimento?.toIso8601String(),
      'tempo_participacao': tempoParticipacao,
      'estado_civil': estadoCivil?.name,
    };
  }
}
