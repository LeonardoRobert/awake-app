import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/outdoor_model.dart';
import '../../providers/outdoor_provider.dart';
import '../../widgets/awake_app_bar.dart';
import 'outdoor_form_screen.dart';

/// Lista de outdoors existentes (admin ve todos, inclusive pausados,
/// porque outdoors_select libera geral pra is_admin()) -- com jeito de
/// editar, apagar ou reordenar cada um (a ordem aqui e' a MESMA que
/// aparece no slideshow, ver outdoorsAtivosProvider).
class OutdoorsAdminScreen extends ConsumerStatefulWidget {
  const OutdoorsAdminScreen({super.key});

  @override
  ConsumerState<OutdoorsAdminScreen> createState() => _OutdoorsAdminScreenState();
}

class _OutdoorsAdminScreenState extends ConsumerState<OutdoorsAdminScreen> {
  /// Copia local (reordenavel) da lista carregada -- ReorderableListView
  /// precisa de uma lista mutavel pra dar feedback imediato ao arrastar,
  /// antes da gravacao no banco terminar.
  List<OutdoorModel>? _outdoorsLocais;
  bool _salvandoOrdem = false;

  Future<void> _apagar(OutdoorModel outdoor) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar outdoor'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    await ref.read(outdoorServiceProvider).apagar(outdoor.id);
    setState(() => _outdoorsLocais?.removeWhere((o) => o.id == outdoor.id));
    ref.invalidate(outdoorsProvider);
  }

  Future<void> _reordenar(int oldIndex, int newIndex) async {
    final lista = _outdoorsLocais;
    if (lista == null) return;

    setState(() {
      final item = lista.removeAt(oldIndex);
      lista.insert(newIndex, item);
      _salvandoOrdem = true;
    });

    try {
      await ref.read(outdoorServiceProvider).salvarOrdem(lista.map((o) => o.id).toList());
    } finally {
      if (mounted) setState(() => _salvandoOrdem = false);
      ref.invalidate(outdoorsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outdoorsAsync = ref.watch(outdoorsProvider);

    // So' re-sincroniza a copia local quando os dados do provider
    // chegam (primeira carga, ou depois de invalidate) -- sem isso, o
    // ReorderableListView perderia o arrasto no meio do gesto toda vez
    // que a tela recompoe.
    outdoorsAsync.whenData((outdoors) {
      _outdoorsLocais ??= List.of(outdoors);
    });

    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Outdoors',
        showQrButton: false,
        actions: _salvandoOrdem
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ]
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OutdoorFormScreen()),
          );
          _outdoorsLocais = null;
          ref.invalidate(outdoorsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: outdoorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar outdoors: $err')),
        data: (_) {
          final outdoors = _outdoorsLocais ?? [];
          if (outdoors.isEmpty) {
            return const Center(child: Text('Nenhum outdoor criado ainda.'));
          }
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Arraste pelo ícone ☰ pra mudar a ordem de exibição no slideshow.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: outdoors.length,
                  onReorderItem: _reordenar,
                  itemBuilder: (context, index) {
                    final outdoor = outdoors[index];
                    return Card(
                      key: ValueKey(outdoor.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 72,
                            height: 36,
                            child: Image.network(outdoor.imagemUrl, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(switch (outdoor.tipo) {
                          OutdoorTipo.sempre => 'Sempre ativo',
                          OutdoorTipo.recorrente => 'Recorrente — ${outdoor.semanaDoMes}º domingo',
                          OutdoorTipo.temporario => 'Temporário',
                        }),
                        subtitle: Text(outdoor.ativo ? 'Ativo' : 'Pausado'),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OutdoorFormScreen(outdoorParaEditar: outdoor),
                            ),
                          );
                          _outdoorsLocais = null;
                          ref.invalidate(outdoorsProvider);
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Apagar outdoor',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _apagar(outdoor),
                            ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
