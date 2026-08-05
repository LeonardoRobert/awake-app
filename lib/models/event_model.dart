import 'package:flutter/material.dart';

// =========================================================
// ESCOPO — define QUEM PODE VER o evento (e, em quase todos os casos,
// tambem a cor da bolinha no calendario). Substitui o antigo booleano
// "exclusivoAwake".
// =========================================================
enum EventoEscopo {
  igreja,
  lideranca,
  casais,
  homens,
  mulheres,
  awake,
  embaixadoresMensageiras,
  criancas,
  danca,
  diaconos,
  louvor,
  midia,
  multimidia,
  teatro,
}

/// Ordem oficial de apresentacao (usada no formulario e como
/// desempate quando dois eventos caem no mesmo dia/horario).
const ordemEscopos = [
  EventoEscopo.igreja,
  EventoEscopo.lideranca,
  EventoEscopo.casais,
  EventoEscopo.homens,
  EventoEscopo.mulheres,
  EventoEscopo.awake,
  EventoEscopo.embaixadoresMensageiras,
  EventoEscopo.criancas,
  EventoEscopo.danca,
  EventoEscopo.diaconos,
  EventoEscopo.louvor,
  EventoEscopo.midia,
  EventoEscopo.multimidia,
  EventoEscopo.teatro,
];

EventoEscopo eventoEscopoFromString(String? value) {
  switch (value) {
    case 'lideranca':
      return EventoEscopo.lideranca;
    case 'casais':
      return EventoEscopo.casais;
    case 'homens':
      return EventoEscopo.homens;
    case 'mulheres':
      return EventoEscopo.mulheres;
    case 'awake':
      return EventoEscopo.awake;
    case 'embaixadores_mensageiras':
      return EventoEscopo.embaixadoresMensageiras;
    case 'criancas':
      return EventoEscopo.criancas;
    case 'danca':
      return EventoEscopo.danca;
    case 'diaconos':
      return EventoEscopo.diaconos;
    case 'louvor':
      return EventoEscopo.louvor;
    case 'midia':
      return EventoEscopo.midia;
    case 'multimidia':
      return EventoEscopo.multimidia;
    case 'teatro':
      return EventoEscopo.teatro;
    default:
      return EventoEscopo.igreja;
  }
}

extension EventoEscopoDb on EventoEscopo {
  String get valorBanco {
    switch (this) {
      case EventoEscopo.igreja:
        return 'igreja';
      case EventoEscopo.lideranca:
        return 'lideranca';
      case EventoEscopo.casais:
        return 'casais';
      case EventoEscopo.homens:
        return 'homens';
      case EventoEscopo.mulheres:
        return 'mulheres';
      case EventoEscopo.awake:
        return 'awake';
      case EventoEscopo.embaixadoresMensageiras:
        return 'embaixadores_mensageiras';
      case EventoEscopo.criancas:
        return 'criancas';
      case EventoEscopo.danca:
        return 'danca';
      case EventoEscopo.diaconos:
        return 'diaconos';
      case EventoEscopo.louvor:
        return 'louvor';
      case EventoEscopo.midia:
        return 'midia';
      case EventoEscopo.multimidia:
        return 'multimidia';
      case EventoEscopo.teatro:
        return 'teatro';
    }
  }

  /// Ministerio correspondente (usado pra saber se um lider de
  /// ministerio pode gerenciar esse escopo). null = so admin.
  String? get ministerioCorrespondente {
    switch (this) {
      case EventoEscopo.homens:
        return 'homens';
      case EventoEscopo.mulheres:
        return 'mulheres';
      case EventoEscopo.awake:
        return 'awake';
      case EventoEscopo.criancas:
        return 'criancas';
      case EventoEscopo.danca:
        return 'danca';
      case EventoEscopo.diaconos:
        return 'diaconos';
      case EventoEscopo.louvor:
        return 'louvor';
      case EventoEscopo.midia:
        return 'midia';
      case EventoEscopo.multimidia:
        return 'multimidia';
      case EventoEscopo.teatro:
        return 'teatro';
      default:
        return null;
    }
  }
}

