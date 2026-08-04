import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/awake_app_bar.dart';
import 'editar_perfil_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final email = ref.watch(authServiceProvider).currentUserEmail;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Perfil'),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Perfil nao encontrado.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    child: Text(
                      profile.nome.isNotEmpty ? profile.nome[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.nome,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _labelPapel(profile.papel.name),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar perfil',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditarPerfilScreen(perfil: profile),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Data de nascimento'),
                subtitle: Text(
                  profile.dataNascimento != null
                      ? DateFormat('dd/MM/yyyy').format(profile.dataNascimento!)
                      : 'Não informado',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('E-mail'),
                subtitle: Text(email ?? 'Não informado'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Celular'),
                subtitle: Text(profile.telefone ?? 'Não informado'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.home_outlined),
                title: const Text('Endereço'),
                subtitle: Text(profile.endereco ?? 'Não informado'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Grupo'),
                subtitle: Text(profile.categoria?.label ?? 'Não definido'),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode_outlined,
                ),
                title: const Text('Modo escuro'),
                value: themeMode == ThemeMode.dark,
                onChanged: (ativado) {
                  ref.read(themeModeProvider.notifier).definir(ativado);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined),
                title: const Text('Treinamentos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/treinamentos'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Termos de uso e privacidade'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/termos'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sair', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await NotificationService.logoutUser();
                  await ref.read(authServiceProvider).signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _labelPapel(String papel) {
    switch (papel) {
      case 'admin':
        return 'Administrador';
      case 'lider':
        return 'Lider';
      default:
        return 'Membro';
    }
  }
}
