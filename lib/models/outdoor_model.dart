enum OutdoorTipo { recorrente, temporario, sempre }

OutdoorTipo outdoorTipoFromString(String? value) {
  switch (value) {
    case 'temporario':
      return OutdoorTipo.temporario;
    case 'sempre':
      return OutdoorTipo.sempre;
    default:
      return OutdoorTipo.recorrente;
  }
}

extension OutdoorTipoDb on OutdoorTipo {
  String get valorBanco {
    switch (this) {
      case OutdoorTipo.temporario:
        return 'temporario';
      case OutdoorTipo.sempre:
        return 'sempre';
      case OutdoorTipo.recorrente:
        return 'recorrente';
    }
  }
}

/// Acha o Nº-esimo domingo (n=1..5) de um mes/ano -- null se esse mes
/// nao tiver esse Nº de domingos (ex: nem todo mes tem 5º domingo).
/// Mesma logica usada em EventModel.occurrencesBetween pra semanasDoMes.
DateTime? nthSundayOfMonth(int year, int month, int n) {
  var dia = DateTime(year, month, 1);
  var contador = 0;
  while (dia.month == month) {
    if (dia.weekday == DateTime.sunday) {
      contador++;
      if (contador == n) return dia;
    }
    dia = dia.add(const Duration(days: 1));
  }
  return null;
}

/// Banner que gira no slideshow da tela de Inicio. So Admin cria
/// (diferente de evento, que lider de ministerio tambem pode).
class OutdoorModel {
  final String id;
  final String imagemUrl;
  final String? linkUrl;
  final OutdoorTipo tipo;
  /// 1 a 5 -- so quando tipo=recorrente.
  final int? semanaDoMes;
  /// So quando tipo=temporario.
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool ativo;
  /// Escopos/ministerios que podem ver esse outdoor (mesmo vocabulario
  /// de EventoEscopo.valorBanco). null/vazio = visivel pra todo mundo.
  final List<String>? escopos;
  final String? criadoPor;
  final DateTime? criadoEm;

  OutdoorModel({
    required this.id,
    required this.imagemUrl,
    this.linkUrl,
    required this.tipo,
    this.semanaDoMes,
    this.dataInicio,
    this.dataFim,
    this.ativo = true,
    this.escopos,
    this.criadoPor,
    this.criadoEm,
  });

  factory OutdoorModel.fromMap(Map<String, dynamic> map) {
    return OutdoorModel(
      id: map['id'] as String,
      imagemUrl: map['imagem_url'] as String,
      linkUrl: map['link_url'] as String?,
      tipo: outdoorTipoFromString(map['tipo'] as String?),
      semanaDoMes: map['semana_do_mes'] as int?,
      dataInicio: map['data_inicio'] != null ? DateTime.parse(map['data_inicio'] as String) : null,
      dataFim: map['data_fim'] != null ? DateTime.parse(map['data_fim'] as String) : null,
      ativo: map['ativo'] as bool? ?? true,
      escopos: (map['escopos'] as List?)?.map((e) => e.toString()).toList(),
      criadoPor: map['criado_por'] as String?,
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em'] as String) : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'imagem_url': imagemUrl,
      'link_url': linkUrl,
      'tipo': tipo.valorBanco,
      'semana_do_mes': tipo == OutdoorTipo.recorrente ? semanaDoMes : null,
      'data_inicio': tipo == OutdoorTipo.temporario
          ? dataInicio?.toIso8601String().split('T').first
          : null,
      'data_fim':
          tipo == OutdoorTipo.temporario ? dataFim?.toIso8601String().split('T').first : null,
      'ativo': ativo,
      'escopos': (escopos == null || escopos!.isEmpty) ? null : escopos,
    };
  }

  /// Se esse outdoor deve aparecer no slideshow no dia informado.
  /// tipo=sempre: sempre visivel, sem nenhuma janela de data (so
  /// depende do toggle "ativo").
  /// tipo=temporario: continuamente entre dataInicio e dataFim.
  /// tipo=recorrente: de 5 dias antes do domingo-alvo (semanaDoMes) ate
  /// o fim do proprio domingo -- checa o mes anterior/atual/seguinte
  /// pra cobrir corretamente as viradas de mes.
  bool estaVisivelEm(DateTime hoje) {
    if (!ativo) return false;
    if (tipo == OutdoorTipo.sempre) return true;
    final dataOnly = DateTime(hoje.year, hoje.month, hoje.day);

    if (tipo == OutdoorTipo.temporario) {
      if (dataInicio == null || dataFim == null) return false;
      return !dataOnly.isBefore(dataInicio!) && !dataOnly.isAfter(dataFim!);
    }

    if (semanaDoMes == null) return false;
    for (final deslocamentoMes in [-1, 0, 1]) {
      final mesRef = DateTime(dataOnly.year, dataOnly.month + deslocamentoMes, 1);
      final domingo = nthSundayOfMonth(mesRef.year, mesRef.month, semanaDoMes!);
      if (domingo == null) continue;
      final inicioJanela = domingo.subtract(const Duration(days: 5));
      if (!dataOnly.isBefore(inicioJanela) && !dataOnly.isAfter(domingo)) {
        return true;
      }
    }
    return false;
  }
}
