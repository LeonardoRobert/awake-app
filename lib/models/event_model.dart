import 'package:flutter/material.dart';

enum EventTipo { ebd, gc, comunhao, laje, cultoCelebracao, cultoFamilia, embaixadoresMensageiras, outro }

EventTipo eventTipoFromString(String? value) {
  switch (value) {
    case 'ebd':
      return EventTipo.ebd;
    case 'gc':
      return EventTipo.gc;
    case 'comunhao':
      return EventTipo.comunhao;
    case 'laje':
      return EventTipo.laje;
    case 'culto_celebracao':
      return EventTipo.cultoCelebracao;
    case 'culto_familia':
      return EventTipo.cultoFamilia;
    case 'embaixadores_mensageiras':
      return EventTipo.embaixadoresMensageiras;
    default:
      return EventTipo.outro;
  }
}

extension EventTipoDb on EventTipo {
  /// Valor exato salvo no banco (o enum do Postgres usa esses nomes).
  String get valorBanco {
    switch (this) {
      case EventTipo.ebd:
        return 'ebd';
      case EventTipo.gc:
        return 'gc';
      case EventTipo.comunhao:
        return 'comunhao';
      case EventTipo.laje:
        return 'laje';
      case EventTipo.cultoCelebracao:
        return 'culto_celebracao';
      case EventTipo.cultoFamilia:
        return 'culto_familia';
      case EventTipo.embaixadoresMensageiras:
        return 'embaixadores_mensageiras';
      case EventTipo.outro:
        return 'outro';
    }
  }
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
      case EventTipo.cultoCelebracao:
        return 'Culto de Celebração';
      case EventTipo.cultoFamilia:
        return 'Culto da Família';
      case EventTipo.embaixadoresMensageiras:
        return 'Embaixadores e Mensageiras';
      case EventTipo.outro:
        return 'Outro';
    }
  }
}

/// Cor da bolinha desse tipo de evento no calendario.
extension EventTipoColor on EventTipo {
  Color get cor {
    switch (this) {
      case EventTipo.ebd:
        return const Color(0xFFFFD21F); // amarela
      case EventTipo.cultoCelebracao:
        return const Color(0xFF1D4ED8); // azul escuro
      case EventTipo.cultoFamilia:
        return const Color(0xFF60A5FA); // azul claro
      case EventTipo.embaixadoresMensageiras:
        return const Color(0xFF8D6E63); // marrom
      case EventTipo.gc:
        return const Color(0xFF4ADE80); // verde claro
      case EventTipo.comunhao:
        return const Color(0xFFEF4444); // vermelho
      case EventTipo.laje:
        return const Color(0xFFFB923C); // laranja
      case EventTipo.outro:
        return const Color(0xFFA78BFA); // roxo
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
  final List<String>? publicoAlvo;
  final List<DateTime> excecoes;
  final String? fotoUrl;

  /// Segunda foto opcional, em formato vertical (Story), usada no
  /// botao "Adicionar ao Instagram".
  final String? fotoStoryUrl;

  /// true = evento exclusivo da Awake (aparece na tela de Inicio se for
  /// sexta-feira). false = evento geral da igreja.
  final bool exclusivoAwake;

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
    this.fotoUrl,
    this.fotoStoryUrl,
    this.exclusivoAwake = false,
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
      fotoUrl: map['foto_url'] as String?,
      fotoStoryUrl: map['foto_story_url'] as String?,
      exclusivoAwake: map['exclusivo_awake'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'data_inicio': dataInicio.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'local': local,
      'recorrente': recorrente,
      'recorrencia_fim': recorrenciaFim?.toIso8601String().split('T').first,
      'tipo': tipo.valorBanco,
      'publico_alvo': publicoAlvo,
      'foto_url': fotoUrl,
      'foto_story_url': fotoStoryUrl,
      'exclusivo_awake': exclusivoAwake,
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