extension EventoEscopoLabel on EventoEscopo {
  String get label {
    switch (this) {
      case EventoEscopo.igreja:
        return 'Igreja (todos)';
      case EventoEscopo.lideranca:
        return 'Liderança geral';
      case EventoEscopo.casais:
        return 'Casais';
      case EventoEscopo.homens:
        return 'Homens';
      case EventoEscopo.mulheres:
        return 'Mulheres';
      case EventoEscopo.awake:
        return 'Awake';
      case EventoEscopo.embaixadoresMensageiras:
        return 'Embaixadores e Mensageiras';
      case EventoEscopo.criancas:
        return 'Crianças';
      case EventoEscopo.danca:
        return 'Dança';
      case EventoEscopo.diaconos:
        return 'Diáconos';
      case EventoEscopo.louvor:
        return 'Louvor';
      case EventoEscopo.midia:
        return 'Mídia';
      case EventoEscopo.multimidia:
        return 'Multimídia';
      case EventoEscopo.teatro:
        return 'Teatro';
    }
  }

  int get prioridade => ordemEscopos.indexOf(this);
}

// =========================================================
// TIPO — so importa DENTRO de dois escopos: "igreja" (EBD, Culto de
// Celebracao, Culto da Familia) e "awake" (GC, Comunhao, Laje). Pros
// demais escopos, o tipo fica em "outro" e nao aparece na tela --
// a cor e o significado ja vem inteiramente do escopo.
// =========================================================
enum EventTipo { ebd, gc, comunhao, laje, cultoCelebracao, cultoFamilia, outro }

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
    default:
      return EventTipo.outro;
  }
}

extension EventTipoDb on EventTipo {
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
      case EventTipo.outro:
        return 'Outro';
    }
  }
}

/// Tipos selecionaveis quando o escopo e "igreja".
const tiposDoEscopoIgreja = [EventTipo.ebd, EventTipo.cultoCelebracao, EventTipo.cultoFamilia, EventTipo.outro];

/// Tipos selecionaveis quando o escopo e "awake".
const tiposDoEscopoAwake = [EventTipo.gc, EventTipo.comunhao, EventTipo.laje, EventTipo.outro];

// =========================================================
// Cor final do evento: vem do ESCOPO, exceto dentro do Awake, onde
// GC/Comunhao/Laje tem cada um sua propria cor.
// =========================================================
Color corDoEvento(EventTipo tipo, EventoEscopo escopo) {
  if (escopo == EventoEscopo.awake) {
    switch (tipo) {
      case EventTipo.gc:
        return const Color(0xFF4ADE80); // verde
      case EventTipo.comunhao:
        return const Color(0xFFFACC15); // amarelo
      case EventTipo.laje:
        return const Color(0xFFA78BFA); // roxo
      default:
        // "Outro" dentro do Awake -- usado por eventos como "Entre
        // Elas" que nao se encaixam em GC/Comunhao/Laje.
        return const Color(0xFFA78BFA); // roxo
    }
  }

  switch (escopo) {
    case EventoEscopo.igreja:
      return const Color(0xFF60A5FA); // azul claro
    case EventoEscopo.lideranca:
      return const Color(0xFFFB923C); // laranja
    case EventoEscopo.casais:
      return const Color(0xFFEF4444); // vermelho
    case EventoEscopo.homens:
      return const Color(0xFF1D4ED8); // azul escuro
    case EventoEscopo.mulheres:
      return const Color(0xFFEC4899); // rosa
    case EventoEscopo.embaixadoresMensageiras:
      return const Color(0xFF8D6E63); // marrom
    case EventoEscopo.criancas:
      return const Color(0xFFC4B5FD); // lilás
    case EventoEscopo.danca:
    case EventoEscopo.diaconos:
    case EventoEscopo.louvor:
    case EventoEscopo.midia:
    case EventoEscopo.multimidia:
    case EventoEscopo.teatro:
      // Ministerios de servico -- todos na mesma cor (preto), ja que
      // aqui a diferenca e o ministerio em si, nao uma faixa etaria.
      return const Color(0xFF000000);
    case EventoEscopo.awake:
      return const Color(0xFF60A5FA); // nao deveria cair aqui
  }
}

