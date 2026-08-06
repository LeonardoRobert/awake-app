import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/escala_servico_model.dart';
import '../../models/profile_model.dart';
import '../../services/escala_servico_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela de criar/editar a escala de um ministerio de servico (Diaconos,
/// Louvor, Danca, Midia, Multimidia) pra uma ocorrencia especifica de
/// um evento geral da igreja.
class EscalaServicoScreen extends StatefulWidget {
  final String ministerio;
  final String eventoId;
  final String eventoTitulo;
  final DateTime dataOcorrencia;

  const EscalaServicoScreen({
    super.key,
    required this.ministerio,
    required this.eventoId,
    required this.eventoTitulo,
    required this.dataOcorrencia,
  });

  @override
  State<EscalaServicoScreen> createState() => _EscalaServicoScreenState();
}

class _EscalaServicoScreenState extends State<EscalaServicoScreen> {
  final _service = EscalaServicoService();
  String? _escalaId;
  List<PosicaoEscala> _posicoes = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final escalaId = await _service.buscarOuCriarEscala(
      ministerio: widget.ministerio,
      eventoId: widget.eventoId,
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

  bool get _ehDiaconos => widget.ministerio == 'diaconos';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Escala de ${widget.ministerio.labelMinisterio}',
        showQrButton: false,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.eventoTitulo, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(widget.dataOcorrencia),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ..._posicoes.map((posicao) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: _ehDiaconos
                          ? _buildPosicaoCasal(posicao)
                          : ListTile(
                              title: Text(posicao.funcao),
                              subtitle:
                                  Text(posicao.nomePessoa ?? 'Ninguém escalado ainda'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Remover essa posição da escala',
                                onPressed: () => _removerPosicao(posicao),
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
                              onTap: () => _escolherPessoa(posicao),
                            ),
                    )),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _adicionarFuncaoLivre,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar posição'),
                ),
              ],
            ),
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
            onTap: () => _escolherPessoa(posicao, slot: 2),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
