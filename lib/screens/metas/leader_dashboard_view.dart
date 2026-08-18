import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/meta_mensal_model.dart';
import '../../providers/metas_provider.dart';

class LeaderDashboardView extends ConsumerWidget {
  const LeaderDashboardView({super.key});

  String _categoriaLabel(String? categoria) {
    switch (categoria) {
      case 'genesis':
        return 'Genesis';
      case 'next':
        return 'Next';
      case 'one':
        return 'One';
      default:
        return 'Sem categoria';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingDoMesProvider);
    final porCategoriaAsync = ref.watch(rankingPorCategoriaProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(rankingDoMesProvider);
        ref.invalidate(rankingPorCategoriaProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Participação por grupo (este mês)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          porCategoriaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Erro: $err'),
            data: (mapa) {
              final entradas = mapa.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              if (entradas.isEmpty) {
                return const Text('Sem check-ins registrados este mês ainda.');
              }
              return Card(
                child: Column(
                  children: entradas
                      .map((e) => ListTile(
                            title: Text(_categoriaLabel(e.key)),
                            trailing: Text(
                              '${e.value}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ))
                      .toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Ranking de participação (este mês)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Soma de check-ins em eventos + escalas de voluntariado',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          rankingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Erro: $err'),
            data: (entries) {
              if (entries.isEmpty) {
                return const Text('Sem check-ins registrados este mês ainda.');
              }

              final maisAtivos = entries.take(10).toList();
              final menosAtivos = entries.reversed.take(10).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mais participativos',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _RankingList(entries: maisAtivos),
                  const SizedBox(height: 24),
                  Text('Menos participativos',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _RankingList(entries: menosAtivos),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final List<RankingEntry> entries;
  const _RankingList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: entries
            .map((e) => ListTile(
                  dense: true,
                  title: Text(e.nome),
                  trailing: Text(
                    '${e.total} check-in${e.total == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