/// Texto curto pra mostrar acima do titulo do evento (ex: "Awake • GC",
/// ou so "Homens" pra escopos sem sub-tipo).
String labelDoEvento(EventTipo tipo, EventoEscopo escopo) {
  if (escopo == EventoEscopo.awake && tipo != EventTipo.outro) {
    return '${escopo.label} • ${tipo.label}';
  }
  if (escopo == EventoEscopo.igreja && tipo != EventTipo.outro) {
    return tipo.label;
  }
  return escopo.label;
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
  /// Em quais semanas do mes o evento acontece (1=primeira semana,
  /// 2=segunda, etc). null/vazio = toda semana (padrao). Ex: [1,3] =
  /// quinzenal; [2] = uma vez por mes, sempre na segunda semana.
  final List<int>? semanasDoMes;
  final EventTipo tipo;
  final EventoEscopo escopo;
  final List<String>? publicoAlvo;
  /// Filtro extra, so dentro do Awake: 'masculino' e/ou 'feminino'.
  /// Se vazio/null, vale pra qualquer genero -- funciona JUNTO com
  /// publicoAlvo (os dois precisam bater, nao um ou outro).
  final List<String>? publicoGenero;
  /// Filtro extra, so dentro de Casais: 'one', 'henrique_patricia',
  /// 'ivaldo_sonja', 'marcelo_andreia'. Vazio/null = todos os casais.
  final List<String>? publicoCasais;
  final List<DateTime> excecoes;
  final String? fotoUrl;
  final String? fotoStoryUrl;

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
    this.semanasDoMes,
    this.tipo = EventTipo.outro,
    this.escopo = EventoEscopo.igreja,
    this.publicoAlvo,
    this.publicoGenero,
    this.publicoCasais,
    this.excecoes = const [],
    this.fotoUrl,
    this.fotoStoryUrl,
  });

  Color get cor => corDoEvento(tipo, escopo);
  String get labelCategoria => labelDoEvento(tipo, escopo);

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
      semanasDoMes: (map['semanas_do_mes'] as List?)?.map((e) => e as int).toList(),
      tipo: eventTipoFromString(map['tipo'] as String?),
      escopo: eventoEscopoFromString(map['escopo'] as String?),
      publicoAlvo: (map['publico_alvo'] as List?)?.map((e) => e.toString()).toList(),
      publicoGenero: (map['publico_genero'] as List?)?.map((e) => e.toString()).toList(),
      publicoCasais: (map['publico_casais'] as List?)?.map((e) => e.toString()).toList(),
      excecoes: (map['excecoes'] as List?)
              ?.map((e) => DateTime.parse(e.toString()))
              .toList() ??
          const [],
      fotoUrl: map['foto_url'] as String?,
      fotoStoryUrl: map['foto_story_url'] as String?,
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
      'semanas_do_mes': semanasDoMes,
      'tipo': tipo.valorBanco,
      'escopo': escopo.valorBanco,
      'publico_alvo': publicoAlvo,
      'publico_genero': publicoGenero,
      'publico_casais': publicoCasais,
      'foto_url': fotoUrl,
      'foto_story_url': fotoStoryUrl,
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

    // Sem semanas especificas escolhidas: repete toda semana, como
    // sempre funcionou.
    if (semanasDoMes == null || semanasDoMes!.isEmpty) {
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

    // Com semanas especificas (quinzenal, mensal, etc): percorre mes a
    // mes, acha todas as ocorrencias daquele dia da semana no mes, e
    // mantem so as que caem na 1a/2a/3a/4a/5a semana escolhida.
    final result = <DateTime>[];
    final weekday = dataInicio.weekday;
    var mesCursor = DateTime(rangeStart.year, rangeStart.month, 1);
    final limiteMes = DateTime(rangeEnd.year, rangeEnd.month, 1);

    while (!mesCursor.isAfter(limiteMes)) {
      var dia = DateTime(mesCursor.year, mesCursor.month, 1);
      var numeroSemana = 0;
      while (dia.month == mesCursor.month) {
        if (dia.weekday == weekday) {
          numeroSemana++;
          if (semanasDoMes!.contains(numeroSemana)) {
            final comHora =
                DateTime(dia.year, dia.month, dia.day, dataInicio.hour, dataInicio.minute);
            final depoisDoInicio = !comHora.isBefore(
                DateTime(dataInicio.year, dataInicio.month, dataInicio.day));
            final dentroDoIntervalo =
                !comHora.isBefore(rangeStart) && !comHora.isAfter(rangeEnd);
            final dentroDoFim = recorrenciaFim == null || !comHora.isAfter(recorrenciaFim!);
            if (depoisDoInicio && dentroDoIntervalo && dentroDoFim && !ehExcecao(comHora)) {
              result.add(comHora);
            }
          }
        }
        dia = dia.add(const Duration(days: 1));
      }
      mesCursor = DateTime(mesCursor.year, mesCursor.month + 1, 1);
    }

    result.sort();
    return result;
  }
}
