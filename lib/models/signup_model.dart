enum SignupStatus {
  inscrito,
  canceladoNoPrazo,
  canceladoForaPrazo,
  checkInFeito,
  faltou,
}

SignupStatus signupStatusFromString(String value) {
  switch (value) {
    case 'inscrito':
      return SignupStatus.inscrito;
    case 'cancelado_no_prazo':
      return SignupStatus.canceladoNoPrazo;
    case 'cancelado_fora_prazo':
      return SignupStatus.canceladoForaPrazo;
    case 'check_in_feito':
      return SignupStatus.checkInFeito;
    case 'faltou':
      return SignupStatus.faltou;
    default:
      return SignupStatus.inscrito;
  }
}

extension SignupStatusLabel on SignupStatus {
  String get label {
    switch (this) {
      case SignupStatus.inscrito:
        return 'Inscrito';
      case SignupStatus.canceladoNoPrazo:
        return 'Cancelado (no prazo)';
      case SignupStatus.canceladoForaPrazo:
        return 'Cancelado (fora do prazo)';
      case SignupStatus.checkInFeito:
        return 'Presença confirmada';
      case SignupStatus.faltou:
        return 'Faltou';
    }
  }
}

class SignupModel {
  final String id;
  final String escalaId;
  final DateTime dataOcorrencia;
  final String userId;
  final SignupStatus status;
  final DateTime inscritoEm;
  final DateTime? canceladoEm;
  final String? userNome;
  final Map<String, dynamic>? escala;

  SignupModel({
    required this.id,
    required this.escalaId,
    required this.dataOcorrencia,
    required this.userId,
    required this.status,
    required this.inscritoEm,
    this.canceladoEm,
    this.userNome,
    this.escala,
  });

  factory SignupModel.fromMap(Map<String, dynamic> map) {
    return SignupModel(
      id: map['id'] as String,
      escalaId: map['escala_id'] as String,
      dataOcorrencia: DateTime.parse(map['data_ocorrencia'] as String),
      userId: map['user_id'] as String,
      status: signupStatusFromString(map['status'] as String),
      inscritoEm: DateTime.parse(map['inscrito_em'] as String),
      canceladoEm: map['cancelado_em'] != null
          ? DateTime.parse(map['cancelado_em'] as String)
          : null,
      userNome: map['profiles'] != null
          ? (map['profiles'] as Map<String, dynamic>)['nome'] as String?
          : null,
      escala: map['escalas'] as Map<String, dynamic>?,
    );
  }
}
