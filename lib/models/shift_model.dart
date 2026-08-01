import 'service_area_model.dart';

/// Representa o "modelo" de uma escala -- se `recorrente` for true,
/// ela se repete toda semana a partir de `data`, e cada semana e uma
/// ocorrencia separada (com sua propria lista de inscritos).
class ShiftModel {
  final String id;
  final String nome;
  final String? areaId;
  final ServiceAreaModel? area;
  final DateTime data;
  final String horarioInicio; // formato HH:mm
  final String horarioFim;
  final int vagas;
  final bool recorrente;
  final DateTime? recorrenciaFim;

  ShiftModel({
    required this.id,
    required this.nome,
    this.areaId,
    this.area,
    required this.data,
    required this.horarioInicio,
    required this.horarioFim,
    required this.vagas,
    this.recorrente = false,
    this.recorrenciaFim,
  });

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] as String,
      nome: map['nome'] as String? ?? '',
      areaId: map['area_id'] as String?,
      area: map['areas_servico'] != null
          ? ServiceAreaModel.fromMap(map['areas_servico'] as Map<String, dynamic>)
          : null,
      data: DateTime.parse(map['data'] as String),
      horarioInicio: (map['horario_inicio'] as String).substring(0, 5),
      horarioFim: (map['horario_fim'] as String).substring(0, 5),
      vagas: map['vagas'] as int,
      recorrente: map['recorrente'] as bool? ?? false,
      recorrenciaFim: map['recorrencia_fim'] != null
          ? DateTime.parse(map['recorrencia_fim'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'nome': nome,
      'area_id': areaId,
      'data': data.toIso8601String().split('T').first,
      'horario_inicio': horarioInicio,
      'horario_fim': horarioFim,
      'vagas': vagas,
      'recorrente': recorrente,
      'recorrencia_fim': recorrenciaFim?.toIso8601String().split('T').first,
    };
  }

  /// Gera as datas (so a data, sem hora) das ocorrencias desse modelo
  /// de escala dentro do intervalo informado.
  List<DateTime> occurrencesBetween(DateTime rangeStart, DateTime rangeEnd) {
    final anchor = DateTime(data.year, data.month, data.day);
    final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    if (!recorrente) {
      if (!anchor.isBefore(start) && !anchor.isAfter(end)) return [anchor];
      return [];
    }

    final result = <DateTime>[];
    var cursor = anchor;

    while (cursor.isBefore(start)) {
      cursor = cursor.add(const Duration(days: 7));
      if (recorrenciaFim != null && cursor.isAfter(recorrenciaFim!)) return result;
    }

    while (!cursor.isAfter(end)) {
      if (recorrenciaFim != null && cursor.isAfter(recorrenciaFim!)) break;
      result.add(cursor);
      cursor = cursor.add(const Duration(days: 7));
    }

    return result;
  }
}

/// Uma ocorrencia especifica (semana) de uma escala, ja com a contagem
/// de vagas preenchidas naquela data.
class ShiftOccurrence {
  final ShiftModel shift;
  final DateTime data;
  final int inscritosCount;

  ShiftOccurrence({
    required this.shift,
    required this.data,
    required this.inscritosCount,
  });

  bool get temVaga => inscritosCount < shift.vagas;

  DateTime get inicioCompleto {
    final partes = shift.horarioInicio.split(':');
    return DateTime(
      data.year,
      data.month,
      data.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );
  }
}