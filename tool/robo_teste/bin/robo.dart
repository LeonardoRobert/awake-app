// Robo de teste automatizado -- Fase 1 (Membro comum), Fase 2 (Lider de
// Areas de Servico) e Fase 3 (Admin).
//
// As 4 contas de teste vem de supabase/sql/2026_contas_teste.sql:
//   1. Membro comum
//   2. Lider de TODAS as areas de servico (Diaconos/Louvor/Danca/
//      Midia/Multimidia) -- os testes criam evento+escala+posicao nas
//      5 de verdade, nao so numa representante.
//   3. Admin
//   4. Admin Financeiro -- NAO virou uma Fase 4 separada. Depois da
//      unificacao admin/admin_financeiro (RLS de contribuicoes agora
//      usa is_admin()), testar "lancar contribuicao" como Admin (Fase
//      3) ja cobre o que essa conta faria de diferente.
//
// Roda como script de linha de comando (via GitHub Actions, ver
// .github/workflows/robo-teste.yml), NAO faz parte do app Flutter.
// Loga como cada conta de teste e exercita as mesmas tabelas/RPCs que
// as telas do app usam, registrando sucesso/erro/duracao de cada
// checagem em testes_automatizados_execucoes.
//
// Variaveis de ambiente esperadas (GitHub Secrets):
//   SUPABASE_URL, SUPABASE_ANON_KEY          -- ja existem no repo
//   SUPABASE_SERVICE_ROLE_KEY                -- sensivel
//   TESTE_MEMBRO_EMAIL, TESTE_MEMBRO_SENHA
//   TESTE_LIDER_EMAIL, TESTE_LIDER_SENHA
//   TESTE_ADMIN_EMAIL, TESTE_ADMIN_SENHA
//
// Notificacoes push: NAO tem teste dedicado, mas todo fluxo que
// dispara uma (pedido de oracao, testemunho, visitante, evento novo,
// escalar alguem) ja passa pelas triggers de verdade em todo teste
// aqui -- so nao vira push real porque os 4 profiles de teste tem
// eh_conta_teste=true, e notificar()/trigger_notificar_*
// (2026_suprimir_notificacao_teste.sql) suprimem push de origem ou
// destino de conta de teste. Ou seja: a ausencia de erro nesses testes
// JA confirma que o caminho da notificacao roda sem quebrar.
//
// Deliberadamente fora do robo: "Apagar minha conta" (apagaria de
// verdade uma das 4 contas fixas -- teria que provisionar uma 5a conta
// descartavel soh pra isso, nao vale o custo hoje) e testes que
// dependem de API externa de verdade (YouTube, PagBank).

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:supabase/supabase.dart';

late final String _url;
late final String _anonKey;
late final SupabaseClient _admin; // service role -- bypassa RLS, so pra escrever resultado/limpar teste
late final SupabaseClient _clienteMembro; // sessao normal da conta de teste, sujeita a RLS de verdade
late final SupabaseClient _clienteLider;
late final SupabaseClient _clienteAdmin;
late final String _emailMembro;
late final String _emailLider;
late final String _emailAdmin;

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

