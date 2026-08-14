import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduz uma excecao tecnica (Postgrest/Auth/Storage/rede) numa
/// mensagem que faz sentido pra quem nao entende de banco de dados --
/// usado nos SnackBar de erro do app inteiro, no lugar de mostrar a
/// excecao crua (que vaza detalhe tecnico tipo nome de tabela/codigo
/// de erro Postgres e nao ajuda a pessoa a entender o que fazer).
///
/// Uso tipico: `Text('Erro ao salvar: ${mensagemDeErroAmigavel(e)}')`
/// no lugar de `Text('Erro ao salvar: $e')`.
String mensagemDeErroAmigavel(Object erro) {
  if (erro is PostgrestException) {
    // P0001 = codigo padrao de "raise exception 'texto'" sem SQLSTATE
    // explicito -- e' como as nossas proprias funcoes/RPCs (check_in_
    // member, inscrever_em_escala, etc.) levantam erro de regra de
    // negocio, e a mensagem ja foi escrita a mao em portugues pra
    // pessoa ler (ex: "QR Code inválido", "Esta escala já está
    // lotada"). Preserva em vez de trocar por algo generico.
    if (erro.code == 'P0001') {
      return erro.message;
    }
    // RLS bloqueou o INSERT/UPDATE (42501) ou a mensagem menciona RLS
    // diretamente -- mesmo padrao usado nos varios bugs de policy
    // encontrados hoje pelo robo de teste.
    if (erro.code == '42501' || erro.message.contains('row-level security')) {
      return 'Você não tem permissão pra fazer isso.';
    }
    if (erro.code == '23505') {
      return 'Esse registro já existe.';
    }
    if (erro.code == '23514' || erro.code == '23502') {
      return 'Alguma informação está faltando ou inválida.';
    }
    return 'Não foi possível completar a ação. Tenta de novo em instantes.';
  }

  if (erro is AuthException) {
    if (erro.message.contains('Invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    return 'Não foi possível completar essa ação de login. Tenta de novo.';
  }

  if (erro is StorageException) {
    return 'Não foi possível enviar o arquivo. Tenta de novo.';
  }

  final texto = erro.toString();
  if (texto.contains('SocketException') ||
      texto.contains('Failed host lookup') ||
      texto.contains('Connection') ||
      texto.contains('Service Unavailable')) {
    return 'Sem conexão com a internet. Confere e tenta de novo.';
  }

  return 'Algo deu errado. Tenta de novo em instantes.';
}
