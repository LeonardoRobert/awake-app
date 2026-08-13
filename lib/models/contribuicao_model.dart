enum MeioPagamento { pix, dinheiro, cartao, transferencia, boleto, outro }

MeioPagamento meioPagamentoFromString(String? value) {
  switch (value) {
    case 'pix':
      return MeioPagamento.pix;
    case 'dinheiro':
      return MeioPagamento.dinheiro;
    case 'cartao':
      return MeioPagamento.cartao;
    case 'transferencia':
      return MeioPagamento.transferencia;
    case 'boleto':
      return MeioPagamento.boleto;
    default:
      return MeioPagamento.outro;
  }
}

enum TipoContribuicao { dizimo, oferta, ofertaMissionaria, movimentoPaz, outro }

TipoContribuicao? tipoContribuicaoFromString(String? value) {
  switch (value) {
    case 'dizimo':
      return TipoContribuicao.dizimo;
    case 'oferta':
      return TipoContribuicao.oferta;
    case 'oferta_missionaria':
      return TipoContribuicao.ofertaMissionaria;
    case 'movimento_paz':
      return TipoContribuicao.movimentoPaz;
    case 'outro':
      return TipoContribuicao.outro;
    default:
      return null;
  }
}

extension TipoContribuicaoLabel on TipoContribuicao {
  String get valorBanco {
    switch (this) {
      case TipoContribuicao.dizimo:
        return 'dizimo';
      case TipoContribuicao.oferta:
        return 'oferta';
      case TipoContribuicao.ofertaMissionaria:
        return 'oferta_missionaria';
      case TipoContribuicao.movimentoPaz:
        return 'movimento_paz';
      case TipoContribuicao.outro:
        return 'outro';
    }
  }

  String get label {
    switch (this) {
      case TipoContribuicao.dizimo:
        return 'Dízimo';
      case TipoContribuicao.oferta:
        return 'Oferta';
      case TipoContribuicao.ofertaMissionaria:
        return 'Oferta missionária';
      case TipoContribuicao.movimentoPaz:
        return 'Movimento da Paz';
      case TipoContribuicao.outro:
        return 'Outro';
    }
  }
}

extension MeioPagamentoLabel on MeioPagamento {
  String get valorBanco {
    switch (this) {
      case MeioPagamento.pix:
        return 'pix';
      case MeioPagamento.dinheiro:
        return 'dinheiro';
      case MeioPagamento.cartao:
        return 'cartao';
      case MeioPagamento.transferencia:
        return 'transferencia';
      case MeioPagamento.boleto:
        return 'boleto';
      case MeioPagamento.outro:
        return 'outro';
    }
  }

  String get label {
    switch (this) {
      case MeioPagamento.pix:
        return 'Pix';
      case MeioPagamento.dinheiro:
        return 'Dinheiro';
      case MeioPagamento.cartao:
        return 'Cartão';
      case MeioPagamento.transferencia:
        return 'Transferência';
      case MeioPagamento.boleto:
        return 'Boleto';
      case MeioPagamento.outro:
        return 'Outro';
    }
  }
}

class ContribuicaoModel {
  final String id;
  /// Nulo quando a entrada veio de extrato importado e nao achou
  /// ninguem cadastrado (ver motivoSemUsuario) -- nao usado hoje em
  /// nenhuma tela do app (essas linhas so aparecem no gestao.html),
  /// mas o model reflete o banco de verdade.
  final String? profileId;
  final DateTime data;
  final String? horario;
  final double valor;
  final MeioPagamento meioPagamento;
  final String? observacao;
  final String? nomePessoa;
  /// Se preenchido, esse lancamento e um pagamento de inscricao pra
  /// um evento ingressado especifico (ex: parcela do retiro) -- em
  /// vez de um dizimo/oferta comum.
  final String? eventoId;
  /// Nulo = nao especificado (lancamentos antigos, ou quando quem
  /// lancou nao escolheu).
  final TipoContribuicao? tipo;

  ContribuicaoModel({
    required this.id,
    this.profileId,
    required this.data,
    this.horario,
    required this.valor,
    required this.meioPagamento,
    this.observacao,
    this.nomePessoa,
    this.eventoId,
    this.tipo,
  });

  factory ContribuicaoModel.fromMap(Map<String, dynamic> map) {
    final perfil = map['profiles'] as Map<String, dynamic>?;
    return ContribuicaoModel(
      id: map['id'] as String,
      profileId: map['profile_id'] as String?,
      data: DateTime.parse(map['data'] as String),
      horario: map['horario'] as String?,
      valor: (map['valor'] as num).toDouble(),
      meioPagamento: meioPagamentoFromString(map['meio_pagamento'] as String?),
      observacao: map['observacao'] as String?,
      nomePessoa: perfil?['nome'] as String?,
      eventoId: map['evento_id'] as String?,
      tipo: tipoContribuicaoFromString(map['tipo'] as String?),
    );
  }
}