/// Variante do _rodar() pra checagens NEGATIVAS -- casos em que a RLS
/// deve BLOQUEAR a acao (lancando excecao). Se o teste passar sem
/// excecao, isso é a falha (permissão vazou). So serve pra INSERT
/// (WITH CHECK falho lanca PostgrestException de verdade); UPDATE/
/// DELETE bloqueado por USING nao lanca excecao (so afeta 0 linhas),
/// entao esses usam _rodar() normal comparando o dado antes/depois.
Future<_Resultado> _rodarEsperandoFalha(String nome, Future<void> Function() teste) async {
  final cronometro = Stopwatch()..start();
  try {
    await teste();
    cronometro.stop();
    stdout.writeln('FALHOU  $nome: deveria ter sido bloqueado pela RLS mas passou.');
    return _Resultado(nome, false, 'Deveria ter sido bloqueado pela RLS mas passou.', cronometro.elapsedMilliseconds);
  } catch (e) {
    cronometro.stop();
    stdout.writeln('OK      $nome (bloqueado corretamente, ${cronometro.elapsedMilliseconds}ms)');
    return _Resultado(nome, true, null, cronometro.elapsedMilliseconds);
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

/// area_id fixo de "Recepção/Primeira Vez" (ver
/// RECUPERACAO_parte3b_fix_id_primeira_vez.sql) -- e o mesmo id que
/// esta_na_escala_primeira_vez() espera pra liberar o insert em
/// visitantes_primeira_vez.
const _areaPrimeiraVezId = '7678a09a-1141-4fcb-833d-0736c91038f0';

/// Prepara o cenario (via _admin, bypassando RLS -- e so setup, nao o
/// que esta sendo testado) escalando o Membro de teste numa area de
/// servico especifica pra HOJE, chama [dentroDoCenario] com o id da
/// escala/inscricao criadas, e desfaz tudo no finally. Reaproveitado
/// pelo teste de "Primeira Vez" e pelo de check-in.
Future<T> _comEscalaAwakeDeHoje<T>({
  required String? areaId,
  required Future<T> Function(String escalaId, String dataStr) dentroDoCenario,
}) async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final escalaId = _gerarUuidV4();
  final dataStr = DateTime.now().toIso8601String().split('T').first;

  await _admin.from('escalas').insert({
    'id': escalaId,
    'nome': '[Robô de teste]',
    'area_id': areaId,
    'data': dataStr,
    'horario_inicio': '00:00',
    'horario_fim': '23:59',
    'vagas': 1,
    'recorrente': false,
  });

  try {
    await _admin.from('inscricoes').insert({
      'escala_id': escalaId,
      'data_ocorrencia': dataStr,
      'user_id': membroId,
      'status': 'inscrito',
    });
    try {
      return await dentroDoCenario(escalaId, dataStr);
    } finally {
      await _admin.from('inscricoes').delete().eq('escala_id', escalaId);
    }
  } finally {
    await _admin.from('escalas').delete().eq('id', escalaId);
  }
}

/// Cadastro de visitante feito por quem esta escalado em "Recepção/
/// Primeira Vez" (LinkFormularioVisitante no Perfil) -- so aparece/
/// funciona pra quem tem inscricao ativa nessa area especifica, por
/// isso monta o cenario com _comEscalaAwakeDeHoje antes.
Future<void> _testarCadastroPrimeiraVez() async {
  await _comEscalaAwakeDeHoje(
    areaId: _areaPrimeiraVezId,
    dentroDoCenario: (escalaId, dataStr) async {
      final userId = _clienteMembro.auth.currentUser!.id;
      final inserido = await _clienteMembro.from('visitantes_primeira_vez').insert({
        'registrado_por': userId,
        'dados': {
          'Nome completo': '[Robô de teste] Visitante',
          'Celular/WhatsApp': '(21) 90000-0000',
          'Data de nascimento': '',
          'Sexo': 'Masculino',
          'Situação de fé': 'Prefiro não responder',
          'Como conheceu': 'Outro: robô de teste',
        },
      }).select('id').single();
      await _admin.from('visitantes_primeira_vez').delete().eq('id', inserido['id'] as String);
    },
  );
}

/// Inscreve e cancela numa escala Awake generica (nao Primeira Vez) --
/// exercita as RPCs inscrever_em_escala e cancel_signup, que o
/// ShiftsScreen usa.
Future<void> _testarInscreverECancelarEscalaAwake() async {
  final escalaId = _gerarUuidV4();
  final dataStr = DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T').first;

  await _admin.from('escalas').insert({
    'id': escalaId,
    'nome': '[Robô de teste]',
    'area_id': null,
    'data': dataStr,
    'horario_inicio': '09:00',
    'horario_fim': '10:00',
    'vagas': 5,
    'recorrente': false,
  });

  try {
    await _clienteMembro.rpc('inscrever_em_escala', params: {
      'p_escala_id': escalaId,
      'p_data_ocorrencia': dataStr,
    });

    final inscricao = await _admin
        .from('inscricoes')
        .select('id')
        .eq('escala_id', escalaId)
        .eq('user_id', _clienteMembro.auth.currentUser!.id)
        .single();

    await _clienteMembro.rpc('cancel_signup', params: {'p_inscricao_id': inscricao['id']});
  } finally {
    await _admin.from('inscricoes').delete().eq('escala_id', escalaId);
    await _admin.from('escalas').delete().eq('id', escalaId);
  }
}

Future<void> _testarCadastrarFilho() async {
  final userId = _clienteMembro.auth.currentUser!.id;
  await _clienteMembro.from('filhos').insert({
    'responsavel_id': userId,
    'nome': '[Robô de teste] Filho',
    'data_nascimento': DateTime(DateTime.now().year - 5).toIso8601String().split('T').first,
  });
  await _admin.from('filhos').delete().eq('responsavel_id', userId).eq('nome', '[Robô de teste] Filho');
}

/// Envia o Questionario de Novo Servo (LinkQuestionarioNovoServo ->
/// questionario_service.dart) -- testa questionarios_novo_servo_insert
/// (profile_id = auth.uid()).
Future<void> _testarEnviarQuestionarioNovoServo() async {
  final userId = _clienteMembro.auth.currentUser!.id;
  final inserido = await _clienteMembro.from('questionarios_novo_servo').insert({
    'profile_id': userId,
    'respostas': {'Por que quer servir?': '[Robô de teste] Verificação automática -- pode ignorar.'},
  }).select('id').single();
  await _admin.from('questionarios_novo_servo').delete().eq('id', inserido['id'] as String);
}

/// Apaga o proprio filho cadastrado -- filhos_delete exige
/// responsavel_id = auth.uid() (2026_corrige_insert_faltando.sql).
/// _testarCadastrarFilho ja testa o insert; esse aqui testa o delete
/// pelo cliente REAL do Membro, nao o bypass de limpeza.
Future<void> _testarApagarFilho() async {
  final userId = _clienteMembro.auth.currentUser!.id;
  final criado = await _clienteMembro
      .from('filhos')
      .insert({
        'responsavel_id': userId,
        'nome': '[Robô de teste] Filho pra apagar',
        'data_nascimento': DateTime(DateTime.now().year - 5).toIso8601String().split('T').first,
      })
      .select('id')
      .single();
  final id = criado['id'] as String;

  try {
    await _clienteMembro.from('filhos').delete().eq('id', id);
    final restante = await _admin.from('filhos').select('id').eq('id', id).maybeSingle();
    if (restante != null) throw Exception('filhos_delete não apagou o filho (ainda existe).');
  } finally {
    await _admin.from('filhos').delete().eq('id', id);
  }
}

/// Negativo: Membro comum tentando criar evento -- eventos_insert
/// exige is_lider_ministerio(escopo), e o Membro de teste nao lidera
/// ministerio nenhum, entao o WITH CHECK deve lançar erro.
Future<void> _testarMembroNaoPodeCriarEvento() async {
  final eventoId = _gerarUuidV4();
  try {
    await _clienteMembro.from('eventos').insert({
      'id': eventoId,
      'titulo': '[Robô de teste] Não deveria conseguir',
      'data_inicio': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'escopo': 'igreja',
      'tipo': 'outro',
      'recorrente': false,
    });
  } finally {
    // So limpa se por algum bug o insert passou mesmo assim.
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Negativo: Membro comum tentando editar um treinamento -- so admin
/// gerencia (treinamentos_update usa is_admin()). UPDATE bloqueado por
/// USING nao lanca excecao (0 linhas afetadas, sem erro) -- por isso
/// confirma comparando o titulo antes/depois, em vez de esperar uma
/// excecao (ao contrario dos negativos de INSERT).
Future<void> _testarMembroNaoPodeEditarTreinamento() async {
  final criado = await _admin
      .from('treinamentos')
      .insert({
        'titulo': '[Robô de teste] Alvo de teste negativo',
        'descricao': 'Pode ignorar.',
        'url_video': 'https://youtube.com/watch?v=robo_de_teste_negativo',
      })
      .select('id')
      .single();
  final id = criado['id'] as String;

  try {
    await _clienteMembro.from('treinamentos').update({'titulo': 'Não deveria conseguir'}).eq('id', id);
    final atual = await _admin.from('treinamentos').select('titulo').eq('id', id).single();
    if (atual['titulo'] != '[Robô de teste] Alvo de teste negativo') {
      throw Exception('Membro conseguiu editar treinamento -- RLS vazou permissão.');
    }
  } finally {
    await _admin.from('treinamentos').delete().eq('id', id);
  }
}

/// Ao casar (estado_civil -> 'casado'), a categoria vira 'one'
/// (trg_calcular_categoria) e o trigger novo
/// trg_ajustar_ministerios_ao_entrar_one deve entrar sozinho em
/// homens/mulheres (conforme sexo) e tirar do Awake --
/// 2026_casamento_ajusta_ministerios.sql. Roda como o PRÓPRIO Membro
/// editando o perfil (mesmo caminho de editar_perfil_screen.dart ->
/// updateProfileFields()), confirmando que funciona pra edição própria,
/// não só quando o admin edita.
Future<void> _testarCasamentoAjustaMinisterios() async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final original = await _admin.from('profiles').select('estado_civil, sexo').eq('id', membroId).single();
  final estadoCivilOriginal = original['estado_civil'] as String?;
  final sexo = original['sexo'] as String?;
  if (sexo != 'masculino' && sexo != 'feminino') {
    throw Exception('Conta de teste do Membro não tem sexo definido -- não dá pra testar o ajuste automático.');
  }
  final ministerioEsperado = sexo == 'masculino' ? 'homens' : 'mulheres';

  final vinculoAwakeOriginal = await _admin
      .from('profile_ministerios')
      .select('papel')
      .eq('profile_id', membroId)
      .eq('ministerio', 'awake')
      .maybeSingle();

  try {
    // Garante uma TRANSICAO de verdade pra 'one' (categoria), mesmo se
    // a conta de teste ja estivesse casada antes desse teste.
    await _clienteMembro.from('profiles').update({'estado_civil': 'solteiro'}).eq('id', membroId);
    await _clienteMembro.from('profiles').update({'estado_civil': 'casado'}).eq('id', membroId);

    final categoriaAtual = await _admin.from('profiles').select('categoria').eq('id', membroId).single();
    if (categoriaAtual['categoria'] != 'one') throw Exception('categoria não virou "one" depois de casar.');

    final vinculoNovo = await _admin
        .from('profile_ministerios')
        .select('papel')
        .eq('profile_id', membroId)
        .eq('ministerio', ministerioEsperado)
        .maybeSingle();
    if (vinculoNovo == null) throw Exception('Não entrou automaticamente em "$ministerioEsperado" ao casar.');

    final aindaNoAwake = await _admin
        .from('profile_ministerios')
        .select('profile_id')
        .eq('profile_id', membroId)
        .eq('ministerio', 'awake')
        .maybeSingle();
    if (aindaNoAwake != null) throw Exception('Continuou no Awake depois de casar (deveria ter saído).');
  } finally {
    // Desfaz tudo: estado civil original, tira do ministerio novo que
    // o teste criou, devolve o vinculo do Awake se ele existia antes.
    await _clienteMembro.from('profiles').update({'estado_civil': estadoCivilOriginal}).eq('id', membroId);
    await _admin.from('profile_ministerios').delete().eq('profile_id', membroId).eq('ministerio', ministerioEsperado);
    if (vinculoAwakeOriginal != null) {
      await _admin.from('profile_ministerios').upsert(
        {'profile_id': membroId, 'ministerio': 'awake', 'papel': vinculoAwakeOriginal['papel']},
        onConflict: 'profile_id,ministerio',
      );
    }
  }
}

Future<void> _testarMinhasContribuicoes() async {
  await _clienteMembro.from('contribuicoes').select().eq('profile_id', _clienteMembro.auth.currentUser!.id);
}

Future<void> _testarMinhasMetas() async {
  final data = await _clienteMembro.rpc('metas_resumo');
  if ((data as List).isEmpty) throw Exception('metas_resumo não devolveu nenhuma linha.');
}

Future<void> _testarListarTreinamentos() async {
  await _clienteMembro.from('treinamentos').select();
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

/// Recalcula a categoria (Genesis/Next/One) de todo mundo -- funcao
/// nova que corrige o bug de categoria nunca atualizar sozinha no
/// aniversario (2026_recalcular_categorias_diario.sql), tambem
/// agendada 1x/dia via pg_cron. So confirma que a funcao roda sem erro.
Future<void> _testarRecalcularCategorias() async {
  await _admin.rpc('recalcular_categorias_diario');
}

// ---------- checagens (conta teste 2: Lider de Areas de Servico) ----------

Future<void> _testarLoginLider() async {
  final senha = _env('TESTE_LIDER_SENHA');
  _clienteLider = SupabaseClient(_url, _anonKey, authOptions: _semPkce);
  final resposta = await _clienteLider.auth.signInWithPassword(email: _emailLider, password: senha);
  if (resposta.session == null) throw Exception('Login não retornou sessão.');
}

/// As 5 areas que a conta 2 lidera (ver 2026_contas_teste.sql).
const _todasAreasServico = ['diaconos', 'louvor', 'danca', 'midia', 'multimidia'];

/// Cria um evento + escala + posicao pra CADA uma das 5 areas que essa
/// conta lidera -- testa eventos_insert, escalas_servico_insert e
/// escala_servico_posicoes_insert via is_lider_ministerio() em todas,
/// nao so numa. Cada evento/escala/posicao e apagado antes de passar
/// pra proxima area.
Future<void> _testarCriarEventoEEscalaTodasAreas() async {
  final userId = _clienteLider.auth.currentUser!.id;

  for (final ministerio in _todasAreasServico) {
    final eventoId = _gerarUuidV4();
    final dataEvento = DateTime.now().add(const Duration(days: 30));
    final dataOcorrencia = dataEvento.toIso8601String().split('T').first;

    await _clienteLider.from('eventos').insert({
      'id': eventoId,
      'titulo': '[Robô de teste] Verificação automática ($ministerio)',
      'data_inicio': dataEvento.toIso8601String(),
      'escopo': ministerio,
      'tipo': 'outro',
      'recorrente': false,
      'criado_por': userId,
    });

    try {
      final escala = await _clienteLider
          .from('escalas_servico')
          .insert({
            'ministerio': ministerio,
            'evento_id': eventoId,
            'data_ocorrencia': dataOcorrencia,
            'criado_por': userId,
          })
          .select('id')
          .single();
      final escalaId = escala['id'] as String;

      try {
        await _clienteLider.from('escala_servico_posicoes').insert({
          'escala_id': escalaId,
          'funcao': '[Robô de teste]',
          'ordem': 999,
        });
      } finally {
        await _admin.from('escala_servico_posicoes').delete().eq('escala_id', escalaId);
        await _admin.from('escalas_servico').delete().eq('id', escalaId);
      }
    } finally {
      await _admin.from('eventos').delete().eq('id', eventoId);
    }
  }
}

/// So dos Diaconos: escala_servico_casais (lembrar par) -- upsert
/// idempotente, testa a RLS dessa tabela separada.
Future<void> _testarCasalDiaconos() async {
  // A tabela tem CHECK (profile_id_a < profile_id_b) -- ordem canonica
  // pra nunca duplicar o par como A-B e B-A. O app de verdade
  // (escala_servico_service.dart: salvarPar()) sempre ordena os dois
  // ids antes de montar o insert; o teste precisa fazer o mesmo.
  final ids = [_clienteLider.auth.currentUser!.id, _clienteMembro.auth.currentUser!.id]..sort();

  await _clienteLider.from('escala_servico_casais').upsert(
    {
      'ministerio': 'diaconos',
      'profile_id_a': ids[0],
      'profile_id_b': ids[1],
      'atualizado_em': DateTime.now().toIso8601String(),
    },
    onConflict: 'ministerio,profile_id_a,profile_id_b',
  );
  await _admin
      .from('escala_servico_casais')
      .delete()
      .eq('ministerio', 'diaconos')
      .eq('profile_id_a', ids[0])
      .eq('profile_id_b', ids[1]);
}

/// O ponto inteiro da escala: cria evento+escala+posicao de "louvor",
/// atribui o Membro de teste na posicao (definirPessoa), e confere que
/// a MESMA consulta que EscalaServicoService.buscarMinhaEscala() usa
/// (a que alimenta a tarja "Você está escalado(a)" na tela de Início)
/// devolve essa posicao pro Membro. Roda como Membro de proposito --
/// e exatamente quem ve a tarja, nao o lider que atribuiu.
Future<void> _testarEscaladoApareceNaInicio() async {
  final liderUserId = _clienteLider.auth.currentUser!.id;
  final membroUserId = _clienteMembro.auth.currentUser!.id;
  final eventoId = _gerarUuidV4();
  final dataEvento = DateTime.now().add(const Duration(days: 30));
  final dataOcorrencia = dataEvento.toIso8601String().split('T').first;

  await _clienteLider.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Verificação automática',
    'data_inicio': dataEvento.toIso8601String(),
    'escopo': 'louvor',
    'tipo': 'outro',
    'recorrente': false,
    'criado_por': liderUserId,
  });

  try {
    final escala = await _clienteLider
        .from('escalas_servico')
        .insert({
          'ministerio': 'louvor',
          'evento_id': eventoId,
          'data_ocorrencia': dataOcorrencia,
          'criado_por': liderUserId,
        })
        .select('id')
        .single();
    final escalaId = escala['id'] as String;

    try {
      final posicao = await _clienteLider
          .from('escala_servico_posicoes')
          .insert({'escala_id': escalaId, 'funcao': '[Robô de teste]', 'ordem': 999})
          .select('id')
          .single();

      await _clienteLider
          .from('escala_servico_posicoes')
          .update({'profile_id': membroUserId})
          .eq('id', posicao['id']);

      // Mesma consulta de EscalaServicoService.buscarMinhaEscala(),
      // rodando com a sessao do MEMBRO (sujeita a RLS de verdade).
      final minhaEscala = await _clienteMembro
          .from('escala_servico_posicoes')
          .select('funcao, escalas_servico!inner(evento_id, data_ocorrencia, ministerio)')
          .eq('profile_id', membroUserId)
          .gte('escalas_servico.data_ocorrencia', dataOcorrencia)
          .lte('escalas_servico.data_ocorrencia', dataOcorrencia);

      final apareceu = (minhaEscala as List)
          .any((e) => ((e as Map<String, dynamic>)['escalas_servico'] as Map)['evento_id'] == eventoId);
      if (!apareceu) {
        throw Exception('Membro escalado não apareceu na consulta que alimenta a tarja da Início.');
      }
    } finally {
      await _admin.from('escala_servico_posicoes').delete().eq('escala_id', escalaId);
      await _admin.from('escalas_servico').delete().eq('id', escalaId);
    }
  } finally {
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Editar SO UMA ocorrencia de um evento recorrente (event_detail_
/// screen.dart + event_form_screen.dart, feature de hoje): marca
/// excecao na serie original (mesma RPC que excluir so uma data) e
/// cria um evento avulso novo com titulo editado, so pra essa data.
Future<void> _testarEditarOcorrenciaUnica() async {
  final userId = _clienteLider.auth.currentUser!.id;
  final eventoOriginalId = _gerarUuidV4();
  final dataOcorrencia = DateTime.now().add(const Duration(days: 21));

  await _clienteLider.from('eventos').insert({
    'id': eventoOriginalId,
    'titulo': '[Robô de teste] Série recorrente',
    'data_inicio': dataOcorrencia.toIso8601String(),
    'escopo': 'louvor',
    'tipo': 'outro',
    'recorrente': true,
    'criado_por': userId,
  });

  try {
    // "Só esta data": marca excecao na serie original...
    await _clienteLider.rpc('excluir_ocorrencia_evento', params: {
      'p_evento_id': eventoOriginalId,
      'p_data': dataOcorrencia.toIso8601String().split('T').first,
    });

    final original = await _admin.from('eventos').select('excecoes').eq('id', eventoOriginalId).single();
    final excecoes = (original['excecoes'] as List?) ?? [];
    if (excecoes.isEmpty) {
      throw Exception('excluir_ocorrencia_evento não gravou a exceção na série original.');
    }

    // ...e cria o evento avulso novo, so pra essa data, com dado editado.
    final eventoAvulsoId = _gerarUuidV4();
    await _clienteLider.from('eventos').insert({
      'id': eventoAvulsoId,
      'titulo': '[Robô de teste] Só esta data (editado)',
      'data_inicio': dataOcorrencia.toIso8601String(),
      'escopo': 'louvor',
      'tipo': 'outro',
      'recorrente': false,
      'criado_por': userId,
    });
    await _admin.from('eventos').delete().eq('id', eventoAvulsoId);
  } finally {
    await _admin.from('eventos').delete().eq('id', eventoOriginalId);
  }
}

/// "Toda a série": UPDATE comum na linha do evento recorrente (mexe em
/// TODAS as ocorrencias futuras de uma vez, ao contrario da excecao de
/// _testarEditarOcorrenciaUnica). Testa eventos_update pro Lider com o
/// CLIENTE REAL dele (nao o bypass de limpeza).
Future<void> _testarEditarEventoTodaSerie() async {
  final userId = _clienteLider.auth.currentUser!.id;
  final eventoId = _gerarUuidV4();

  await _clienteLider.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Série recorrente',
    'data_inicio': DateTime.now().add(const Duration(days: 21)).toIso8601String(),
    'escopo': 'louvor',
    'tipo': 'outro',
    'recorrente': true,
    'criado_por': userId,
  });

  try {
    await _clienteLider.from('eventos').update({'titulo': '[Robô de teste] Série editada'}).eq('id', eventoId);

    final atual = await _admin.from('eventos').select('titulo').eq('id', eventoId).single();
    if (atual['titulo'] != '[Robô de teste] Série editada') {
      throw Exception('eventos_update não persistiu a edição.');
    }
  } finally {
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Apaga a serie INTEIRA (nao so uma ocorrencia) -- testa eventos_delete
/// pro Lider com o cliente real dele, nao o bypass de limpeza que os
/// outros testes usam pra se auto-limpar.
Future<void> _testarApagarEventoTodaSerie() async {
  final userId = _clienteLider.auth.currentUser!.id;
  final eventoId = _gerarUuidV4();

  await _clienteLider.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Pra apagar',
    'data_inicio': DateTime.now().add(const Duration(days: 21)).toIso8601String(),
    'escopo': 'louvor',
    'tipo': 'outro',
    'recorrente': true,
    'criado_por': userId,
  });

  await _clienteLider.from('eventos').delete().eq('id', eventoId);

  final restante = await _admin.from('eventos').select('id').eq('id', eventoId).maybeSingle();
  if (restante != null) {
    // Nao conseguiu apagar pela RLS -- limpa com o bypass mesmo assim,
    // pra nao deixar sujeira, e reporta a falha.
    await _admin.from('eventos').delete().eq('id', eventoId);
    throw Exception('eventos_delete não apagou o evento (ainda existe).');
  }
}

/// Lider cria, edita e apaga um MODELO de escala Awake (a linha em
/// "escalas" em si -- shift_form_screen.dart/ShiftService.
/// createShiftTemplate/updateShiftTemplate/deleteShiftTemplate),
/// diferente de _comEscalaAwakeDeHoje que so monta cenario via bypass.
/// Confirma que escalas_insert/update/delete liberam "qualquer lider",
/// nao so admin (is_admin() OR is_lider_de_algum_ministerio()).
Future<void> _testarLiderCriarEditarApagarModeloEscalaAwake() async {
  final escalaId = _gerarUuidV4();
  final dataStr = DateTime.now().add(const Duration(days: 10)).toIso8601String().split('T').first;

  await _clienteLider.from('escalas').insert({
    'id': escalaId,
    'nome': '[Robô de teste] Modelo de escala',
    'area_id': null,
    'data': dataStr,
    'horario_inicio': '09:00',
    'horario_fim': '10:00',
    'vagas': 3,
    'recorrente': false,
  });

  try {
    await _clienteLider.from('escalas').update({'vagas': 5}).eq('id', escalaId);
    final atual = await _admin.from('escalas').select('vagas').eq('id', escalaId).single();
    if (atual['vagas'] != 5) throw Exception('escalas_update não persistiu a edição.');

    await _clienteLider.from('escalas').delete().eq('id', escalaId);
    final restante = await _admin.from('escalas').select('id').eq('id', escalaId).maybeSingle();
    if (restante != null) throw Exception('escalas_delete não apagou o modelo (ainda existe).');
  } finally {
    await _admin.from('escalas').delete().eq('id', escalaId);
  }
}

/// Le os inscritos de uma ocorrencia de escala Awake -- mesma consulta
/// de ShiftService.listSignupsForOccurrence(), que tambem alimenta o
/// botao de copiar pro WhatsApp na tela de inscritos. Confirma que
/// inscricoes_select libera is_lider_de_algum_ministerio(), nao so o
/// proprio inscrito. (O copia-e-cola de escala SEMANAL/MENSAL dos
/// ministerios de servico usa escala_servico_posicoes por baixo, ja
/// coberto por _testarCriarEventoEEscalaTodasAreas/
/// _testarEscaladoApareceNaInicio -- e o mesmo "Copiar pro WhatsApp"
/// que ja existia em escala_servico_screen.dart/
/// escala_grade_screen.dart antes de hoje.)
Future<void> _testarLiderVerInscritosEscala() async {
  await _comEscalaAwakeDeHoje(
    areaId: null,
    dentroDoCenario: (escalaId, dataStr) async {
      final inscritos = await _clienteLider
          .from('inscricoes')
          .select('id, status, profiles(nome)')
          .eq('escala_id', escalaId)
          .eq('data_ocorrencia', dataStr)
          .inFilter('status', ['inscrito', 'check_in_feito']);
      if ((inscritos as List).isEmpty) {
        throw Exception('Líder não viu nenhum inscrito na ocorrência (deveria ver ao menos o Membro de teste).');
      }
    },
  );
}

/// Negativo: Lider de Areas de Servico tentando criar evento de escopo
/// que ele NAO lidera (so lidera as 5 areas em _todasAreasServico) --
/// is_lider_ministerio('homens') deve ser falso pra essa conta, RLS
/// deve bloquear.
Future<void> _testarLiderNaoPodeCriarEventoForaDoQueLidera() async {
  final eventoId = _gerarUuidV4();
  try {
    await _clienteLider.from('eventos').insert({
      'id': eventoId,
      'titulo': '[Robô de teste] Não deveria conseguir',
      'data_inicio': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'escopo': 'homens',
      'tipo': 'outro',
      'recorrente': false,
    });
  } finally {
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

Future<void> _testarDashboardMinisterio() async {
  // Mesma consulta base que dashboard_ministerio_screen.dart faz --
  // so chegar sem excecao ja confirma que a RLS de profile_ministerios
  // libera o lider ver quem esta no proprio ministerio.
  await _clienteLider.from('profile_ministerios').select('profile_id, criado_em').eq('ministerio', 'louvor');
}

// ---------- checagens (conta teste 3: Admin) ----------

Future<void> _testarLoginAdmin() async {
  final senha = _env('TESTE_ADMIN_SENHA');
  _clienteAdmin = SupabaseClient(_url, _anonKey, authOptions: _semPkce);
  final resposta = await _clienteAdmin.auth.signInWithPassword(email: _emailAdmin, password: senha);
  if (resposta.session == null) throw Exception('Login não retornou sessão.');
}

Future<void> _testarVerTodosUsuarios() async {
  // Admin ve profiles de todo mundo (tela de Usuarios do gestao.html) --
  // um Membro so veria o proprio.
  final data = await _clienteAdmin.from('profiles').select('id').limit(2);
  if ((data as List).isEmpty) throw Exception('Admin não conseguiu ver nenhum profile.');
}

Future<void> _testarCriarEventoAdmin() async {
  final userId = _clienteAdmin.auth.currentUser!.id;
  final eventoId = _gerarUuidV4();

  await _clienteAdmin.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Verificação automática',
    'data_inicio': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    'escopo': 'igreja',
    'tipo': 'outro',
    'recorrente': false,
    'criado_por': userId,
  });
  await _admin.from('eventos').delete().eq('id', eventoId);
}

/// Editar e apagar evento pelo cliente REAL do Admin (nao o bypass de
/// limpeza) -- escopo 'igreja', que só admin gerencia (nenhum
/// ministerioCorrespondente).
Future<void> _testarEditarEApagarEventoAdmin() async {
  final userId = _clienteAdmin.auth.currentUser!.id;
  final eventoId = _gerarUuidV4();

  await _clienteAdmin.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Pra editar/apagar',
    'data_inicio': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    'escopo': 'igreja',
    'tipo': 'outro',
    'recorrente': false,
    'criado_por': userId,
  });

  try {
    await _clienteAdmin.from('eventos').update({'titulo': '[Robô de teste] Editado'}).eq('id', eventoId);
    final atual = await _admin.from('eventos').select('titulo').eq('id', eventoId).single();
    if (atual['titulo'] != '[Robô de teste] Editado') throw Exception('eventos_update não persistiu a edição.');

    await _clienteAdmin.from('eventos').delete().eq('id', eventoId);
    final restante = await _admin.from('eventos').select('id').eq('id', eventoId).maybeSingle();
    if (restante != null) throw Exception('eventos_delete não apagou o evento (ainda existe).');
  } finally {
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Testa outdoors_insert (is_admin()) -- feature nova de hoje. O
/// delete de verdade fica em _testarApagarOutdoor, testado pelo
/// cliente real, nao esse bypass de limpeza.
Future<void> _testarCriarOutdoor() async {
  final userId = _clienteAdmin.auth.currentUser!.id;
  final outdoorId = _gerarUuidV4();

  await _clienteAdmin.from('outdoors').insert({
    'id': outdoorId,
    'imagem_url': 'https://exemplo.invalido/robo-teste.jpg',
    'tipo': 'sempre',
    'ativo': true,
    'criado_por': userId,
  });
  await _admin.from('outdoors').delete().eq('id', outdoorId);
}

/// Editar e apagar outdoor pelo cliente REAL do Admin (nao o bypass de
/// limpeza) -- testa outdoors_update/outdoors_delete de verdade.
Future<void> _testarEditarEApagarOutdoor() async {
  final userId = _clienteAdmin.auth.currentUser!.id;
  final outdoorId = _gerarUuidV4();

  await _clienteAdmin.from('outdoors').insert({
    'id': outdoorId,
    'imagem_url': 'https://exemplo.invalido/robo-teste.jpg',
    'tipo': 'sempre',
    'ativo': true,
    'criado_por': userId,
  });

  try {
    await _clienteAdmin.from('outdoors').update({'ativo': false}).eq('id', outdoorId);
    final atual = await _admin.from('outdoors').select('ativo').eq('id', outdoorId).single();
    if (atual['ativo'] != false) throw Exception('outdoors_update não persistiu a edição.');

    await _clienteAdmin.from('outdoors').delete().eq('id', outdoorId);
    final restante = await _admin.from('outdoors').select('id').eq('id', outdoorId).maybeSingle();
    if (restante != null) throw Exception('outdoors_delete não apagou o outdoor (ainda existe).');
  } finally {
    // So executa de verdade se o delete acima falhou e deixou sujeira.
    await _admin.from('outdoors').delete().eq('id', outdoorId);
  }
}

/// Testa contribuicoes_insert -- ate ontem so is_admin_financeiro()
/// conseguia, hoje qualquer admin (RLS unificada, ver
/// 2026_contribuicoes_admin.sql). Lanca pra conta teste 1 (Membro).
Future<void> _testarLancarContribuicao() async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final inserido = await _clienteAdmin
      .from('contribuicoes')
      .insert({
        'profile_id': membroId,
        'data': DateTime.now().toIso8601String().split('T').first,
        'valor': 1.0,
        'meio_pagamento': 'pix',
        'observacao': '[Robô de teste] Verificação automática -- pode ignorar.',
        'lancado_por': _clienteAdmin.auth.currentUser!.id,
      })
      .select('id')
      .single();
  await _admin.from('contribuicoes').delete().eq('id', inserido['id'] as String);
}

Future<void> _testarCaixaDeEntrada() async {
  // Mesma consulta que admin_mensagens_screen.dart faz -- admin ve
  // pedidos de oracao e testemunhos de todo mundo.
  await _clienteAdmin.from('pedidos_oracao').select('id').limit(5);
  await _clienteAdmin.from('testemunhos').select('id').limit(5);
}

Future<void> _testarVerVisitantesPrimeiraVez() async {
  // Mesma consulta que admin_visitantes_screen.dart faz.
  await _clienteAdmin.from('visitantes_primeira_vez').select('id, dados').limit(5);
}

/// Cria, atualiza e apaga um treinamento (TreinamentoService) -- so
/// admin gerencia (treinamentos_screen.dart: FAB só aparece isAdmin).
Future<void> _testarCrudTreinamento() async {
  final criado = await _clienteAdmin
      .from('treinamentos')
      .insert({
        'titulo': '[Robô de teste] Verificação automática',
        'descricao': 'Pode ignorar.',
        'url_video': 'https://youtube.com/watch?v=robo_de_teste',
      })
      .select('id')
      .single();
  final id = criado['id'] as String;

  try {
    await _clienteAdmin.from('treinamentos').update({'titulo': '[Robô de teste] Editado'}).eq('id', id);
  } finally {
    await _clienteAdmin.from('treinamentos').delete().eq('id', id);
  }
}

/// Admin promove alguem a Admin e depois reverte (gestao.html: botao
/// "Tornar admin"/"Remover admin" na tela de Usuarios) -- so
/// profiles_update_admin (is_admin()), sem RPC/function nenhuma.
Future<void> _testarPromoverERemoverAdmin() async {
  final membroId = _clienteMembro.auth.currentUser!.id;

  await _clienteAdmin.from('profiles').update({'papel': 'admin'}).eq('id', membroId);
  try {
    final atual = await _admin.from('profiles').select('papel').eq('id', membroId).single();
    if (atual['papel'] != 'admin') throw Exception('profiles_update_admin não promoveu o Membro.');
  } finally {
    // Sempre reverte -- as outras fases do robo esperam o Membro de
    // teste com papel='membro'.
    await _admin.from('profiles').update({'papel': 'membro'}).eq('id', membroId);
  }
}

/// Admin edita o perfil de OUTRA pessoa (gestao.html: "Editar perfil"
/// na tela de Usuarios) e reverte -- mesma policy profiles_update_admin.
Future<void> _testarEditarPerfilDeOutraPessoa() async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final original = await _admin.from('profiles').select('telefone').eq('id', membroId).single();
  final telefoneOriginal = original['telefone'] as String?;

  try {
    await _clienteAdmin.from('profiles').update({'telefone': '(21) 90000-0000'}).eq('id', membroId);
    final atual = await _admin.from('profiles').select('telefone').eq('id', membroId).single();
    if (atual['telefone'] != '(21) 90000-0000') {
      throw Exception('profiles_update_admin não editou o telefone do Membro.');
    }
  } finally {
    await _admin.from('profiles').update({'telefone': telefoneOriginal}).eq('id', membroId);
  }
}

