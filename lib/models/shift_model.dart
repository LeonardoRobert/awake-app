import 'service_area_model.dart';

class ShiftModel {
  final String id;
  final String areaId;
  final ServiceAreaModel? area;
  final DateTime data;
  final String horarioInicio; // formato HH:mm
  final String horarioFim;
  final int vagas;
  final int inscritosCount;

  ShiftModel({
    required this.id,
    required this.areaId,
    this.area,
    required this.data,
    required this.horarioInicio,
    required this.horarioFim,
    required this.vagas,
    this.inscritosCount = 0,
  });

  bool get temVaga => inscritosCount < vagas;

  /// Data/hora combinada de inicio do turno, usada para calcular a regra
  /// de cancelamento com 24h de antecedencia.
  DateTime get inicioCompleto {
    final partes = horarioInicio.split(':');
    return DateTime(
      data.year,
      data.month,
      data.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] as String,
      areaId: map['area_id'] as String,
      area: map['areas_servico'] != null
          ? ServiceAreaModel.fromMap(map['areas_servico'] as Map<String, dynamic>)
          : null,
      data: DateTime.parse(map['data'] as String),
      horarioInicio: (map['horario_inicio'] as String).substring(0, 5),
      horarioFim: (map['horario_fim'] as String).substring(0, 5),
      vagas: map['vagas'] as int,
      inscritosCount: map['inscritos_count'] as int? ?? 0,
    );
  }
}
