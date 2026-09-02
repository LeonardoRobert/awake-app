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

/// Código de líder ERRADO deve ser rejeitado (exceção lançada) e NÃO
/// deve criar vínculo nenhum em profile_ministerios -- achado hoje:
/// existiam 2 versões ambíguas de solicitar_papel_lider() ao mesmo
/// tempo (2026_remove_solicitar_papel_lider_antiga.sql apagou a
/// antiga, que só mexia no profiles.papel legado e nunca promovia de
/// verdade via profile_ministerios, além de deixar a chamada ambígua
/// pro PostgREST). NÃO testa o código CERTO aqui de propósito -- o
/// código real de líder não deve aparecer em nenhum arquivo
/// versionado no repositório.
Future<void> _testarCodigoLiderErrado() async {
  const ministerioTeste = 'teatro'; // area que a conta Membro de teste nao lidera
  final membroId = _clienteMembro.auth.currentUser!.id;

  final vinculoAntes = await _admin
      .from('profile_ministerios')
      .select('papel')
      .eq('profile_id', membroId)
      .eq('ministerio', ministerioTeste)
      .maybeSingle();

  var lancouExcecao = false;
  try {
    await _clienteMembro.rpc('solicitar_papel_lider', params: {
      'p_codigo': 'codigo-obviamente-errado-do-robo-de-teste',
      'p_ministerio': ministerioTeste,
    });
  } catch (_) {
    lancouExcecao = true;
  }

  if (!lancouExcecao) throw Exception('Código de líder errado não lançou exceção nenhuma.');

  final vinculoDepois = await _admin
      .from('profile_ministerios')
      .select('papel')
      .eq('profile_id', membroId)
      .eq('ministerio', ministerioTeste)
      .maybeSingle();

  if (vinculoDepois != null && vinculoAntes == null) {
    // Limpa a sujeira antes de reportar a falha.
    await _admin.from('profile_ministerios').delete().eq('profile_id', membroId).eq('ministerio', ministerioTeste);
    throw Exception('Código de líder errado mesmo assim criou vínculo em profile_ministerios.');
  }
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

/// "Agora" em horario de Brasilia (UTC-3 fixo -- o Brasil aboliu
/// horario de verao em 2019, entao um offset fixo e' seguro). Varias
/// funcoes do banco (ex: esta_na_escala_primeira_vez()) calculam
/// "hoje" via `now() at time zone 'America/Sao_Paulo'`, nao em UTC --
/// testes que comparam "hoje"/"ontem" contra esse conceito precisam
/// calcular do mesmo jeito. Sem isso, ha uma janela de ~3h por dia
/// (21h-00h de Brasilia) onde o UTC do servidor do robo (GitHub
/// Actions, roda em UTC) ja virou o dia seguinte mas Brasilia ainda
/// nao -- nessa janela, "ontem" calculado em UTC bate com "hoje" em
/// Brasilia, dando falso positivo/negativo dependendo de quando o
/// robo roda (foi exatamente isso que aconteceu com
/// primeira_vez_so_no_dia numa rodada real).
DateTime _agoraBrasilia() => DateTime.now().toUtc().subtract(const Duration(hours: 3));
String _hojeBrasiliaStr() => _agoraBrasilia().toIso8601String().split('T').first;

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
///
/// "Hoje" aqui e' calculado em horario de Brasilia (ver
/// _hojeBrasiliaStr()) -- funcoes do banco como
/// esta_na_escala_primeira_vez() tambem calculam "hoje" assim, entao
/// precisa bater, senao ha uma janela de ~3h por dia (21h-00h de
/// Brasilia) onde o UTC do servidor do robo ja virou o dia seguinte
/// mas Brasilia ainda nao.
Future<T> _comEscalaAwakeDeHoje<T>({
  required String? areaId,
  required Future<T> Function(String escalaId, String dataStr) dentroDoCenario,
}) async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final escalaId = _gerarUuidV4();
  final dataStr = _hojeBrasiliaStr();

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

/// esta_na_escala_primeira_vez() (formulario "Registrar visitante" no
/// Perfil) so deve liberar no PROPRIO DIA da escala -- antes nao tinha
/// filtro de data nenhum, ficava disponivel pra sempre depois de uma
/// unica inscricao (2026_primeira_vez_so_no_dia.sql corrigiu). Testa
/// os dois lados: escala de ONTEM nao libera mais, escala de HOJE
/// continua liberando.
Future<void> _testarPrimeiraVezSoNoDia() async {
  final escalaOntemId = _gerarUuidV4();
  final dataOntemStr = _agoraBrasilia()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .split('T')
      .first;

  await _admin.from('escalas').insert({
    'id': escalaOntemId,
    'nome': '[Robô de teste]',
    'area_id': _areaPrimeiraVezId,
    'data': dataOntemStr,
    'horario_inicio': '00:00',
    'horario_fim': '23:59',
    'vagas': 1,
    'recorrente': false,
  });

  try {
    await _admin.from('inscricoes').insert({
      'escala_id': escalaOntemId,
      'data_ocorrencia': dataOntemStr,
      'user_id': _clienteMembro.auth.currentUser!.id,
      'status': 'inscrito',
    });

    try {
      final liberadoOntem = await _clienteMembro.rpc('esta_na_escala_primeira_vez') as bool;
      if (liberadoOntem) {
        throw Exception(
            'esta_na_escala_primeira_vez() liberou pra escala de ONTEM -- deveria só liberar no próprio dia.');
      }
    } finally {
      await _admin.from('inscricoes').delete().eq('escala_id', escalaOntemId);
    }
  } finally {
    await _admin.from('escalas').delete().eq('id', escalaOntemId);
  }

  // Confirma que HOJE continua liberando normalmente (nao regrediu).
  await _comEscalaAwakeDeHoje(
    areaId: _areaPrimeiraVezId,
    dentroDoCenario: (escalaId, dataStr) async {
      final liberadoHoje = await _clienteMembro.rpc('esta_na_escala_primeira_vez') as bool;
      if (!liberadoHoje) {
        throw Exception('esta_na_escala_primeira_vez() não liberou pra escala de HOJE.');
      }
    },
  );
}

/// Líder do Awake sempre vê "Registrar visitante", mesmo sem nenhuma
/// inscrição em Primeira Vez -- exceção deliberada em
/// esta_na_escala_primeira_vez(). A conta de teste "Líder" não lidera
/// o Awake por padrão (só as 5 áreas de serviço) -- concede
/// temporariamente, mesmo padrão já usado em outros testes de líder
/// do Awake.
Future<void> _testarPrimeiraVezLiderAwakeSempre() async {
  final liderId = _clienteLider.auth.currentUser!.id;
  final vinculoAwakeOriginal = await _admin
      .from('profile_ministerios')
      .select('papel')
      .eq('profile_id', liderId)
      .eq('ministerio', 'awake')
      .maybeSingle();

  await _admin.from('profile_ministerios').upsert(
    {'profile_id': liderId, 'ministerio': 'awake', 'papel': 'lider'},
    onConflict: 'profile_id,ministerio',
  );

  try {
    final liberado = await _clienteLider.rpc('esta_na_escala_primeira_vez') as bool;
    if (!liberado) {
      throw Exception('esta_na_escala_primeira_vez() não liberou pro líder do Awake (deveria liberar sempre).');
    }
  } finally {
    if (vinculoAwakeOriginal == null) {
      await _admin.from('profile_ministerios').delete().eq('profile_id', liderId).eq('ministerio', 'awake');
    } else {
      await _admin.from('profile_ministerios').upsert(
        {'profile_id': liderId, 'ministerio': 'awake', 'papel': vinculoAwakeOriginal['papel']},
        onConflict: 'profile_id,ministerio',
      );
    }
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

/// Confirma o comportamento E o texto exato da mensagem de horario
/// sobreposto -- achado em producao (14/08): a mensagem tinha um "(a)"
/// que quebrava o match com shifts_screen.dart._mensagemAmigavel(),
/// que procura a substring literal 'ja esta inscrito em outra
/// escala'. Sem esse teste, uma mudanca de texto no SQL pode
/// dessincronizar da tela de novo sem ninguem perceber (a excecao
/// ainda "funciona", so' a mensagem bonita que some).
Future<void> _testarMensagemHorarioSobreposto() async {
  final escalaAId = _gerarUuidV4();
  final escalaBId = _gerarUuidV4();
  final dataStr = DateTime.now().add(const Duration(days: 15)).toIso8601String().split('T').first;

  await _admin.from('escalas').insert([
    {
      'id': escalaAId,
      'nome': '[Robô de teste] A',
      'area_id': null,
      'data': dataStr,
      'horario_inicio': '09:00',
      'horario_fim': '10:00',
      'vagas': 5,
      'recorrente': false,
    },
    {
      'id': escalaBId,
      'nome': '[Robô de teste] B',
      'area_id': null,
      'data': dataStr,
      'horario_inicio': '09:30',
      'horario_fim': '10:30', // sobrepoe a escala A de proposito
      'vagas': 5,
      'recorrente': false,
    },
  ]);

  try {
    await _clienteMembro.rpc('inscrever_em_escala', params: {
      'p_escala_id': escalaAId,
      'p_data_ocorrencia': dataStr,
    });

    Object? erroCapturado;
    try {
      await _clienteMembro.rpc('inscrever_em_escala', params: {
        'p_escala_id': escalaBId,
        'p_data_ocorrencia': dataStr,
      });
    } catch (e) {
      erroCapturado = e;
    }

    if (erroCapturado == null) {
      throw Exception('Inscreveu em duas escalas com horário sobreposto -- deveria ter sido bloqueado.');
    }
    final texto = erroCapturado.toString();
    if (!texto.contains('ja esta inscrito em outra escala') &&
        !texto.contains('já está inscrito em outra escala')) {
      throw Exception(
          'Bloqueou a inscrição, mas a mensagem não bate com o que shifts_screen.dart espera '
          '(_mensagemAmigavel ficaria genérica pro membro). Erro real: $texto');
    }
  } finally {
    await _admin.from('inscricoes').delete().inFilter('escala_id', [escalaAId, escalaBId]);
    await _admin.from('escalas').delete().inFilter('id', [escalaAId, escalaBId]);
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
  final sexoOriginal = original['sexo'] as String?;
  // A conta de teste do Membro pode nao ter "sexo" preenchido -- em vez
  // de depender desse dado ja existir (e o teste falhar por causa de
  // cadastro incompleto, nao de bug de verdade), define um valor pra
  // esse teste e desfaz no finally, junto com o resto.
  final sexo = (sexoOriginal == 'masculino' || sexoOriginal == 'feminino') ? sexoOriginal : 'masculino';
  if (sexo != sexoOriginal) {
    await _clienteMembro.from('profiles').update({'sexo': sexo}).eq('id', membroId);
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
    // Desfaz tudo: estado civil e sexo originais, tira do ministerio
    // novo que o teste criou, devolve o vinculo do Awake se existia.
    await _clienteMembro.from('profiles').update({'estado_civil': estadoCivilOriginal}).eq('id', membroId);
    if (sexo != sexoOriginal) {
      await _clienteMembro.from('profiles').update({'sexo': sexoOriginal}).eq('id', membroId);
    }
    await _admin.from('profile_ministerios').delete().eq('profile_id', membroId).eq('ministerio', ministerioEsperado);
    if (vinculoAwakeOriginal != null) {
      await _admin.from('profile_ministerios').upsert(
        {'profile_id': membroId, 'ministerio': 'awake', 'papel': vinculoAwakeOriginal['papel']},
        onConflict: 'profile_id,ministerio',
      );
    }
  }
}

/// Ao "descasar" (estado_civil sai de casado/noivo pra outro valor), o
/// grupo_casais (Discipulado de Casais) deve ser limpo sozinho --
/// trg_limpar_grupo_casais_ao_sair_de_casado
/// (2026_limpar_grupo_casais_ao_descasar.sql). Homens/Mulheres é o
/// oposto (fica -- ninguém tira automaticamente, por decisão do Leo),
/// por isso desfaz esse efeito colateral do trigger de casamento no
/// finally, sem checar ele aqui (já testado em
/// _testarCasamentoAjustaMinisterios).
Future<void> _testarDescasarLimpaGrupoCasais() async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final original =
      await _admin.from('profiles').select('estado_civil, grupo_casais, sexo').eq('id', membroId).single();
  final estadoCivilOriginal = original['estado_civil'] as String?;
  final grupoCasaisOriginal = original['grupo_casais'] as String?;
  final sexo = original['sexo'] as String?;
  final ministerioSecundario = sexo == 'masculino' ? 'homens' : (sexo == 'feminino' ? 'mulheres' : null);

  final vinculoSecundarioOriginal = ministerioSecundario == null
      ? null
      : await _admin
          .from('profile_ministerios')
          .select('papel')
          .eq('profile_id', membroId)
          .eq('ministerio', ministerioSecundario)
          .maybeSingle();
  final vinculoAwakeOriginal = await _admin
      .from('profile_ministerios')
      .select('papel')
      .eq('profile_id', membroId)
      .eq('ministerio', 'awake')
      .maybeSingle();

  try {
    await _clienteMembro.from('profiles').update({
      'estado_civil': 'casado',
      'grupo_casais': 'henrique_patricia',
    }).eq('id', membroId);

    final depoisDeCasar = await _admin.from('profiles').select('grupo_casais').eq('id', membroId).single();
    if (depoisDeCasar['grupo_casais'] != 'henrique_patricia') {
      throw Exception('grupo_casais não foi gravado ao casar (setup do teste falhou).');
    }

    await _clienteMembro.from('profiles').update({'estado_civil': 'solteiro'}).eq('id', membroId);

    final depoisDeDescasar = await _admin.from('profiles').select('grupo_casais').eq('id', membroId).single();
    if (depoisDeDescasar['grupo_casais'] != null) {
      throw Exception('grupo_casais não foi limpo automaticamente ao "descasar".');
    }
  } finally {
    await _admin.from('profiles').update({
      'estado_civil': estadoCivilOriginal,
      'grupo_casais': grupoCasaisOriginal,
    }).eq('id', membroId);

    // O "casar" temporario acima tambem disparou
    // trg_ajustar_ministerios_ao_entrar_one -- desfaz esse efeito
    // colateral (entrar em homens/mulheres, sair do awake) pra nao
    // deixar sujeira.
    if (ministerioSecundario != null && vinculoSecundarioOriginal == null) {
      await _admin
          .from('profile_ministerios')
          .delete()
          .eq('profile_id', membroId)
          .eq('ministerio', ministerioSecundario);
    }
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
      // Nao basta a lista nao vir vazia -- profiles_select bloqueando
      // o lider de ler o nome de outra pessoa faz o join voltar
      // profiles=null em silencio (sem erro nenhum), e a tela caia no
      // fallback "Membro" pra todo mundo. Foi exatamente esse bug que
      // passou batido ate o Leo reportar, porque esse teste so
      // conferia "lista nao vazia".
      final nomeVeio = inscritos.any((i) => i['profiles'] != null);
      if (!nomeVeio) {
        throw Exception('Líder viu a inscrição mas profiles(nome) veio null -- RLS bloqueando o nome.');
      }
    },
  );
}

/// Lider consegue escalar OUTRA pessoa (o Membro de teste) numa
/// ocorrencia que ela nao se inscreveu sozinha -- inscrever_membro_
/// como_lider() precisa aceitar de quem e' lider/admin.
Future<void> _testarLiderEscalarMembroManual() async {
  final escalaId = _gerarUuidV4();
  final dataStr = DateTime.now().toIso8601String().split('T').first;
  final membroId = _clienteMembro.auth.currentUser!.id;

  await _admin.from('escalas').insert({
    'id': escalaId,
    'nome': '[Robô de teste] escalar manual',
    'area_id': null,
    'data': dataStr,
    'horario_inicio': '00:00',
    'horario_fim': '23:59',
    'vagas': 2,
    'recorrente': false,
  });

  try {
    await _clienteLider.rpc('inscrever_membro_como_lider', params: {
      'p_user_id': membroId,
      'p_escala_id': escalaId,
      'p_data_ocorrencia': dataStr,
    });

    final inscricao = await _admin
        .from('inscricoes')
        .select('id, status')
        .eq('escala_id', escalaId)
        .eq('user_id', membroId)
        .maybeSingle();
    if (inscricao == null) {
      throw Exception('Líder chamou a função mas não criou a inscrição do Membro.');
    }
  } finally {
    await _admin.from('inscricoes').delete().eq('escala_id', escalaId);
    await _admin.from('escalas').delete().eq('id', escalaId);
  }
}

/// Negativo: Membro comum (nao lider, nao admin) tentando escalar
/// OUTRA pessoa via inscrever_membro_como_lider() -- deve ser
/// bloqueado pela checagem is_admin()/is_lider_de_algum_ministerio()
/// dentro da funcao.
Future<void> _testarMembroNaoPodeEscalarOutraPessoa() async {
  final escalaId = _gerarUuidV4();
  final dataStr = DateTime.now().toIso8601String().split('T').first;
  final liderId = _clienteLider.auth.currentUser!.id;

  await _admin.from('escalas').insert({
    'id': escalaId,
    'nome': '[Robô de teste] nao deveria escalar',
    'area_id': null,
    'data': dataStr,
    'horario_inicio': '00:00',
    'horario_fim': '23:59',
    'vagas': 2,
    'recorrente': false,
  });

  try {
    await _clienteMembro.rpc('inscrever_membro_como_lider', params: {
      'p_user_id': liderId,
      'p_escala_id': escalaId,
      'p_data_ocorrencia': dataStr,
    });
  } finally {
    await _admin.from('inscricoes').delete().eq('escala_id', escalaId);
    await _admin.from('escalas').delete().eq('id', escalaId);
  }
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

/// Mesma consulta base que dashboard_ministerio_screen.dart faz -- NAO
/// basta so' nao lancar excecao (RLS bloqueando volta lista vazia/so
/// a propria linha, em silencio, sem erro nenhum): esse teste
/// adiciona o Membro de teste ao ministerio que o Lider lidera
/// (louvor) e confirma que o Lider consegue ver AMBAS as linhas -- a
/// dele e a do Membro -- nao so' a propria. Foi exatamente esse tipo
/// de bug ("dashboard só mostra os dados do próprio líder") que
/// passou batido antes, porque o teste antigo só conferia "não deu
/// erro".
Future<void> _testarDashboardMinisterio() async {
  final liderId = _clienteLider.auth.currentUser!.id;
  final membroId = _clienteMembro.auth.currentUser!.id;

  final vinculoOriginal = await _admin
      .from('profile_ministerios')
      .select('papel')
      .eq('profile_id', membroId)
      .eq('ministerio', 'louvor')
      .maybeSingle();

  await _admin.from('profile_ministerios').upsert(
    {'profile_id': membroId, 'ministerio': 'louvor', 'papel': 'membro'},
    onConflict: 'profile_id,ministerio',
  );

  try {
    final vistoPeloLider = await _clienteLider
        .from('profile_ministerios')
        .select('profile_id')
        .eq('ministerio', 'louvor');
    final ids = (vistoPeloLider as List).map((v) => (v as Map<String, dynamic>)['profile_id']).toSet();

    if (!ids.contains(liderId)) throw Exception('Líder não viu a própria linha em profile_ministerios.');
    if (!ids.contains(membroId)) {
      throw Exception('Líder não viu o Membro no time do ministério que lidera (dashboard mostraria só ele mesmo).');
    }
  } finally {
    if (vinculoOriginal == null) {
      await _admin.from('profile_ministerios').delete().eq('profile_id', membroId).eq('ministerio', 'louvor');
    } else {
      await _admin.from('profile_ministerios').upsert(
        {'profile_id': membroId, 'ministerio': 'louvor', 'papel': vinculoOriginal['papel']},
        onConflict: 'profile_id,ministerio',
      );
    }
  }
}

// ---------- checagens (conta teste 3: Admin) ----------

Future<void> _testarLoginAdmin() async {
  final senha = _env('TESTE_ADMIN_SENHA');
  _clienteAdmin = SupabaseClient(_url, _anonKey, authOptions: _semPkce);
  final resposta = await _clienteAdmin.auth.signInWithPassword(email: _emailAdmin, password: senha);
  if (resposta.session == null) throw Exception('Login não retornou sessão.');
}

/// Admin lê a lista de e-mails (auth.users) via RPC -- gestao.html usa
/// isso pra mostrar o e-mail no modal "Editar perfil" e na listagem
/// de Usuários (e-mail não vive em profiles, só em auth.users).
Future<void> _testarAdminListarEmails() async {
  final data = await _clienteAdmin.rpc('admin_listar_emails');
  if ((data as List).isEmpty) throw Exception('admin_listar_emails não devolveu nenhum e-mail.');
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

/// Líder do Awake (não só admin) também vê Visitantes -- Primeira Vez
/// e consegue marcar como lido -- mesma tela (AdminVisitantesScreen),
/// agora tambem no menu de quem lidera o Awake (profile_screen.dart).
/// A conta de teste "Líder" lidera só as 5 áreas de serviço, não o
/// Awake -- concede papel de líder do Awake temporariamente só pra
/// esse teste, e desfaz no finally.
Future<void> _testarLiderAwakeVerEMarcarVisitante() async {
  final liderId = _clienteLider.auth.currentUser!.id;
  final membroId = _clienteMembro.auth.currentUser!.id;

  final vinculoAwakeOriginal = await _admin
      .from('profile_ministerios')
      .select('papel')
      .eq('profile_id', liderId)
      .eq('ministerio', 'awake')
      .maybeSingle();

  await _admin.from('profile_ministerios').upsert(
    {'profile_id': liderId, 'ministerio': 'awake', 'papel': 'lider'},
    onConflict: 'profile_id,ministerio',
  );

  final criado = await _admin
      .from('visitantes_primeira_vez')
      .insert({
        'registrado_por': membroId,
        'dados': {'Nome completo': '[Robô de teste] Visitante alvo do líder'},
      })
      .select('id')
      .single();
  final id = criado['id'] as String;

  try {
    final visto = await _clienteLider.from('visitantes_primeira_vez').select('id').eq('id', id).maybeSingle();
    if (visto == null) throw Exception('Líder do Awake não conseguiu ver o visitante (select bloqueado).');

    await _clienteLider.from('visitantes_primeira_vez').update({'lido': true}).eq('id', id);
    final atual = await _admin.from('visitantes_primeira_vez').select('lido').eq('id', id).single();
    if (atual['lido'] != true) throw Exception('Líder do Awake não conseguiu marcar o visitante como lido.');
  } finally {
    await _admin.from('visitantes_primeira_vez').delete().eq('id', id);
    if (vinculoAwakeOriginal == null) {
      await _admin.from('profile_ministerios').delete().eq('profile_id', liderId).eq('ministerio', 'awake');
    } else {
      await _admin.from('profile_ministerios').upsert(
        {'profile_id': liderId, 'ministerio': 'awake', 'papel': vinculoAwakeOriginal['papel']},
        onConflict: 'profile_id,ministerio',
      );
    }
  }
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
/// profiles_update_admin (is_admin()), sem RPC/function nenhuma. A
/// checagem le com o cliente REAL do Membro (nao o bypass) -- confirma
/// que a MUDANCA FEITA PELO ADMIN chega mesmo na sessao de quem foi
/// alterado, nao so' que o banco gravou.
Future<void> _testarPromoverERemoverAdmin() async {
  final membroId = _clienteMembro.auth.currentUser!.id;

  await _clienteAdmin.from('profiles').update({'papel': 'admin'}).eq('id', membroId);
  try {
    final atual = await _clienteMembro.from('profiles').select('papel').eq('id', membroId).single();
    if (atual['papel'] != 'admin') {
      throw Exception('Sessão do Membro não vê a promoção a admin feita pelo admin.');
    }
  } finally {
    // Sempre reverte -- as outras fases do robo esperam o Membro de
    // teste com papel='membro'.
    await _admin.from('profiles').update({'papel': 'membro'}).eq('id', membroId);
  }
}

/// Admin edita o perfil de OUTRA pessoa (gestao.html: "Editar perfil"
/// na tela de Usuarios) e reverte -- mesma policy profiles_update_admin.
/// Checagem com o cliente REAL do Membro, mesmo motivo do teste acima.
Future<void> _testarEditarPerfilDeOutraPessoa() async {
  final membroId = _clienteMembro.auth.currentUser!.id;
  final original = await _admin.from('profiles').select('telefone').eq('id', membroId).single();
  final telefoneOriginal = original['telefone'] as String?;

  try {
    await _clienteAdmin.from('profiles').update({'telefone': '(21) 90000-0000'}).eq('id', membroId);
    final atual = await _clienteMembro.from('profiles').select('telefone').eq('id', membroId).single();
    if (atual['telefone'] != '(21) 90000-0000') {
      throw Exception('Sessão do Membro não vê o telefone editado pelo admin.');
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

  // Dali pra frente, QUALQUER excecao (erro de rede, Supabase fora do
  // ar no meio da chamada, etc.) tenta limpar a conta descartavel via
  // bypass antes de propagar -- antes so' cobria o caso especifico de
  // status != 200, deixando conta orfa em qualquer outra falha (foi o
  // que aconteceu num 503 do Supabase em 14/08).
  try {
    await _admin.from('profiles').update({'eh_conta_teste': true}).eq('id', idDescartavel);

    final resultado = await _clienteAdmin.functions.invoke(
      'admin-apagar-usuario',
      body: {'profileId': idDescartavel},
    );
    if (resultado.status != 200) {
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
  } catch (e) {
    // Best-effort: se a conta ainda existir, tenta apagar; se ja tiver
    // sumido (o admin-apagar-usuario pode ter funcionado mesmo com a
    // excecao vindo de outro lugar), so' ignora o erro da limpeza.
    try {
      await _admin.auth.admin.deleteUser(idDescartavel);
    } catch (_) {}
    rethrow;
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
    // CRITICO: sem criado_por, trigger_notificar_novo_evento() pula
    // inteiro o filtro de "eh conta de teste" e manda push DE VERDADE
    // pra igreja toda (escopo='igreja' = audiencia geral) -- bug real
    // que ja aconteceu em producao antes dessa correcao.
    'criado_por': quemFazCheckin.auth.currentUser!.id,
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

/// Admin marca check-in retroativo (aba Awake do gestao.html, botao
/// "Editar") pra alguem que nao escaneou o QR Code na hora. Confirma
/// que a linha foi criada, e que chamar de novo pra mesma pessoa/
/// evento/data nao duplica (a funcao checa "exists" antes de inserir).
Future<void> _testarAdminCheckinRetroativo() async {
  final eventoId = _gerarUuidV4();
  final membroId = _clienteMembro.auth.currentUser!.id;
  final dataStr = DateTime.now().toIso8601String().split('T').first;

  await _admin.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Verificação automática',
    'data_inicio': DateTime.now().toIso8601String(),
    'escopo': 'igreja',
    'tipo': 'outro',
    'recorrente': false,
    'criado_por': _clienteAdmin.auth.currentUser!.id,
  });

  try {
    await _clienteAdmin.rpc('admin_adicionar_checkin_evento', params: {
      'p_user_id': membroId,
      'p_evento_id': eventoId,
      'p_data_ocorrencia': dataStr,
    });
    // Chama de novo de proposito -- nao pode duplicar a linha.
    await _clienteAdmin.rpc('admin_adicionar_checkin_evento', params: {
      'p_user_id': membroId,
      'p_evento_id': eventoId,
      'p_data_ocorrencia': dataStr,
    });

    final presencas = await _admin
        .from('presencas_eventos')
        .select('id')
        .eq('evento_id', eventoId)
        .eq('user_id', membroId);
    if ((presencas as List).length != 1) {
      throw Exception(
          'admin_adicionar_checkin_evento() deveria ter exatamente 1 linha (achou ${presencas.length}) -- ou não criou, ou duplicou.');
    }
  } finally {
    await _admin.from('presencas_eventos').delete().eq('evento_id', eventoId);
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Negativo: Lider (nao admin) tentando marcar check-in retroativo de
/// outra pessoa -- admin_adicionar_checkin_evento() so' aceita admin.
Future<void> _testarNaoAdminNaoPodeCheckinRetroativo() async {
  final eventoId = _gerarUuidV4();
  final membroId = _clienteMembro.auth.currentUser!.id;

  await _admin.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] não deveria conseguir',
    'data_inicio': DateTime.now().toIso8601String(),
    'escopo': 'igreja',
    'tipo': 'outro',
    'recorrente': false,
    'criado_por': _clienteAdmin.auth.currentUser!.id,
  });

  try {
    await _clienteLider.rpc('admin_adicionar_checkin_evento', params: {
      'p_user_id': membroId,
      'p_evento_id': eventoId,
      'p_data_ocorrencia': DateTime.now().toIso8601String().split('T').first,
    });
  } finally {
    await _admin.from('presencas_eventos').delete().eq('evento_id', eventoId);
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Contador manual de presenca (aba Shallom do gestao.html + tela
/// "Contador de evento" no app) -- testa os dois lados: ajuste relativo
/// (+/-, nunca fica negativo) e ajuste absoluto (definir_contagem_evento,
/// usado só pelo "Editar" do gestao, rejeita valor negativo).
Future<void> _testarAdminContagemManual() async {
  final eventoId = _gerarUuidV4();
  final dataStr = DateTime.now().toIso8601String().split('T').first;

  await _admin.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] Verificação automática',
    'data_inicio': DateTime.now().toIso8601String(),
    'escopo': 'igreja',
    'tipo': 'ebd',
    'recorrente': false,
    'criado_por': _clienteAdmin.auth.currentUser!.id,
  });

  try {
    final depoisDoisMais = await _clienteAdmin.rpc('ajustar_contagem_evento', params: {
      'p_evento_id': eventoId,
      'p_data_ocorrencia': dataStr,
      'p_delta': 1,
    }) as int;
    final depoisMaisUm = await _clienteAdmin.rpc('ajustar_contagem_evento', params: {
      'p_evento_id': eventoId,
      'p_data_ocorrencia': dataStr,
      'p_delta': 1,
    }) as int;
    if (depoisDoisMais != 1 || depoisMaisUm != 2) {
      throw Exception('ajustar_contagem_evento(+1) duas vezes deveria dar 1 e depois 2 -- deu $depoisDoisMais e $depoisMaisUm.');
    }

    // Desce bem mais do que tem -- nao pode ficar negativo.
    final depoisDeZerar = await _clienteAdmin.rpc('ajustar_contagem_evento', params: {
      'p_evento_id': eventoId,
      'p_data_ocorrencia': dataStr,
      'p_delta': -10,
    }) as int;
    if (depoisDeZerar != 0) {
      throw Exception('ajustar_contagem_evento(-10) numa contagem de 2 deveria travar em 0, deu $depoisDeZerar.');
    }

    // Ajuste absoluto (Editar no gestao) -- define um valor direto.
    final aposDefinir = await _clienteAdmin.rpc('definir_contagem_evento', params: {
      'p_evento_id': eventoId,
      'p_data_ocorrencia': dataStr,
      'p_valor': 42,
    }) as int;
    if (aposDefinir != 42) {
      throw Exception('definir_contagem_evento(42) deveria devolver 42, deu $aposDefinir.');
    }

    Object? erroValorNegativo;
    try {
      await _clienteAdmin.rpc('definir_contagem_evento', params: {
        'p_evento_id': eventoId,
        'p_data_ocorrencia': dataStr,
        'p_valor': -1,
      });
    } catch (e) {
      erroValorNegativo = e;
    }
    if (erroValorNegativo == null) {
      throw Exception('definir_contagem_evento(-1) deveria ter sido rejeitado.');
    }
  } finally {
    await _admin.from('contagem_manual_eventos').delete().eq('evento_id', eventoId);
    await _admin.from('eventos').delete().eq('id', eventoId);
  }
}

/// Negativo: Lider (nao admin) tentando ajustar a contagem manual --
/// ajustar_contagem_evento() so' aceita admin.
Future<void> _testarNaoAdminNaoPodeAjustarContagem() async {
  final eventoId = _gerarUuidV4();

  await _admin.from('eventos').insert({
    'id': eventoId,
    'titulo': '[Robô de teste] não deveria conseguir',
    'data_inicio': DateTime.now().toIso8601String(),
    'escopo': 'igreja',
    'tipo': 'ebd',
    'recorrente': false,
    'criado_por': _clienteAdmin.auth.currentUser!.id,
  });

  try {
    await _clienteLider.rpc('ajustar_contagem_evento', params: {
      'p_evento_id': eventoId,
      'p_data_ocorrencia': DateTime.now().toIso8601String().split('T').first,
      'p_delta': 1,
    });
  } finally {
    await _admin.from('contagem_manual_eventos').delete().eq('evento_id', eventoId);
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
    resultados.add(await _rodar('membro_descasar_limpa_grupo_casais', _testarDescasarLimpaGrupoCasais));
    resultados.add(await _rodar('membro_editar_perfil', _testarEditarPerfil));
    resultados.add(await _rodar('codigo_lider_errado', _testarCodigoLiderErrado));
    resultados.add(await _rodar('membro_cadastro_primeira_vez', _testarCadastroPrimeiraVez));
    resultados.add(await _rodar('primeira_vez_so_no_dia', _testarPrimeiraVezSoNoDia));
    resultados.add(await _rodar('membro_inscrever_e_cancelar_escala', _testarInscreverECancelarEscalaAwake));
    resultados.add(await _rodar('mensagem_horario_sobreposto', _testarMensagemHorarioSobreposto));
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
    resultados.add(await _rodar('lider_editar_ocorrencia_unica', _testarEditarOcorrenciaUnica));
    resultados.add(await _rodar('lider_editar_evento_toda_serie', _testarEditarEventoTodaSerie));
    resultados.add(await _rodar('lider_apagar_evento_toda_serie', _testarApagarEventoTodaSerie));
    resultados.add(await _rodar('lider_modelo_escala_awake', _testarLiderCriarEditarApagarModeloEscalaAwake));
    resultados.add(await _rodar('primeira_vez_lider_awake_sempre', _testarPrimeiraVezLiderAwakeSempre));
    resultados.add(await _rodarEsperandoFalha(
        'lider_nao_pode_criar_evento_fora_do_que_lidera', _testarLiderNaoPodeCriarEventoForaDoQueLidera));
    if (resultadoLoginMembro.sucesso) {
      // Dependem do Membro tambem estar logado.
      resultados.add(await _rodar('lider_casal_diaconos', _testarCasalDiaconos));
      resultados.add(await _rodar('lider_escalado_aparece_na_inicio', _testarEscaladoApareceNaInicio));
      resultados.add(await _rodar('lider_ver_inscritos_escala', _testarLiderVerInscritosEscala));
      resultados.add(await _rodar('lider_escalar_membro_manual', _testarLiderEscalarMembroManual));
      resultados.add(await _rodarEsperandoFalha(
          'membro_nao_pode_escalar_outra_pessoa', _testarMembroNaoPodeEscalarOutraPessoa));
      resultados.add(await _rodar('lider_awake_ver_e_marcar_visitante', _testarLiderAwakeVerEMarcarVisitante));
      resultados.add(await _rodar('lider_dashboard_ve_time_inteiro', _testarDashboardMinisterio));
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
    resultados.add(await _rodar('admin_listar_emails', _testarAdminListarEmails));
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
      resultados.add(await _rodar('admin_checkin_retroativo', _testarAdminCheckinRetroativo));
      resultados.add(await _rodarEsperandoFalha(
          'nao_admin_nao_pode_checkin_retroativo', _testarNaoAdminNaoPodeCheckinRetroativo));
      resultados.add(await _rodar('admin_contagem_manual', _testarAdminContagemManual));
      resultados.add(await _rodarEsperandoFalha(
          'nao_admin_nao_pode_ajustar_contagem', _testarNaoAdminNaoPodeAjustarContagem));
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

  try {
    await _salvarResultados(rodadaId, resultados);
  } catch (e) {
    // Se ATE o salvamento falhar (ex: Supabase fora do ar no meio da
    // rodada), nao deixa virar excecao nao tratada com stack trace --
    // so' avisa e segue pro resumo/exit normal. As checagens em si ja
    // rodaram e falharam do jeito certo (PostgrestException capturada
    // em _rodar()), so' o registro na tabela que nao foi.
    stderr.writeln('Não deu pra salvar os resultados em testes_automatizados_execucoes: $e');
  }

  final falhas = resultados.where((r) => !r.sucesso).toList();
  stdout.writeln('=== ${resultados.length - falhas.length}/${resultados.length} passaram ===');

  if (falhas.isNotEmpty) {
    stderr.writeln('Falharam: ${falhas.map((f) => f.nome).join(', ')}');
    exit(1); // workflow fica vermelho -- GitHub avisa por e-mail sozinho
  }

  // Termina o processo na marra -- os SupabaseClient (sessoes com
  // renovacao automatica de token em segundo plano) deixam o event
  // loop vivo, entao sem isso o "dart run" nunca sai sozinho mesmo com
  // tudo ja impresso, e o job fica pendurado ate o timeout do GitHub
  // Actions.
  exit(0);
}
