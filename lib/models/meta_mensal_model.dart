/// Metas fixas do ministerio, por mes.
class MetasConfig {
  static const ebd = 3;
  static const comunhao = 1;
  static const gc = 1;
  static const escala = 2;
}

class MetaMensal {
  final DateTime mes;
  final int ebd;
  final int gc;
  final int comunhao;
  final int escala;

  MetaMensal({
    required this.mes,
    required this.ebd,
    required this.gc,
    required this.comunhao,
    required this.escala,
  });

  bool get cumpriuEbd => ebd >= MetasConfig.ebd;
  bool get cumpriuGc => gc >= MetasConfig.gc;
  bool get cumpriuComunhao => comunhao >= MetasConfig.comunhao;
  bool get cumpriuEscala => escala >= MetasConfig.escala;

  bool get mesCumprido => cumpriuEbd && cumpriuGc && cumpriuComunhao && cumpriuEscala;
}

/// Um dos 6 troféus de constância.
class Trofeu {
  final String nome;
  final int meses;

  const Trofeu(this.nome, this.meses);
}

const trofeus = [
  Trofeu('João Batista', 2),
  Trofeu('Davi', 4),
  Trofeu('José do Egito', 6),
  Trofeu('Jacó', 8),
  Trofeu('Moisés', 10),
  Trofeu('Noé', 12),
];

class RankingEntry {
  final String nome;
  final String? categoria;
  final int total;

  RankingEntry({required this.nome, this.categoria, required this.total});
}