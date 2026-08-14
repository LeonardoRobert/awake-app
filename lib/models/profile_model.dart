enum UserRole { membro, admin }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'admin':
    // 'admin_financeiro' deixou de ser um papel separado -- Admin e
    // Admin Financeiro tinham as mesmas permissoes de banco, e a tela
    // de Financeiro virou so pagamento de evento ingressado (qualquer
    // admin ja acessa). O banco esta sendo migrado (ver
    // supabase/sql/2026_merge_admin_financeiro.sql), mas o app trata
    // esse valor antigo como admin tambem, por seguranca.
    case 'admin_financeiro':
      return UserRole.admin;
    default:
      // Cobre 'membro' e tambem o antigo 'lider' (que nao existe mais
      // como papel global -- virou papel por ministerio).
      return UserRole.membro;
  }
}

enum EstadoCivil { solteiro, namorando, noivo, casado, outro }

EstadoCivil? estadoCivilFromString(String? value) {
  if (value == null) return null;
  return EstadoCivil.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EstadoCivil.outro,
  );
}

enum Sexo { masculino, feminino }

Sexo? sexoFromString(String? value) {
  if (value == null) return null;
  return Sexo.values.firstWhere(
    (e) => e.name == value,
    orElse: () => Sexo.masculino,
  );
}

extension SexoLabel on Sexo {
  String get label => this == Sexo.masculino ? 'Masculino' : 'Feminino';
}

/// Subgrupos dentro de "Casais" -- so pra quem e casado e NAO e do
/// Awake (quem e casado e Awake ja cai automaticamente em "One").
enum GrupoCasais { henriquePatricia, ivaldoSonja, marceloAndreia }

GrupoCasais? grupoCasaisFromString(String? value) {
  switch (value) {
    case 'henrique_patricia':
      return GrupoCasais.henriquePatricia;
    case 'ivaldo_sonja':
      return GrupoCasais.ivaldoSonja;
    case 'marcelo_andreia':
      return GrupoCasais.marceloAndreia;
    default:
      return null;
  }
}

extension GrupoCasaisDb on GrupoCasais {
  String get valorBanco {
    switch (this) {
      case GrupoCasais.henriquePatricia:
        return 'henrique_patricia';
      case GrupoCasais.ivaldoSonja:
        return 'ivaldo_sonja';
      case GrupoCasais.marceloAndreia:
        return 'marcelo_andreia';
    }
  }

  String get label {
    switch (this) {
      case GrupoCasais.henriquePatricia:
        return 'Grupo do Henrique e Patrícia';
      case GrupoCasais.ivaldoSonja:
        return 'Grupo do Ivaldo e Sonja';
      case GrupoCasais.marceloAndreia:
        return 'Grupo do Marcelo e Andréia';
    }
  }
}

/// Genesis (13-16, solteiro/namorando), Next (17+, solteiro/namorando),
/// One (noivo ou casado, qualquer idade). Calculado automaticamente
/// no banco (ver supabase/schema.sql: calcular_categoria) — aqui so
/// refletimos o valor para exibir na tela. Vale so dentro do Awake.
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

/// Vinculo da pessoa com um ministerio (Awake, Homens, Mulheres,
/// Criancas) -- uma pessoa pode ter ate 2 ao mesmo tempo, cada um com
/// seu proprio papel (membro ou lider).
class MinisterioMembership {
  final String ministerio; // 'awake' | 'homens' | 'mulheres' | 'criancas'
  final bool ehLider;

  const MinisterioMembership({required this.ministerio, required this.ehLider});
}

extension MinisterioLabel on String {
  String get labelMinisterio {
    switch (this) {
      case 'awake':
        return 'Awake';
      case 'homens':
        return 'Homens';
      case 'mulheres':
        return 'Mulheres';
      case 'criancas':
        return 'Crianças';
      case 'coral':
        return 'Coral';
      case 'danca':
        return 'Dança';
      case 'diaconos':
        return 'Diáconos';
      case 'intercessao':
        return 'Intercessão';
      case 'louvor':
        return 'Louvor';
      case 'midia':
        return 'Mídia';
      case 'multimidia':
        return 'Multimídia';
      case 'teatro':
        return 'Teatro';
      default:
        return this;
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
  final Sexo? sexo;
  final GrupoCasais? grupoCasais;
  final String? fotoUrl;
  final Categoria? categoria;
  final UserRole papel;
  final String qrCodeId;
  final bool ativo;
  final bool tourVisto;
  final DateTime criadoEm;
  final List<MinisterioMembership> ministerios;

  ProfileModel({
    required this.id,
    required this.nome,
    this.telefone,
    this.endereco,
    this.dataNascimento,
    this.tempoParticipacao,
    this.estadoCivil,
    this.sexo,
    this.grupoCasais,
    this.fotoUrl,
    this.categoria,
    required this.papel,
    required this.qrCodeId,
    required this.ativo,
    this.tourVisto = false,
    required this.criadoEm,
    this.ministerios = const [],
  });

  bool get isAdmin => papel == UserRole.admin;

  bool get pertenceAwake => ministerios.any((m) => m.ministerio == 'awake');
  bool get pertenceHomens => ministerios.any((m) => m.ministerio == 'homens');
  bool get pertenceMulheres => ministerios.any((m) => m.ministerio == 'mulheres');
  bool get pertenceCriancas => ministerios.any((m) => m.ministerio == 'criancas');

  bool get ehLiderDeAlgumMinisterio => isAdmin || ministerios.any((m) => m.ehLider);

  /// Mantido com esse nome de proposito: ate hoje, toda lideranca do
  /// app e lideranca do Awake, e as telas de Escala, Check-in, Metas e
  /// Treinamentos usam esse getter esperando exatamente esse
  /// significado. Trocar o nome exigiria mexer em varias telas sem
  /// necessidade.
  bool get isLider =>
      isAdmin || ministerios.any((m) => m.ministerio == 'awake' && m.ehLider);

  factory ProfileModel.fromMap(
    Map<String, dynamic> map, {
    List<MinisterioMembership> ministerios = const [],
  }) {
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
      sexo: sexoFromString(map['sexo'] as String?),
      grupoCasais: grupoCasaisFromString(map['grupo_casais'] as String?),
      fotoUrl: map['foto_url'] as String?,
      categoria: categoriaFromString(map['categoria'] as String?),
      papel: userRoleFromString(map['papel'] as String? ?? 'membro'),
      qrCodeId: map['qr_code_id'] as String,
      ativo: map['ativo'] as bool? ?? true,
      tourVisto: map['tour_visto'] as bool? ?? false,
      criadoEm: DateTime.parse(map['criado_em'] as String),
      ministerios: ministerios,
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
      'sexo': sexo?.name,
      'grupo_casais': grupoCasais?.valorBanco,
    };
  }
}
