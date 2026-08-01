import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/meta_mensal_model.dart';
import '../../providers/metas_provider.dart';

class MemberMetasView extends ConsumerWidget {
  const MemberMetasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(metaDoMesProvider);
    final streakAsync = ref.watch(streakAtualProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(metaDoMesProvider);
        ref.invalidate(streakAtualProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Minha meta do mês', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          metaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Erro ao carregar: $err'),
            data: (meta) => _ChecklistCard(meta: meta),
          ),
          const SizedBox(height: 32),
          Text('Meus troféus', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Um troféu novo a cada tanto de meses seguidos com a meta cumprida',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          streakAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Erro ao carregar: $err'),
            data: (streak) => _TrophyGallery(streakMeses: streak),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final MetaMensal meta;
  const _ChecklistCard({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ItemMeta(label: 'EBD', atual: meta.ebd, meta: MetasConfig.ebd, ok: meta.cumpriuEbd),
            const Divider(),
            _ItemMeta(
                label: 'GC', atual: meta.gc, meta: MetasConfig.gc, ok: meta.cumpriuGc),
            const Divider(),
            _ItemMeta(
              label: 'Evento de Comunhão',
              atual: meta.comunhao,
              meta: MetasConfig.comunhao,
              ok: meta.cumpriuComunhao,
            ),
            const Divider(),
            _ItemMeta(
              label: 'Escala de voluntariado',
              atual: meta.escala,
              meta: MetasConfig.escala,
              ok: meta.cumpriuEscala,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: meta.mesCumprido
                    ? Colors.green.withOpacity(0.15)
                    : AwakeColors.lightBlueGrey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    meta.mesCumprido ? Icons.emoji_events : Icons.hourglass_bottom,
                    color: meta.mesCumprido ? Colors.green.shade700 : AwakeColors.navy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meta.mesCumprido
                          ? 'Meta do mês cumprida! 🎉'
                          : 'Ainda em andamento — continue firme.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemMeta extends StatelessWidget {
  final String label;
  final int atual;
  final int meta;
  final bool ok;

  const _ItemMeta({
    required this.label,
    required this.atual,
    required this.meta,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          color: ok ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(
          '$atual/$meta',
          style: TextStyle(fontWeight: FontWeight.w600, color: ok ? Colors.green.shade700 : null),
        ),
      ],
    );
  }
}

class _TrophyGallery extends StatelessWidget {
  final int streakMeses;
  const _TrophyGallery({required this.streakMeses});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trofeus.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final trofeu = trofeus[index];
        final conquistado = streakMeses >= trofeu.meses;

        return Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: conquistado ? AwakeColors.yellow : Colors.grey.shade300,
              child: Icon(
                Icons.emoji_events,
                color: conquistado ? AwakeColors.navy : Colors.grey.shade500,
                size: 30,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trofeu.nome,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: conquistado ? FontWeight.w700 : FontWeight.w400,
                color: conquistado ? null : Colors.grey,
              ),
            ),
            Text(
              '${trofeu.meses} meses',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        );
      },
    );
  }
}