/// Admin apaga a conta de OUTRA pessoa (gestao.html: "Apagar conta" na
/// tela de Usuarios -> Edge Function admin-apagar-usuario). Cria uma
/// conta descartavel só pra isso (nunca uma das 4 fixas!) e confirma
/// que ela some de auth.users de verdade.
Future<void> _testarAdminApagarContaDeUsuario() async {
  final clienteTemp = SupabaseClient(_url, _anonKey, authOptions: _semPkce);
  final marca = DateTime.now().millisecondsSinceEpoch;
  final emailDescartavel = 'teste.descartavel.admin.$marca@shallom.app';
  final senhaDescartavel = 'Descartavel$marca!';

  final resposta = await clienteTemp.auth.signUp(email: emailDescartavel, password: senhaDescartavel);
  final idDescartavel = resposta.user?.id;
  if (idDescartavel == null) throw Exception('Cadastro descartável não retornou usuário.');
  await _admin.from('profiles').update({'eh_conta_teste': true}).eq('id', idDescartavel);

  final resultado = await _clienteAdmin.functions.invoke(
    'admin-apagar-usuario',
    body: {'profileId': idDescartavel},
  );
  if (resultado.status != 200) {
    // Se a function falhar por algum motivo, ainda tenta limpar a
    // conta descartavel via bypass, pra nao deixar sujeira.
    await _admin.auth.admin.deleteUser(idDescartavel);
    throw Exception('admin-apagar-usuario devolveu status ${resultado.status}: ${resultado.data}');
  }

  // Confirma que sumiu de auth.users de verdade -- getUserById lanca
  // excecao (nao devolve null) quando o usuario nao existe mais.
  try {
    await _admin.auth.admin.getUserById(idDescartavel);
    throw Exception('Usuário descartável ainda existe depois do admin-apagar-usuario.');
  } catch (e) {
    if (e.toString().contains('ainda existe')) rethrow;
    // Qualquer outro erro aqui (ex: "User not found") É o resultado
    // esperado -- confirma que a conta sumiu de verdade.
  }
}

