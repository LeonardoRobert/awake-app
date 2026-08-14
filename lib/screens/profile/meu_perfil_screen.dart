import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/erro_amigavel.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/awake_app_bar.dart';
import 'editar_perfil_screen.dart';

/// Tela de detalhes do perfil -- acessada a partir de "Ver meu perfil"
/// no Menu. Mostra tudo que a pessoa cadastrou.
class MeuPerfilScreen extends ConsumerWidget {
  const MeuPerfilScreen({super.key});

  Future<void> _confirmarEApagarConta(BuildContext context, WidgetRef ref) async {
    final confirmacaoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar minha conta'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Isso apaga sua conta e TODOS os seus dados pessoais pra sempre '
                '(dízimos/ofertas, escalas, filhos cadastrados, pedidos de oração...). '
                'Não pode ser desfeito.',
              ),
              const SizedBox(height: 16),
              Text('Digite APAGAR pra confirmar:', style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: 4),
              TextFormField(
                controller: confirmacaoController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v?.trim().toUpperCase() == 'APAGAR' ? null : 'Digite exatamente "APAGAR"',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Apagar pra sempre'),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authServiceProvider).apagarMinhaConta();
      await NotificationService.logoutUser();
      await ref.read(authServiceProvider).signOut();
      // O redirect do GoRouter cuida da navegacao pra tela de login
      // depois do signOut -- so precisa fechar o dialogo de loading.
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível apagar a conta: ${mensagemDeErroAmigavel(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final email = ref.watch(authServiceProvider).currentUserEmail;

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Meu perfil', showQrButton: false),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Perfil não encontrado.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(profile.nome, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar perfil',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EditarPerfilScreen(perfil: profile)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: const Text('Ministério(s)'),
                subtitle: Text(
                  profile.ministerios.isEmpty
                      ? 'Não definido'
                      : profile.ministerios
                          .map((m) => m.ehLider
                              ? '${m.ministerio.labelMinisterio} (líder)'
                              : m.ministerio.labelMinisterio)
                          .join(', '),
                ),
              ),
              if (profile.pertenceAwake)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Grupo'),
                  subtitle: Text(profile.categoria?.label ?? 'Não definido'),
                ),
              if (profile.estadoCivil == EstadoCivil.casado && !profile.pertenceAwake)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Grupo de casais'),
                  subtitle: Text(profile.grupoCasais?.label ?? 'Ainda não tenho grupo'),
                ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _confirmarEApagarConta(context, ref),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Apagar minha conta'),
              ),
            ],
          );
        },
      ),
    );
  }
}
