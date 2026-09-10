/// Um grupo de casais (ex: "Henrique e Patrícia") -- vem do catalogo
/// dinamico no banco (grupos_casais_catalogo), nao de um enum fixo,
/// porque um admin pode criar grupos novos a qualquer momento.
class GrupoCasaisModel {
  final String slug;
  final String nome;

  const GrupoCasaisModel({required this.slug, required this.nome});

  /// Identificador usado como "ministerio" em profile_ministerios /
  /// ocasioes_ministerio -- ver 2026_grupos_casais_ministerios.sql.
  String get ministerio => 'casais_$slug';

  factory GrupoCasaisModel.fromMap(Map<String, dynamic> map) {
    return GrupoCasaisModel(
      slug: map['slug'] as String,
      nome: map['nome'] as String,
    );
  }
}