/// Admin marca como lido e apaga uma linha de uma tabela de mensagem
/// (pedidos_oracao/testemunhos/visitantes_primeira_vez) -- mesmos
/// botoes "Marcar como lido"/"Apagar" de admin_mensagens_screen.dart e
/// admin_visitantes_screen.dart. [dadosInsercao] ja inclui quem e o
/// dono da linha.
Future<void> _testarAdminMarcarLidoEApagar(String tabela, Map<String, dynamic> dadosInsercao) async {
  final criado = await _admin.from(tabela).insert(dadosInsercao).select('id').single();
  final id = criado['id'] as String;

  try {
    await _clienteAdmin.from(tabela).update({'lido': true}).eq('id', id);
    final atual = await _admin.from(tabela).select('lido').eq('id', id).single();
    if (atual['lido'] != true) throw Exception('Admin não conseguiu marcar "$tabela" como lido.');

    await _clienteAdmin.from(tabela).delete().eq('id', id);
    final restante = await _admin.from(tabela).select('id').eq('id', id).maybeSingle();
    if (restante != null) throw Exception('Admin não conseguiu apagar de "$tabela".');
  } finally {
    await _admin.from(tabela).delete().eq('id', id);
  }
}

/// Admin ve, marca como lido e apaga um Questionario de Novo Servo
/// (aparece junto com pedidos/testemunhos em admin_mensagens_screen.dart)
/// -- testa questionarios_novo_servo_select/update/delete (is_admin()).
Future<void> _testarAdminGerenciarQuestionario() async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final criado = await _admin
      .from('questionarios_novo_servo')
      .insert({
        'profile_id': membroId,
        'respostas': {'Por que quer servir?': '[Robô de teste] Alvo de teste.'},
      })
      .select('id')
      .single();
  final id = criado['id'] as String;

  try {
    final visto = await _clienteAdmin.from('questionarios_novo_servo').select('id').eq('id', id).maybeSingle();
    if (visto == null) throw Exception('Admin não conseguiu ver o questionário (select bloqueado).');

    await _clienteAdmin.from('questionarios_novo_servo').update({'lido': true}).eq('id', id);
    final atual = await _admin.from('questionarios_novo_servo').select('lido').eq('id', id).single();
    if (atual['lido'] != true) throw Exception('Admin não conseguiu marcar o questionário como lido.');

    await _clienteAdmin.from('questionarios_novo_servo').delete().eq('id', id);
    final restante = await _admin.from('questionarios_novo_servo').select('id').eq('id', id).maybeSingle();
    if (restante != null) throw Exception('Admin não conseguiu apagar o questionário.');
  } finally {
    await _admin.from('questionarios_novo_servo').delete().eq('id', id);
  }
}

