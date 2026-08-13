// Robo de teste automatizado -- Fase 1 (conta teste 1: Membro comum).
//
// Roda como script de linha de comando (via GitHub Actions, ver
// .github/workflows/robo-teste.yml), NAO faz parte do app Flutter.
// Loga como a conta de teste "Membro" e exercita as mesmas
// tabelas/RPCs que as telas do app usam, registrando sucesso/erro/
// duracao de cada checagem em testes_automatizados_execucoes.
//
// Variaveis de ambiente esperadas (GitHub Secrets):
//   SUPABASE_URL, SUPABASE_ANON_KEY          -- ja existem no repo
//   SUPABASE_SERVICE_ROLE_KEY                -- novo, mais sensivel
//   TESTE_MEMBRO_EMAIL, TESTE_MEMBRO_SENHA   -- novos

import 'dart:io';
import 'dart:math';
import 'package:supabase/supabase.dart';

late final String _url;
late final String _anonKey;
late final SupabaseClient _admin; // service role -- bypassa RLS, so pra escrever resultado/limpar teste
late final SupabaseClient _clienteMembro; // sessao normal da conta de teste, sujeita a RLS de verdade
late final String _emailMembro;

// O fluxo padrao (PKCE) exige um storage local pra guardar o "code
// verifier" -- nao existe isso aqui (script Dart puro, sem navegador,
// sem redirecionamento). Sem isso, signUp()/resetPasswordForEmail()
// quebram com "Null check operator used on a null value". Fluxo
// implicito nao precisa desse storage e e o correto pra um script
// server-side como este.
const _semPkce = AuthClientOptions(authFlowType: AuthFlowType.implicit);

class _Resultado {
  final String nome;
  final bool sucesso;
  final String? erro;
  final int duracaoMs;
  _Resultado(this.nome, this.sucesso, this.erro, this.duracaoMs);
}

String _env(String nome) {
  final valor = Platform.environment[nome];
  if (valor == null || valor.isEmpty) {
    throw StateError('Variavel de ambiente "$nome" nao definida.');
  }
  return valor;
}

String _gerarUuidV4() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int start, int len) =>
      bytes.sublist(start, start + len).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 2)}-${hex(6, 2)}-${hex(8, 2)}-${hex(10, 6)}';
}

Future<_Resultado> _rodar(String nome, Future<void> Function() teste) async {
  final cronometro = Stopwatch()..start();
  try {
    await teste();
    cronometro.stop();
    stdout.writeln('OK      $nome (${cronometro.elapsedMilliseconds}ms)');
    return _Resultado(nome, true, null, cronometro.elapsedMilliseconds);
  } catch (e) {
    cronometro.stop();
    stdout.writeln('FALHOU  $nome: $e');
    return _Resultado(nome, false, e.toString(), cronometro.elapsedMilliseconds);
  }
}

// ---------- checagens (conta teste 1: Membro) ----------

Future<void> _testarLogin() async {
  final senha = _env('TESTE_MEMBRO_SENHA');
  _clienteMembro = SupabaseClient(_url, _anonKey, authOptions: _semPkce);
  final resposta = await _clienteMembro.auth.signInWithPassword(email: _emailMembro, password: senha);
  if (resposta.session == null) throw Exception('Login não retornou sessão.');
}

Future<void> _testarCadastro() async {
  final clienteTemp = SupabaseClient(_url, _anonKey, authOptions: _semPkce);
  final marca = DateTime.now().millisecondsSinceEpoch;
  final emailDescartavel = 'teste.descartavel.$marca@shallom.app';
  final senhaDescartavel = 'Descartavel$marca!';

  final resposta = await clienteTemp.auth.signUp(email: emailDescartavel, password: senhaDescartavel);
  final id = resposta.user?.id;
  if (id == null) throw Exception('Cadastro não retornou usuário.');

  try {
    // Se o app cria a linha de profiles durante o cadastro, marca como
    // teste (nao da erro se a linha ainda nao existir -- so nao afeta
    // nenhuma linha).
    await _admin.from('profiles').update({'eh_conta_teste': true}).eq('id', id);
  } finally {
    await _admin.auth.admin.deleteUser(id);
  }
}

Future<void> _testarRecuperarSenha() async {
  // So confere que o fluxo INICIA sem erro -- nao completa a troca de
  // senha de verdade (manda um e-mail real pra caixa de teste, o que
  // e esperado e inofensivo).
  final clienteAnon = SupabaseClient(_url, _anonKey, authOptions: _semPkce);
  await clienteAnon.auth.resetPasswordForEmail(_emailMembro);
}

Future<void> _testarListaEventos() async {
  // So chegar aqui sem lancar excecao ja confirma que a consulta (e a
  // RLS por tras dela) funcionou -- uma falha vira PostgrestException,
  // capturada pelo _rodar().
  await _clienteMembro.from('eventos').select();
}

Future<void> _testarQrCode() async {
  final userId = _clienteMembro.auth.currentUser!.id;
  final perfil = await _clienteMembro.from('profiles').select('qr_code_id').eq('id', userId).single();
  if (perfil['qr_code_id'] == null) throw Exception('qr_code_id vazio no perfil de teste.');
}

Future<void> _testarPedidoOracao() async {
  final userId = _clienteMembro.auth.currentUser!.id;
  final inserido = await _clienteMembro.from('pedidos_oracao').insert({
    'profile_id': userId,
    'anonimo': false, // precisa ser false pra supressao de notificacao saber que e teste
    'texto': '[Robô de teste] Verificação automática -- pode ignorar.',
  }).select('id').single();
  await _admin.from('pedidos_oracao').delete().eq('id', inserido['id'] as String);
}

