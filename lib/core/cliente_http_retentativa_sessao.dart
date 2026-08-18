import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente HTTP customizado so pra dar uma segunda chance quando o
/// Supabase responde com o erro `PGRST303` ("JWT issued at future").
///
/// Isso acontece quando o relogio interno da infra do Supabase (Auth
/// vs. Postgres/PostgREST) fica descompassado por alguns segundos --
/// normalmente logo depois que o projeto "acorda" de um periodo parado.
/// O token que o app ja tem guardado passa a ser visto (por engano)
/// como "emitido no futuro" ate o relogio deles se ajustar sozinho.
///
/// Sem isso, a pessoa via uma tela de erro crua e precisava fechar e
/// abrir o app de novo pra forcar uma sessao nova (o que basicamente
/// so renova o token). Com isso, o proprio app detecta o erro, renova
/// a sessao e tenta a mesma requisicao de novo sozinho, uma unica vez.
class ClienteHttpComRetentativaDeSessao extends http.BaseClient {
  ClienteHttpComRetentativaDeSessao(this._interno);

  final http.Client _interno;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // So sabemos clonar com seguranca requisicoes "normais" (Request,
    // usado por GoTrue/PostgREST e pela maioria das chamadas do
    // Storage) -- uploads de arquivo via stream nao dao pra reenviar,
    // entao esses passam direto, sem retentativa.
    final requisicaoOriginal = request is http.Request ? request : null;

    final resposta = await _interno.send(request);
    if (resposta.statusCode != 401 || requisicaoOriginal == null) {
      return resposta;
    }

    final corpo = await resposta.stream.bytesToString();
    final ehTokenEmitidoNoFuturo =
        corpo.contains('PGRST303') || corpo.contains('issued at future');
    if (!ehTokenEmitidoNoFuturo) {
      return _respostaReconstruida(resposta, corpo);
    }

    try {
      final novaSessao = await Supabase.instance.client.auth.refreshSession();
      final novoToken = novaSessao.session?.accessToken;
      if (novoToken == null) {
        return _respostaReconstruida(resposta, corpo);
      }

      final novaRequisicao = http.Request(
        requisicaoOriginal.method,
        requisicaoOriginal.url,
      )
        ..headers.addAll(requisicaoOriginal.headers)
        ..headers['Authorization'] = 'Bearer $novoToken'
        ..bodyBytes = requisicaoOriginal.bodyBytes;

      return await _interno.send(novaRequisicao);
    } catch (_) {
      // Nem a renovacao da sessao funcionou -- devolve o erro
      // original, nao ha mais nada a tentar aqui.
      return _respostaReconstruida(resposta, corpo);
    }
  }

  http.StreamedResponse _respostaReconstruida(
    http.StreamedResponse original,
    String corpoJaLido,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(corpoJaLido)),
      original.statusCode,
      contentLength: original.contentLength,
      request: original.request,
      headers: original.headers,
      isRedirect: original.isRedirect,
      persistentConnection: original.persistentConnection,
      reasonPhrase: original.reasonPhrase,
    );
  }
}