/// Admin adiciona o Membro de teste a um ministério que ele ainda não
/// tem vínculo, promove pra líder, e por fim tira ele do ministério
/// por completo -- mesmo fluxo dos botões "+ Membro"/"+ Líder", do
/// chip clicável (lider<->membro) e do "✕" (remover) em gestao.html
/// (Usuários). Testa profile_ministerios_insert/_update/_delete pra
/// is_admin().
Future<void> _testarAdminGerenciarMinisterioDeUsuario() async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  const ministerio = 'coral';

  try {
    await _clienteAdmin.from('profile_ministerios').upsert(
      {'profile_id': membroId, 'ministerio': ministerio, 'papel': 'membro'},
      onConflict: 'profile_id,ministerio',
    );
    var atual = await _admin
        .from('profile_ministerios')
        .select('papel')
        .eq('profile_id', membroId)
        .eq('ministerio', ministerio)
        .single();
    if (atual['papel'] != 'membro') throw Exception('profile_ministerios_insert não adicionou o Membro.');

    await _clienteAdmin
        .from('profile_ministerios')
        .update({'papel': 'lider'})
        .eq('profile_id', membroId)
        .eq('ministerio', ministerio);
    atual = await _admin
        .from('profile_ministerios')
        .select('papel')
        .eq('profile_id', membroId)
        .eq('ministerio', ministerio)
        .single();
    if (atual['papel'] != 'lider') throw Exception('profile_ministerios_update não promoveu a líder.');

    await _clienteAdmin
        .from('profile_ministerios')
        .delete()
        .eq('profile_id', membroId)
        .eq('ministerio', ministerio);
    final restante = await _admin
        .from('profile_ministerios')
        .select('profile_id')
        .eq('profile_id', membroId)
        .eq('ministerio', ministerio)
        .maybeSingle();
    if (restante != null) throw Exception('profile_ministerios_delete não removeu o vínculo (ainda existe).');
  } finally {
    await _admin.from('profile_ministerios').delete().eq('profile_id', membroId).eq('ministerio', ministerio);
  }
}

