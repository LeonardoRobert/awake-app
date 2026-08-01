import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/awake_app_bar.dart';
import 'leader_dashboard_view.dart';
import 'member_metas_view.dart';

/// Aba de Metas e Troféus. Mostra o checklist pessoal para membros,
/// e um dashboard de participação para líderes/admin.
class MetasScreen extends ConsumerWidget {
  const MetasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final isLider = profileAsync.value?.isLider ?? false;

    return Scaffold(
      appBar: AwakeAppBar(title: isLider ? 'Dashboard' : 'Metas e Troféus'),
      body: isLider ? const LeaderDashboardView() : const MemberMetasView(),
    );
  }
}