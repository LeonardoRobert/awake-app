import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/mensagem_model.dart';
import '../../services/mensagem_service.dart';
import '../../widgets/awake_app_bar.dart';

/// So admin acessa (o link so aparece no menu pra admin, e a RLS
/// tambem bloqueia no banco pra quem nao e). Mostra Pedidos de Oracao
/// e Testemunhos em abas.
class AdminMensagensScreen extends StatefulWidget {
  const AdminMensagensScreen({super.key});

  @override
  State<AdminMensagensScreen> createState() => _AdminMensagensScreenState();
}

class _AdminMensagensScreenState extends State<AdminMensagensScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AwakeAppBar(title: 'Caixa de entrada', showQrButton: false),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Oração'),
              Tab(text: 'Testemunhos'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ListaMensagens(tabela: 'pedidos_oracao'),
                _ListaMensagens(tabela: 'testemunhos'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaMensagens extends StatefulWidget {
  final String tabela;
  const _ListaMensagens({required this.tabela});

  @override
  State<_ListaMensagens> createState() => _ListaMensagensState();
}

class _ListaMensagensState extends State<_ListaMensagens> {
  late Future<List<MensagemModel>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = MensagemService(widget.tabela).listarTodas();
  }

  Future<void> _recarregar() async {
    setState(() => _futuro = MensagemService(widget.tabela).listarTodas());
    await _futuro;
  }

  Future<void> _confirmarEApagar(MensagemModel m) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    await MensagemService(widget.tabela).apagar(m.id);
    _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _recarregar,
      child: FutureBuilder<List<MensagemModel>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final mensagens = snapshot.data ?? [];
          if (mensagens.isEmpty) {
            return const Center(child: Text('Nada por aqui ainda.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mensagens.length,
            itemBuilder: (context, index) {
              final m = mensagens[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                m.anonimo ? Icons.visibility_off_outlined : Icons.person_outline,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  m.anonimo ? 'Anônimo' : (m.nomeAutor ?? 'Sem nome'),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(m.criadoEm),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(m.texto),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!m.lido)
                            TextButton(
                              onPressed: () async {
                                await MensagemService(widget.tabela).marcarComoLida(m.id);
                                _recarregar();
                              },
                              child: const Text('Marcar como lido'),
                            ),
                          TextButton(
                            onPressed: () => _confirmarEApagar(m),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Apagar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}