/// Anexa um "PDF" (bytes fake, so testando o caminho de storage +
/// tabela, nao o conteudo) a um video-id fake -- mesmo fluxo de "Meus
/// Conteúdos" (meus_conteudos_screen.dart -> VideoMaterialService).
Future<void> _testarAnexarMaterial() async {
  final videoId = 'robo-teste-${_gerarUuidV4()}';
  final caminho = 'materiais/$videoId.pdf';
  final bytesFake = [0x25, 0x50, 0x44, 0x46]; // "%PDF" -- so pra nao subir arquivo vazio

  await _clienteAdmin.storage.from('materiais-conteudo').uploadBinary(
        caminho,
        Uint8List.fromList(bytesFake),
        fileOptions: const FileOptions(upsert: true),
      );
  final url = _clienteAdmin.storage.from('materiais-conteudo').getPublicUrl(caminho);

  try {
    await _clienteAdmin.from('video_materiais').upsert(
      {
        'video_youtube_id': videoId,
        'material_url': url,
        'nome_arquivo': 'robo-teste.pdf',
        'criado_por': _clienteAdmin.auth.currentUser!.id,
      },
      onConflict: 'video_youtube_id',
    );
  } finally {
    await _admin.from('video_materiais').delete().eq('video_youtube_id', videoId);
    await _clienteAdmin.storage.from('materiais-conteudo').remove([caminho]);
  }
}

