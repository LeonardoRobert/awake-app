import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/escala_servico_model.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Estado de uma ocorrencia (culto especifico) dentro da tela: comeca so
/// com data/evento, e ganha escalaId/posicoes depois do primeiro carregar.
class _OcorrenciaEscala {
  final DateTime data;
  final EventModel evento;
  String? escalaId;
  List<PosicaoEscala> posicoes = [];

  _OcorrenciaEscala({required this.data, required this.evento});
}

/// Tela de criar/editar a escala de um ministerio de servico (Diaconos,
/// Louvor, Danca, Midia, Multimidia) pra uma ou mais ocorrencias de
/// eventos gerais da igreja -- usada tanto pra uma unica ocorrencia
/// (botao "Criar/editar escala" dentro do detalhe de um evento) quanto
/// pra semana inteira de uma vez (fluxo Semanal), pra nao precisar abrir
/// a tela de novo culto a culto.
class EscalaServicoScreen extends StatefulWidget {
  final String ministerio;
  final List<(DateTime data, EventModel evento)> ocorrencias;

  const EscalaServicoScreen({
    super.key,
    required this.ministerio,
    required this.ocorrencias,
  });

  @override
  State<EscalaServicoScreen> createState() => _EscalaServicoScreenState();
}

class _EscalaServicoScreenState extends State<EscalaServicoScreen> {
  final _service = EscalaServicoService();
  late final List<_OcorrenciaEscala> _ocorrencias = widget.ocorrencias
      .map((oc) => _OcorrenciaEscala(data: oc.$1, evento: oc.$2))
      .toList();
  bool _carregando = true;
  String? _erroCarregar;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarregar = null;
    });
    try {
      await Future.wait(_ocorrencias.map((oc) async {
        final escalaId = await _service.buscarOuCriarEscala(
          ministerio: widget.ministerio,
          eventoId: oc.evento.id,
          dataOcorrencia: oc.data,
        );
        final posicoes = await _service.listarPosicoes(escalaId);
        oc.escalaId = escalaId;
        oc.posicoes = posicoes;
      }));
    } catch (e) {
      // Sem isso, qualquer falha aqui deixava a tela presa em
      // "carregando" pra sempre, sem nenhum aviso -- pior tipo de bug
      // de diagnosticar, porque nao aparece nada de errado na tela.
      // Inclui o id de quem esta logado no proprio erro -- serve pra
      // diagnosticar problema de sessao sem precisar abrir o DevTools.
      final meuId = Supabase.instance.client.auth.currentUser?.id ?? '(ninguém logado)';
      if (mounted) setState(() => _erroCarregar = '(logado como $meuId) $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recarregarOcorrencia(_OcorrenciaEscala ocorrencia) async {
    final posicoes = await _service.listarPosicoes(ocorrencia.escalaId!);
    if (!mounted) return;
    setState(() => ocorrencia.posicoes = posicoes);
  }

  bool get _ehDiaconos => widget.ministerio == 'diaconos';

  Future<void> _escolherPessoa(
    _OcorrenciaEscala ocorrencia,
    PosicaoEscala posicao, {
    int slot = 1,
  }) async {
    final buscaController = TextEditingController();
    List<PessoaBusca> resultados = [];
    final jaTemPessoa = slot == 1 ? posicao.profileId != null : posicao.profileId2 != null;

    final selecionado = await showDialog<PessoaBusca?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> buscar(String texto) async {
            final r = await _service.buscarPessoasDoMinisterio(widget.ministerio, texto);
            setDialogState(() => resultados = r);
          }

          if (resultados.isEmpty && buscaController.text.isEmpty) {
            buscar('');
          }

          return AlertDialog(
            title: Text(
              _ehDiaconos
                  ? 'Quem vai ser a $slotª pessoa em "${posicao.funcao}"?'
                  : 'Quem vai ser "${posicao.funcao}"?',
            ),
            content: SizedBox(
              width: 350,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: buscaController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Buscar pessoa',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: buscar,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: resultados.length,
                      itemBuilder: (context, index) {
                        final pessoa = resultados[index];
                        return ListTile(
                          title: Text(pessoa.nome),
                          onTap: () => Navigator.of(dialogContext).pop(pessoa),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (jaTemPessoa)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    PessoaBusca(id: '', nome: ''), // sinal de "limpar"
                  ),
                  child: const Text('Remover pessoa', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );

    if (selecionado == null) return;

    final novoProfileId = selecionado.id.isEmpty ? null : selecionado.id;
    if (slot == 1) {
      await _service.definirPessoa(posicao.id, novoProfileId);
    } else {
      await _service.definirSegundaPessoa(posicao.id, novoProfileId);
    }

    // Mesma memoria de casal ja usada na grade mensal: so pros
    // Diaconos, e so quando a pessoa foi definida (nao ao limpar).
    if (_ehDiaconos && novoProfileId != null) {
      await _aplicarEfeitoCasal(ocorrencia, posicao.funcao, slot, selecionado);
    }

    await _recarregarOcorrencia(ocorrencia);
  }

  /// Autopreenche o slot irmao com o par salvo (se houver) e, assim que
  /// os dois slots dessa posicao ficarem preenchidos, lembra/atualiza o
  /// par -- mesma logica da grade mensal (ver escala_grade_screen.dart).
  Future<void> _aplicarEfeitoCasal(
    _OcorrenciaEscala ocorrencia,
    String funcao,
    int slotEditado,
    PessoaBusca pessoa,
  ) async {
    final posicoes = await _service.listarPosicoes(ocorrencia.escalaId!);
    final posicaoAtual = posicoes.firstWhere((p) => p.funcao == funcao);

    final slotIrmaoVazio =
        slotEditado == 1 ? posicaoAtual.profileId2 == null : posicaoAtual.profileId == null;

    if (slotIrmaoVazio) {
      final par = await _service.buscarParDoCasal(
        ministerio: widget.ministerio,
        profileId: pessoa.id,
      );
      if (par != null) {
        if (slotEditado == 1) {
          await _service.definirSegundaPessoa(posicaoAtual.id, par.id);
        } else {
          await _service.definirPessoa(posicaoAtual.id, par.id);
        }
      }
    }

    final posicoesFinal = await _service.listarPosicoes(ocorrencia.escalaId!);
    final posicaoFinal = posicoesFinal.firstWhere((p) => p.funcao == funcao);
    if (posicaoFinal.profileId != null && posicaoFinal.profileId2 != null) {
      await _service.salvarPar(
        ministerio: widget.ministerio,
        profileIdA: posicaoFinal.profileId!,
        profileIdB: posicaoFinal.profileId2!,
      );
    }
  }

  Future<void> _adicionarFuncaoLivre(_OcorrenciaEscala ocorrencia) async {
    final controller = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar posição'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da posição/função'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (nome == null || nome.isEmpty || ocorrencia.escalaId == null) return;
    await _service.adicionarPosicao(
      escalaId: ocorrencia.escalaId!,
      funcao: nome,
      ordem: ocorrencia.posicoes.length + 1,
    );
    await _recarregarOcorrencia(ocorrencia);
  }

  Future<void> _removerPosicao(_OcorrenciaEscala ocorrencia, PosicaoEscala posicao) async {
    await _service.removerPosicao(posicao.id);
    await _recarregarOcorrencia(ocorrencia);
  }

  /// So pra Danca: em vez de escolher pessoa por pessoa em cada
  /// "Integrante N", cola uma lista (um nome por linha) e o app tenta
  /// casar cada linha com uma pessoa de verdade do ministerio (precisa
  /// ser perfil real -- e' o que faz check-in por QR, notificacao e a
  /// tarja "Voce esta escalado(a)" funcionarem). Quem nao bater fica
  /// de fora, listado no final, pra resolver na busca normal.
  Future<void> _colarListaNomes(_OcorrenciaEscala ocorrencia) async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Colar lista de nomes'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Um nome por linha. Cada um precisa bater com o nome de uma '
                'pessoa já cadastrada na Dança -- quem não bater fica de fora, '
                'pra você resolver na busca normal.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Ana Souza\nBruno Lima\nCarla Mendes...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Escalar'),
          ),
        ],
      ),
    );

    if (texto == null || ocorrencia.escalaId == null) return;
    final nomes = texto.split('\n').map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    if (nomes.isEmpty) return;

    final posicoesVazias = ocorrencia.posicoes.where((p) => p.profileId == null).toList();
    final naoEncontrados = <String>[];
    var proximaOrdem = ocorrencia.posicoes.length + 1;
    var indiceVazia = 0;

    for (final nome in nomes) {
      final resultados = await _service.buscarPessoasDoMinisterio(widget.ministerio, nome);
      final exatos = resultados.where((p) => p.nome.toLowerCase() == nome.toLowerCase()).toList();
      final pessoa = exatos.length == 1
          ? exatos.first
          : (resultados.length == 1 ? resultados.first : null);

      if (pessoa == null) {
        naoEncontrados.add(nome);
        continue;
      }

      if (indiceVazia < posicoesVazias.length) {
        await _service.definirPessoa(posicoesVazias[indiceVazia].id, pessoa.id);
        indiceVazia++;
      } else {
        final novaPosicao = await _service.adicionarPosicaoRetornandoId(
          escalaId: ocorrencia.escalaId!,
          funcao: 'Integrante $proximaOrdem',
          ordem: proximaOrdem,
        );
        proximaOrdem++;
        await _service.definirPessoa(novaPosicao, pessoa.id);
      }
    }

    await _recarregarOcorrencia(ocorrencia);

    if (!mounted) return;
    final escalados = nomes.length - naoEncontrados.length;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resultado'),
        content: Text(
          naoEncontrados.isEmpty
              ? '$escalados pessoa(s) escalada(s) com sucesso.'
              : '$escalados escalada(s). Não encontrados na Dança (verifique o nome '
                  'exato ou escale na busca normal):\n\n${naoEncontrados.join('\n')}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  /// Monta um texto pronto pra colar num grupo do WhatsApp (usa
  /// *asterisco* pra negrito, que o WhatsApp já entende sozinho).
  String _gerarTextoWhatsApp() {
    final buffer = StringBuffer('*Escala de ${widget.ministerio.labelMinisterio}*');
    for (final ocorrencia in _ocorrencias) {
      buffer.writeln();
      buffer.writeln();
      buffer.writeln(
        '*${DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(ocorrencia.data)}* — ${ocorrencia.evento.titulo}',
      );
      for (final posicao in ocorrencia.posicoes) {
        final quem = _ehDiaconos
            ? _formatarCasal(posicao.nomePessoa, posicao.nomePessoa2)
            : (posicao.nomePessoa ?? '—');
        buffer.writeln('${posicao.funcao}: $quem');
      }
    }
    return buffer.toString();
  }

  String _formatarCasal(String? nome1, String? nome2) {
    if (nome1 == null && nome2 == null) return '—';
    if (nome1 != null && nome2 != null) return '$nome1 e $nome2';
    return nome1 ?? nome2!;
  }

  void _copiarParaWhatsApp(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _gerarTextoWhatsApp()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escala copiada! Já pode colar no grupo do WhatsApp.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _ocorrencias.length > 1
        ? 'Escala semanal — ${widget.ministerio.labelMinisterio}'
        : 'Escala de ${widget.ministerio.labelMinisterio}';

    return Scaffold(
      appBar: AwakeAppBar(
        title: titulo,
        showQrButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copiar pro WhatsApp',
            onPressed: _carregando ? null : () => _copiarParaWhatsApp(context),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erroCarregar != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Erro ao carregar a escala: $_erroCarregar', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _carregar, child: const Text('Tentar de novo')),
                      ],
                    ),
                  ),
                )
              : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final ocorrencia in _ocorrencias) ...[
                  Text(ocorrencia.evento.titulo, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(ocorrencia.data),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ...ocorrencia.posicoes.map((posicao) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: _ehDiaconos
                            ? _buildPosicaoCasal(ocorrencia, posicao)
                            : ListTile(
                                title: Text(posicao.funcao),
                                subtitle:
                                    Text(posicao.nomePessoa ?? 'Ninguém escalado ainda'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Remover essa posição da escala',
                                  onPressed: () => _removerPosicao(ocorrencia, posicao),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: posicao.profileId != null
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                                  child: Icon(
                                    posicao.profileId != null
                                        ? Icons.check
                                        : Icons.person_outline,
                                    size: 18,
                                  ),
                                ),
                                onTap: () => _escolherPessoa(ocorrencia, posicao),
                              ),
                      )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _adicionarFuncaoLivre(ocorrencia),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar posição'),
                      ),
                      if (widget.ministerio == 'danca')
                        OutlinedButton.icon(
                          onPressed: () => _colarListaNomes(ocorrencia),
                          icon: const Icon(Icons.playlist_add_outlined),
                          label: const Text('Colar lista de nomes'),
                        ),
                    ],
                  ),
                  if (ocorrencia != _ocorrencias.last) ...[
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _buildPosicaoCasal(_OcorrenciaEscala ocorrencia, PosicaoEscala posicao) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(posicao.funcao,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remover essa posição da escala',
                  onPressed: () => _removerPosicao(ocorrencia, posicao),
                ),
              ],
            ),
          ),
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: posicao.profileId != null
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              child: Icon(
                posicao.profileId != null ? Icons.check : Icons.person_outline,
                size: 14,
              ),
            ),
            title: Text(posicao.nomePessoa ?? 'Escolher 1ª pessoa do casal'),
            onTap: () => _escolherPessoa(ocorrencia, posicao, slot: 1),
          ),
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: posicao.profileId2 != null
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              child: Icon(
                posicao.profileId2 != null ? Icons.check : Icons.person_outline,
                size: 14,
              ),
            ),
            title: Text(posicao.nomePessoa2 ?? 'Escolher 2ª pessoa do casal'),
            onTap: () => _escolherPessoa(ocorrencia, posicao, slot: 2),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
