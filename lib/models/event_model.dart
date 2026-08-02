enum EventTipo { ebd, gc, comunhao, laje, outro }

EventTipo eventTipoFromString(String? value) {
  return EventTipo.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EventTipo.outro,
  );
}

extension EventTipoLabel on EventTipo {
  String get label {
    switch (this) {
      case EventTipo.ebd:
        return 'EBD';
      case EventTipo.gc:
        return 'GC';
      case EventTipo.comunhao:
        return 'Comunhão';
      case EventTipo.laje:
        return 'Laje';
      case EventTipo.outro:
        return 'Outro';
    }
  }
}

class EventModel {
  final String id;
  final String titulo;
  final String? descricao;
  final DateTime dataInicio;
  final DateTime? dataFim;
  final String? local;
  final String? criadoPor;
  final bool recorrente;
  final DateTime? recorrenciaFim;
  final EventTipo tipo;

  /// null = evento visivel para todos. Se preenchido, so aparece para
  /// membros cuja categoria (genesis/next/one) estiver nessa lista.
  /// Lideres e admin sempre veem tudo, independente disso (regra
  /// aplicada no banco via RLS).
  final List<String>? publicoAlvo;

  /// Datas puladas dessa recorrencia (ex: "so essa semana nao tem
  /// esse evento", sem apagar a serie toda).
  final List<DateTime> excecoes;

  EventModel({
    required this.id,
    required this.titulo,
    this.descricao,
    required this.dataInicio,
    this.dataFim,
    this.local,
    this.criadoPor,
    this.recorrente = false,
    this.recorrenciaFim,
    this.tipo = EventTipo.outro,
    this.publicoAlvo,
    this.excecoes = const [],
  });


  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] as String,
      titulo: map['titulo'] as String,
      descricao: map['descricao'] as String?,
      dataInicio: DateTime.parse(map['data_inicio'] as String),
      dataFim: map['data_fim'] != null
          ? DateTime.parse(map['data_fim'] as String)
          : null,
      local: map['local'] as String?,
      criadoPor: map['criado_por'] as String?,
      recorrente: map['recorrente'] as bool? ?? false,
      recorrenciaFim: map['recorrencia_fim'] != null
          ? DateTime.parse(map['recorrencia_fim'] as String)
          : null,
      tipo: eventTipoFromString(map['tipo'] as String?),
      publicoAlvo: (map['publico_alvo'] as List?)?.map((e) => e.toString()).toList(),
      excecoes: (map['excecoes'] as List?)
              ?.map((e) => DateTime.parse(e.toString()))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'data_inicio': dataInicio.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'local': local,
      'recorrente': recorrente,
      'recorrencia_fim': recorrenciaFim?.toIso8601String().split('T').first,
      'tipo': tipo.name,
      'publico_alvo': publicoAlvo,
    };
  }

  /// Gera as ocorrencias desse evento dentro do intervalo informado.
  List<DateTime> occurrencesBetween(DateTime rangeStart, DateTime rangeEnd) {
    bool ehExcecao(DateTime d) =>
        excecoes.any((e) => e.year == d.year && e.month == d.month && e.day == d.day);

    if (!recorrente) {
      if (!dataInicio.isBefore(rangeStart) && !dataInicio.isAfter(rangeEnd)) {
        return ehExcecao(dataInicio) ? [] : [dataInicio];
      }
      return [];
    }

    final result = <DateTime>[];
    var cursor = dataInicio;

    while (cursor.isBefore(rangeStart)) {
      cursor = cursor.add(const Duration(days: 7));
      if (recorrenciaFim != null && cursor.isAfter(recorrenciaFim!)) {
        return result;
      }
    }

    while (!cursor.isAfter(rangeEnd)) {
      if (recorrenciaFim != null && cursor.isAfter(recorrenciaFim!)) break;
      if (!ehExcecao(cursor)) result.add(cursor);
      cursor = cursor.add(const Duration(days: 7));
    }

    return result;
  }
}