/// Check-in por QR Code numa escala Awake -- exige que a pessoa esteja
/// inscrita naquela ocorrencia (checkin_scanner_screen.dart). Monta o
/// cenario (Membro inscrito numa escala de teste) e [quemFazCheckin]
/// faz o check-in via a mesma RPC que o app usa. check_in_member() usa
/// is_admin() OR is_lider_de_algum_ministerio() -- ou seja, QUALQUER
/// lider pode fazer check-in, nao so lider do Awake -- por isso o
/// mesmo teste roda com o Admin e com o Lider de Areas de Servico.
Future<void> _testarCheckInEscala(SupabaseClient quemFazCheckin) async {
  await _comEscalaAwakeDeHoje(
    areaId: null,
    dentroDoCenario: (escalaId, dataStr) async {
      final perfil = await _admin
          .from('profiles')
          .select('qr_code_id')
          .eq('id', _clienteMembro.auth.currentUser!.id)
          .single();

      final nome = await quemFazCheckin.rpc('check_in_member', params: {
        'p_qr_code_id': perfil['qr_code_id'],
        'p_escala_id': escalaId,
        'p_data_ocorrencia': dataStr,
      });
      if (nome == null || (nome as String).isEmpty) {
        throw Exception('check_in_member não devolveu nome nenhum.');
      }
    },
  );
}

