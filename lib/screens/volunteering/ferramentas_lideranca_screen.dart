import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/link_formulario_visitante.dart';
import '../calendar/contador_evento_screen.dart';
import 'checkin_ministerio_screen.dart';

/// Ponto de entrada unico pra ferramentas de lider -- agrupa o que
/// antes aparecia solto no Menu. Nao muda NENHUMA permissao existente:
/// "Contador de evento" continua exatamente como era (so' admin,
/// eventos gerais da igreja); "Registrar visitante" continua a mesma
/// tela/regra de sempre. A novidade de verdade e' o Check-in em massa,
/// um item por ministerio que a pessoa lidera (exceto Awake, que nao
/// muda) -- 100% aditivo, nao mexe em Escala de Servico nem no
/// contador geral.
class FerramentasLiderancaScreen extends ConsumerWidget {
  const FerramentasLiderancaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Ferramentas da Liderança', showQrButton: false),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          final ministeriosLiderados =
              profile.ministerios.where((m) => m.ehLider && m.ministerio != 'awake').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (profile.isAdmin) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('Contador de evento'),
                    subtitle: const Text('EBD, Culto de Celebração e Culto da Família'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ContadorEventoScreen(),
                    )),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              for (final m in ministeriosLiderados) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text('Check-in — ${m.ministerio.labelMinisterio}'),
                    subtitle: const Text('Registre em massa quem esteve presente hoje'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CheckinMinisterioScreen(ministerio: m.ministerio),
                    )),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const LinkFormularioVisitante(),
            ],
          );
        },
      ),
    );
  }
}
