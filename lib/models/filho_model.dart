/// Representa um filho cadastrado por um pai/mae. Nao tem conta/login
/// proprio -- e so um dado vinculado ao perfil do responsavel, usado
/// pra liberar visibilidade de eventos de Criancas e de Embaixadores e
/// Mensageiras.
class FilhoModel {
  final String id;
  final String responsavelId;
  final String nome;
  final DateTime dataNascimento;

  FilhoModel({
    required this.id,
    required this.responsavelId,
    required this.nome,
    required this.dataNascimento,
  });

  int get idade {
    final hoje = DateTime.now();
    var anos = hoje.year - dataNascimento.year;
    final aniversarioJaPassouEsteAno = hoje.month > dataNascimento.month ||
        (hoje.month == dataNascimento.month && hoje.day >= dataNascimento.day);
    if (!aniversarioJaPassouEsteAno) anos--;
    return anos;
  }

  factory FilhoModel.fromMap(Map<String, dynamic> map) {
    return FilhoModel(
      id: map['id'] as String,
      responsavelId: map['responsavel_id'] as String,
      nome: map['nome'] as String,
      dataNascimento: DateTime.parse(map['data_nascimento'] as String),
    );
  }
}
