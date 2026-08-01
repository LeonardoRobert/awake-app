class ServiceAreaModel {
  final String id;
  final String nome;

  ServiceAreaModel({required this.id, required this.nome});

  factory ServiceAreaModel.fromMap(Map<String, dynamic> map) {
    return ServiceAreaModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
    );
  }
}
