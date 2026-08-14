import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/outdoor_model.dart';
import '../../providers/outdoor_provider.dart';
import '../../widgets/awake_app_bar.dart';
import 'outdoor_form_screen.dart';

/// Lista de outdoors existentes (admin ve todos, inclusive pausados,
/// porque outdoors_select libera geral pra is_admin()) -- com jeito de
/// editar ou apagar cada um.
class OutdoorsAdminScreen extends ConsumerWidget {
  const OutdoorsAdminScreen({super.key});

  Future<void> _apagar(BuildContext context, WidgetRef ref, OutdoorModel outdoor) async {
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
    ref.invalidate(outdoorsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outdoorsAsync = ref.watch(outdoorsProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Outdoors', showQrButton: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OutdoorFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: outdoorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar outdoors: $err')),
        data: (outdoors) {
          if (outdoors.isEmpty) {
            return const Center(child: Text('Nenhum outdoor criado ainda.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: outdoors.length,
            itemBuilder: (context, index) {
              final outdoor = outdoors[index];
              return Card(
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OutdoorFormScreen(outdoorParaEditar: outdoor)),
                  ),
                  trailing: IconButton(
                    tooltip: 'Apagar outdoor',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _apagar(context, ref, outdoor),
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