/// Check-in num evento do calendario -- NAO exige inscricao previa
/// (diferente do check-in de escala). check_in_evento() usa a mesma
/// regra "qualquer lider" que check_in_member().
Future<void> _testarCheckInEvento(SupabaseClient quemFazCheckin) async {
  final eventoId = _gerarUuidV4();
  await _admin.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Verificação automática',
    'data_inicio': DateTime.now().toIso8601String(),
    'escopo': 'igreja',
    'tipo': 'outro',
    'recorrente': false,
  });

  try {
    final perfil = await _admin
        .from('profiles')
        .select('qr_code_id')
        .eq('id', _clienteMembro.auth.currentUser!.id)
        .single();

    final nome = await quemFazCheckin.rpc('check_in_evento', params: {
      'p_qr_code_id': perfil['qr_code_id'],
      'p_evento_id': eventoId,
      'p_data_ocorrencia': DateTime.now().toIso8601String().split('T').first,
    });
    if (nome == null || (nome as String).isEmpty) {
      throw Exception('check_in_evento não devolveu nome nenhum.');
    }
  } finally {
    await _admin.from('presencas_eventos').delete().eq('evento_id', eventoId);
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Le o catalogo de funcoes (escala_servico_funcoes_catalogo) das 5
/// areas -- e o que alimenta tanto as colunas da Escala Mensal
/// (escala_grade_screen.dart) quanto o formulario da Escala Semanal
/// (EscalaServicoService.listarCatalogo/buscarOuCriarEscala). A
/// escrita em si (criar escala/posicao/atribuir pessoa) ja e testada
/// em _testarCriarEventoEEscalaTodasAreas e
/// _testarEscaladoApareceNaInicio -- mensal e semanal usam as MESMAS
/// tabelas por baixo, só a apresentação (grade vs. formulário) muda.
Future<void> _testarCatalogoFuncoesTodasAreas() async {
  for (final ministerio in _todasAreasServico) {
    await _clienteLider
        .from('escala_servico_funcoes_catalogo')
        .select('funcao, ordem')
        .eq('ministerio', ministerio)
        .order('ordem');
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
  _emailLider = _env('TESTE_LIDER_EMAIL');
  _emailAdmin = _env('TESTE_ADMIN_EMAIL');

  _admin = SupabaseClient(_url, serviceKey, authOptions: _semPkce);

  final rodadaId = _gerarUuidV4();
  stdout.writeln('=== Rodada $rodadaId ===');

  final resultados = <_Resultado>[];

  // ---------- Fase 1: Membro comum ----------
  // Login precisa vir primeiro -- as demais checagens dessa fase
  // dependem de _clienteMembro estar autenticado. O check-in da Fase 3
  // tambem depende do Membro estar logado (usa o qr_code_id dele).
  final resultadoLoginMembro = await _rodar('membro_login', _testarLogin);
  resultados.add(resultadoLoginMembro);

  if (resultadoLoginMembro.sucesso) {
    resultados.add(await _rodar('membro_ver_inicio', _testarListaEventos));
    resultados.add(await _rodar('membro_ver_calendario', _testarListaEventos));
    resultados.add(await _rodar('membro_qr_code_proprio', _testarQrCode));
    resultados.add(await _rodar('membro_enviar_pedido_oracao', _testarPedidoOracao));
    resultados.add(await _rodar('membro_enviar_testemunho', _testarTestemunho));
    resultados.add(await _rodar('membro_enviar_questionario_novo_servo', _testarEnviarQuestionarioNovoServo));
    resultados.add(await _rodar('membro_casamento_ajusta_ministerios', _testarCasamentoAjustaMinisterios));
    resultados.add(await _rodar('membro_editar_perfil', _testarEditarPerfil));
    resultados.add(await _rodar('membro_cadastro_primeira_vez', _testarCadastroPrimeiraVez));
    resultados.add(await _rodar('membro_inscrever_e_cancelar_escala', _testarInscreverECancelarEscalaAwake));
    resultados.add(await _rodar('membro_cadastrar_filho', _testarCadastrarFilho));
    resultados.add(await _rodar('membro_apagar_filho', _testarApagarFilho));
    resultados.add(await _rodar('membro_minhas_contribuicoes', _testarMinhasContribuicoes));
    resultados.add(await _rodar('membro_minhas_metas', _testarMinhasMetas));
    resultados.add(await _rodar('membro_listar_treinamentos', _testarListarTreinamentos));
    resultados.add(await _rodarEsperandoFalha('membro_nao_pode_criar_evento', _testarMembroNaoPodeCriarEvento));
    resultados.add(await _rodar('membro_nao_pode_editar_treinamento', _testarMembroNaoPodeEditarTreinamento));
  } else {
    stdout.writeln('Login do Membro falhou -- pulando checagens que dependem dessa sessão.');
  }

  // Essas nao dependem do login da conta teste 1.
  resultados.add(await _rodar('cadastro_conta_nova', _testarCadastro));
  resultados.add(await _rodar('gerar_pix_dizimo_oferta', _testarPixDizimoEOferta));
  resultados.add(await _rodar('recalcular_categorias', _testarRecalcularCategorias));

  // ---------- Fase 2: Lider de Areas de Servico ----------
  final resultadoLoginLider = await _rodar('lider_login', _testarLoginLider);
  resultados.add(resultadoLoginLider);

  if (resultadoLoginLider.sucesso) {
    resultados.add(await _rodar('lider_criar_evento_e_escala_todas_areas', _testarCriarEventoEEscalaTodasAreas));
    resultados.add(await _rodar('lider_catalogo_funcoes_todas_areas', _testarCatalogoFuncoesTodasAreas));
    resultados.add(await _rodar('lider_dashboard_ministerio', _testarDashboardMinisterio));
    resultados.add(await _rodar('lider_editar_ocorrencia_unica', _testarEditarOcorrenciaUnica));
    resultados.add(await _rodar('lider_editar_evento_toda_serie', _testarEditarEventoTodaSerie));
    resultados.add(await _rodar('lider_apagar_evento_toda_serie', _testarApagarEventoTodaSerie));
    resultados.add(await _rodar('lider_modelo_escala_awake', _testarLiderCriarEditarApagarModeloEscalaAwake));
    resultados.add(await _rodarEsperandoFalha(
        'lider_nao_pode_criar_evento_fora_do_que_lidera', _testarLiderNaoPodeCriarEventoForaDoQueLidera));
    if (resultadoLoginMembro.sucesso) {
      // Dependem do Membro tambem estar logado.
      resultados.add(await _rodar('lider_casal_diaconos', _testarCasalDiaconos));
      resultados.add(await _rodar('lider_escalado_aparece_na_inicio', _testarEscaladoApareceNaInicio));
      resultados.add(await _rodar('lider_ver_inscritos_escala', _testarLiderVerInscritosEscala));
      // Lider (de qualquer ministerio, nao so Awake -- ver comentario
      // em _testarCheckInEscala) tambem pode fazer check-in.
      resultados.add(await _rodar('lider_check_in_escala', () => _testarCheckInEscala(_clienteLider)));
      resultados.add(await _rodar('lider_check_in_evento', () => _testarCheckInEvento(_clienteLider)));
    }
  } else {
    stdout.writeln('Login do Líder falhou -- pulando checagens que dependem dessa sessão.');
  }

  // ---------- Fase 3: Admin ----------
  final resultadoLoginAdmin = await _rodar('admin_login', _testarLoginAdmin);
  resultados.add(resultadoLoginAdmin);

  if (resultadoLoginAdmin.sucesso) {
    resultados.add(await _rodar('admin_ver_todos_usuarios', _testarVerTodosUsuarios));
    resultados.add(await _rodar('admin_criar_evento', _testarCriarEventoAdmin));
    resultados.add(await _rodar('admin_editar_apagar_evento', _testarEditarEApagarEventoAdmin));
    resultados.add(await _rodar('admin_criar_outdoor', _testarCriarOutdoor));
    resultados.add(await _rodar('admin_editar_apagar_outdoor', _testarEditarEApagarOutdoor));
    resultados.add(await _rodar('admin_caixa_de_entrada', _testarCaixaDeEntrada));
    resultados.add(await _rodar('admin_ver_visitantes_primeira_vez', _testarVerVisitantesPrimeiraVez));
    resultados.add(await _rodar('admin_crud_treinamento', _testarCrudTreinamento));
    resultados.add(await _rodar('admin_anexar_material', _testarAnexarMaterial));
    if (resultadoLoginMembro.sucesso) {
      // Dependem do Membro estar logado (lancar contribuicao pra ele,
      // fazer check-in usando o qr_code_id dele, marcar como
      // lido/apagar mensagens dele, promover/editar o perfil dele).
      resultados.add(await _rodar('admin_lancar_contribuicao', _testarLancarContribuicao));
      resultados.add(await _rodar('admin_check_in_escala', () => _testarCheckInEscala(_clienteAdmin)));
      resultados.add(await _rodar('admin_check_in_evento', () => _testarCheckInEvento(_clienteAdmin)));
      resultados.add(await _rodar('admin_promover_e_remover_admin', _testarPromoverERemoverAdmin));
      resultados.add(await _rodar('admin_editar_perfil_de_outra_pessoa', _testarEditarPerfilDeOutraPessoa));
      resultados.add(await _rodar('admin_apagar_conta_de_usuario', _testarAdminApagarContaDeUsuario));
      resultados.add(await _rodar('admin_gerenciar_questionario_novo_servo', _testarAdminGerenciarQuestionario));
      resultados.add(await _rodar('admin_gerenciar_ministerio_de_usuario', _testarAdminGerenciarMinisterioDeUsuario));
      final membroId = _clienteMembro.auth.currentUser!.id;
      resultados.add(await _rodar(
          'admin_marcar_lido_e_apagar_pedido_oracao',
          () => _testarAdminMarcarLidoEApagar('pedidos_oracao', {
                'profile_id': membroId,
                'anonimo': false,
                'texto': '[Robô de teste] Alvo de teste.',
              })));
      resultados.add(await _rodar(
          'admin_marcar_lido_e_apagar_testemunho',
          () => _testarAdminMarcarLidoEApagar('testemunhos', {
                'profile_id': membroId,
                'anonimo': false,
                'texto': '[Robô de teste] Alvo de teste.',
              })));
      resultados.add(await _rodar(
          'admin_marcar_lido_e_apagar_visitante',
          () => _testarAdminMarcarLidoEApagar('visitantes_primeira_vez', {
                'registrado_por': membroId,
                'dados': {'Nome completo': '[Robô de teste] Visitante alvo'},
              })));
    }
  } else {
    stdout.writeln('Login do Admin falhou -- pulando checagens que dependem dessa sessão.');
  }

  await _salvarResultados(rodadaId, resultados);

  final falhas = resultados.where((r) => !r.sucesso).toList();
  stdout.writeln('=== ${resultados.length - falhas.length}/${resultados.length} passaram ===');

  if (falhas.isNotEmpty) {
    stderr.writeln('Falharam: ${falhas.map((f) => f.nome).join(', ')}');
    exit(1); // workflow fica vermelho -- GitHub avisa por e-mail sozinho
  }
}