Future<void> _testarTestemunho() async {
  final userId = _clienteMembro.auth.currentUser!.id;
  final inserido = await _clienteMembro.from('testemunhos').insert({
    'profile_id': userId,
    'anonimo': false,
    'texto': '[Robô de teste] Verificação automática -- pode ignorar.',
  }).select('id').single();
  await _admin.from('testemunhos').delete().eq('id', inserido['id'] as String);
}

Future<void> _testarEditarPerfil() async {
  final userId = _clienteMembro.auth.currentUser!.id;
  final atual = await _clienteMembro.from('profiles').select('nome').eq('id', userId).single();
  final nomeOriginal = atual['nome'] as String;

  try {
    await _clienteMembro.from('profiles').update({'nome': '$nomeOriginal (verificando)'}).eq('id', userId);
  } finally {
    await _clienteMembro.from('profiles').update({'nome': nomeOriginal}).eq('id', userId);
  }
}

// Mesma logica de geracao de codigo Pix (TLV + CRC16-CCITT-FALSE) usada
// em financeiro_screen.dart e docs/site.html -- reimplementada aqui
// porque o pacote nao tem como importar codigo do app Flutter (ver
// nota no topo do arquivo). Se a logica de geracao de Pix mudar num
// lugar, precisa atualizar aqui tambem.
String _tlv(String id, String valor) {
  final tamanho = valor.length.toString().padLeft(2, '0');
  return '$id$tamanho$valor';
}

int _crc16CcittFalse(String payload) {
  var crc = 0xFFFF;
  for (final codeUnit in payload.codeUnits) {
    crc ^= (codeUnit << 8);
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc & 0xFFFF;
}

String _gerarCodigoPix(double valor) {
  final valorFormatado = valor.toStringAsFixed(2);
  final infoConta = _tlv('00', 'br.gov.bcb.pix') + _tlv('01', 'shallom.financeiro@gmail.com');
  final semCrc = _tlv('00', '01') +
      _tlv('01', '12') +
      _tlv('26', infoConta) +
      _tlv('52', '0000') +
      _tlv('53', '986') +
      _tlv('54', valorFormatado) +
      _tlv('58', 'BR') +
      _tlv('59', 'COMUNIDADE SHALLOM') +
      _tlv('60', 'SAO JOAO DE MER') +
      _tlv('62', _tlv('05', '***')) +
      '6304';
  final crc = _crc16CcittFalse(semCrc).toRadixString(16).toUpperCase().padLeft(4, '0');
  return semCrc + crc;
}

Future<void> _testarPixDizimoEOferta() async {
  for (final valor in [10.0, 25.50]) {
    final codigo = _gerarCodigoPix(valor);
    if (!codigo.startsWith('000201')) {
      throw Exception('Código Pix (R\$$valor) não começa com o cabeçalho EMV esperado.');
    }
    if (codigo.length < 50) {
      throw Exception('Código Pix (R\$$valor) parece curto demais (${codigo.length} chars).');
    }
  }
}

// ---------- orquestracao ----------

Future<void> _salvarResultados(String rodadaId, List<_Resultado> resultados) async {
  await _admin.from('testes_automatizados_execucoes').insert(
    resultados
        .map((r) => {
              'rodada_id': rodadaId,
              'nome_teste': r.nome,
              'sucesso': r.sucesso,
              'erro': r.erro,
              'duracao_ms': r.duracaoMs,
            })
        .toList(),
  );
}

Future<void> main() async {
  _url = _env('SUPABASE_URL');
  _anonKey = _env('SUPABASE_ANON_KEY');
  final serviceKey = _env('SUPABASE_SERVICE_ROLE_KEY');
  _emailMembro = _env('TESTE_MEMBRO_EMAIL');

  _admin = SupabaseClient(_url, serviceKey, authOptions: _semPkce);

  final rodadaId = _gerarUuidV4();
  stdout.writeln('=== Rodada $rodadaId ===');

  final resultados = <_Resultado>[];

  // Login precisa vir primeiro -- as demais checagens dependem de
  // _clienteMembro estar autenticado.
  final resultadoLogin = await _rodar('login', _testarLogin);
  resultados.add(resultadoLogin);

  if (resultadoLogin.sucesso) {
    resultados.add(await _rodar('ver_inicio', _testarListaEventos));
    resultados.add(await _rodar('ver_calendario', _testarListaEventos));
    resultados.add(await _rodar('qr_code_proprio', _testarQrCode));
    resultados.add(await _rodar('enviar_pedido_oracao', _testarPedidoOracao));
    resultados.add(await _rodar('enviar_testemunho', _testarTestemunho));
    resultados.add(await _rodar('editar_perfil', _testarEditarPerfil));
  } else {
    stdout.writeln('Login falhou -- pulando checagens que dependem de sessão.');
  }

  // Essas nao dependem do login da conta teste 1.
  resultados.add(await _rodar('cadastro_conta_nova', _testarCadastro));
  resultados.add(await _rodar('recuperar_senha', _testarRecuperarSenha));
  resultados.add(await _rodar('gerar_pix_dizimo_oferta', _testarPixDizimoEOferta));

  await _salvarResultados(rodadaId, resultados);

  final falhas = resultados.where((r) => !r.sucesso).toList();
  stdout.writeln('=== ${resultados.length - falhas.length}/${resultados.length} passaram ===');

  if (falhas.isNotEmpty) {
    stderr.writeln('Falharam: ${falhas.map((f) => f.nome).join(', ')}');
    exit(1); // workflow fica vermelho -- GitHub avisa por e-mail sozinho
  }
}
