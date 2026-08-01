import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/treinamento_provider.dart';

class TreinamentosScreen extends ConsumerWidget {
  const TreinamentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treinamentosAsync = ref.watch(treinamentosProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isAdmin = profileAsync.value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Treinamentos')),
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
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final t = lista[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
                  title: Text(t.titulo),
                  subtitle: t.descricao != null
                      ? Text(t.descricao!, maxLines: 2, overflow: TextOverflow.ellipsis)
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
}