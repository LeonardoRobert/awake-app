import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/escala_servico_model.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Mostra os proximos EBD/Culto de Celebracao/Culto da Familia numa
/// tela so -- a pessoa preenche os 3 sem precisar ir e voltar.
class EscalaSemanalScreen extends StatelessWidget {
  final String ministerio;
  final List<(DateTime, EventModel)> ocorrencias;

  const EscalaSemanalScreen({
    super.key,
    required this.ministerio,
    required this.ocorrencias,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Escala semanal — ${ministerio.labelMinisterio}',
        showQrButton: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ocorrencias.length,
        separatorBuilder: (_, __) => const Divider(height: 40),
        itemBuilder: (context, index) {
          final (data, evento) = ocorrencias[index];
          return _SecaoEscalaCulto(
            ministerio: ministerio,
            evento: evento,
            dataOcorrencia: data,
          );
        },
      ),
    );
  }
}

class _SecaoEscalaCulto extends StatefulWidget {
  final String ministerio;
  final EventModel evento;
  final DateTime dataOcorrencia;

  const _SecaoEscalaCulto({
    required this.ministerio,
    required this.evento,
    required this.dataOcorrencia,
  });

  @override
  State<_SecaoEscalaCulto> createState() => _SecaoEscalaCultoState();
}

class _SecaoEscalaCultoState extends State<_SecaoEscalaCulto> {
  final _service = EscalaServicoService();
  String? _escalaId;
  List<PosicaoEscala> _posicoes = [];
  bool _carregando = true;

  bool get _ehDiaconos => widget.ministerio == 'diaconos';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final escalaId = await _service.buscarOuCriarEscala(
      ministerio: widget.ministerio,
      eventoId: widget.evento.id,
      dataOcorrencia: widget.dataOcorrencia,
    );
    final posicoes = await _service.listarPosicoes(escalaId);
    if (mounted) {
      setState(() {
        _escalaId = escalaId;
        _posicoes = posicoes;
        _carregando = false;
      });
    }
  }

  Future<void> _escolherPessoa(PosicaoEscala posicao, {int slot = 1}) async {
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

          if (resultados.isEmpty && buscaController.text.isEmpty) buscar('');

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
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(PessoaBusca(id: '', nome: '')),
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
    _carregar();
  }

  Future<void> _adicionarFuncaoLivre() async {
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

    if (nome == null || nome.isEmpty || _escalaId == null) return;
    await _service.adicionarPosicao(
      escalaId: _escalaId!,
      funcao: nome,
      ordem: _posicoes.length + 1,
    );
    _carregar();
  }

  Future<void> _removerPosicao(PosicaoEscala posicao) async {
    await _service.removerPosicao(posicao.id);
    _carregar();
  }

  /// Tira a pessoa escalada, mas MANTEM a posicao/funcao -- fica
  /// disponivel pra escalar outra pessoa depois.
  Future<void> _desescalarPessoa(PosicaoEscala posicao, {int slot = 1}) async {
    if (slot == 1) {
      await _service.definirPessoa(posicao.id, null);
    } else {
      await _service.definirSegundaPessoa(posicao.id, null);
    }
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.evento.titulo, style: Theme.of(context).textTheme.titleLarge),
        Text(
          DateFormat("EEEE, dd 'de' MMMM 'às' HH:mm", 'pt_BR').format(widget.dataOcorrencia),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (_carregando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          ..._posicoes.map((posicao) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: _ehDiaconos
                    ? _buildPosicaoCasal(posicao)
                    : ListTile(
                        title: Text(posicao.funcao),
                        subtitle: Text(posicao.nomePessoa ?? 'Ninguém escalado ainda'),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (opcao) {
                            if (opcao == 'tirar') {
                              _desescalarPessoa(posicao);
                            } else if (opcao == 'excluir') {
                              _removerPosicao(posicao);
                            }
                          },
                          itemBuilder: (context) => [
                            if (posicao.profileId != null)
                              const PopupMenuItem(
                                value: 'tirar',
                                child: Text('Tirar essa pessoa'),
                              ),
                            const PopupMenuItem(
                              value: 'excluir',
                              child: Text(
                                'Excluir posição',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        leading: CircleAvatar(
                          backgroundColor: posicao.profileId != null
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          child: Icon(
                            posicao.profileId != null ? Icons.check : Icons.person_outline,
                            size: 18,
                          ),
                        ),
                        onTap: () => _escolherPessoa(posicao),
                      ),
              )),
          OutlinedButton.icon(
            onPressed: _adicionarFuncaoLivre,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar posição'),
          ),
        ],
      ],
    );
  }

  Widget _buildPosicaoCasal(PosicaoEscala posicao) {
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
                  onPressed: () => _removerPosicao(posicao),
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
            trailing: posicao.profileId != null
                ? IconButton(
                    icon: const Icon(Icons.person_remove_outlined, size: 16),
                    tooltip: 'Tirar essa pessoa (mantém a posição)',
                    onPressed: () => _desescalarPessoa(posicao, slot: 1),
                  )
                : null,
            onTap: () => _escolherPessoa(posicao, slot: 1),
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
            trailing: posicao.profileId2 != null
                ? IconButton(
                    icon: const Icon(Icons.person_remove_outlined, size: 16),
                    tooltip: 'Tirar essa pessoa (mantém a posição)',
                    onPressed: () => _desescalarPessoa(posicao, slot: 2),
                  )
                : null,
            onTap: () => _escolherPessoa(posicao, slot: 2),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}