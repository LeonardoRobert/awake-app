import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/erro_amigavel.dart';
import '../../models/treinamento_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/treinamento_provider.dart';
import '../../widgets/awake_app_bar.dart';

class TreinamentosScreen extends ConsumerWidget {
  const TreinamentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treinamentosAsync = ref.watch(treinamentosProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isAdmin = profileAsync.value?.isAdmin ?? false;

    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Treinamentos',
        showQrButton: false,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => context.push('/treinamentos/novo'),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(treinamentosProvider.future),
        child: treinamentosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erro ao carregar: $err')),
          data: (lista) {
            if (lista.isEmpty) {
              return const Center(child: Text('Nenhum treinamento publicado ainda.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final t = lista[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
                  title: Text(t.titulo),
                  subtitle: t.descricao != null
                      ? Text(t.descricao!, maxLines: 2, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: isAdmin
                      ? PopupMenuButton<String>(
                          onSelected: (opcao) {
                            switch (opcao) {
                              case 'editar':
                                context.push('/treinamentos/novo', extra: t);
                                break;
                              case 'excluir':
                                _confirmarExclusao(context, ref, t);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Editar'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'excluir',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline, color: Colors.red),
                                title: Text('Excluir', style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        )
                      : null,
                  onTap: () => context.push('/treinamentos/detalhe', extra: t),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    WidgetRef ref,
    TreinamentoModel treinamento,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir treinamento?'),
        content: Text(
          'Isso vai apagar "${treinamento.titulo}" permanentemente. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;

    try {
      await ref.read(treinamentoServiceProvider).delete(treinamento.id);
      ref.invalidate(treinamentosProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Treinamento excluído.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir: ${mensagemDeErroAmigavel(e)}')));
      }
    }
  }
}
