import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/erro_amigavel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../screens/financeiro/financeiro_screen.dart';
import '../../screens/messages/admin_mensagens_screen.dart';
import '../../screens/messages/enviar_mensagem_screen.dart';
import '../../screens/pages/nossas_paginas_screen.dart';
import '../../models/profile_model.dart';
import '../../screens/calendar/outdoors_admin_screen.dart';
import '../../screens/pages/meus_conteudos_screen.dart';
import '../../screens/pages/nossos_conteudos_screen.dart';
import '../../screens/pages/quem_somos_screen.dart';
import '../../screens/calendar/escala_grade_screen.dart';
import '../../screens/volunteering/admin_visitantes_screen.dart';
import '../../screens/volunteering/dashboard_ministerio_screen.dart';
import '../../services/escala_servico_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/awake_app_bar.dart';
import '../../widgets/link_formulario_visitante.dart';
import 'meu_perfil_screen.dart';

/// Essa tela virou um MENU (antes era a lista direta de dados do
/// perfil -- isso agora fica em "Ver meu perfil" / MeuPerfilScreen).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _enviandoFoto = false;

  Future<void> _trocarFoto() async {
    final picker = ImagePicker();
    final arquivo = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (arquivo == null) return;

    setState(() => _enviandoFoto = true);
    try {
      final Uint8List bytes = await arquivo.readAsBytes();
      await ref.read(authServiceProvider).uploadFotoPerfil(bytes, arquivo.name);
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar foto: ${mensagemDeErroAmigavel(e)}')));
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final email = ref.watch(authServiceProvider).currentUserEmail;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Menu'),
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
                  GestureDetector(
                    onTap: _enviandoFoto ? null : _trocarFoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage:
                              profile.fotoUrl != null ? NetworkImage(profile.fotoUrl!) : null,
                          child: profile.fotoUrl == null
                              ? Text(
                                  profile.nome.isNotEmpty ? profile.nome[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 28),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _enviandoFoto
                                ? const SizedBox(
                                    height: 12,
                                    width: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.nome, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const LinkFormularioVisitante(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Ver meu perfil'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const MeuPerfilScreen())),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('Quem somos nós'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const QuemSomosScreen())),
              ),
              // So aparece aqui pra quem e Awake -- quem e Shallom ja
              // tem isso como aba propria (Início/Calendário/
              // Conteúdos/Contribua/Perfil), nao precisa duplicar.
              if (profile.pertenceAwake) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.ondemand_video_outlined),
                  title: const Text('Nossos Conteúdos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const NossosConteudosScreen())),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public_outlined),
                title: const Text('Nossas páginas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const NossasPaginasScreen())),
              ),
              // So aparece aqui dentro do Menu pra quem e Awake -- os
              // demais ministerios ja tem "Contribua" como aba propria.
              if (profile.pertenceAwake) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Contribua'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const FinanceiroScreen())),
                ),
              ],
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined),
                title: const Text('Treinamentos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/treinamentos'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pan_tool_alt_outlined),
                title: const Text('Pedido de oração'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const EnviarMensagemScreen(
                    tabela: 'pedidos_oracao',
                    titulo: 'Pedido de oração',
                    rotuloCampo: 'Seu pedido de oração',
                    textoExplicativo:
                        'Compartilhe seu pedido — nossa liderança vai orar por você.',
                  ),
                )),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.celebration_outlined),
                title: const Text('Testemunho'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const EnviarMensagemScreen(
                    tabela: 'testemunhos',
                    titulo: 'Testemunho',
                    rotuloCampo: 'Seu testemunho',
                    textoExplicativo: 'Compartilhe o que Deus tem feito na sua vida.',
                  ),
                )),
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
              if (profile.isAdmin) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: const Text('Caixa de entrada'),
                  subtitle: const Text('Pedidos de oração e testemunhos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AdminMensagensScreen())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: const Text('Visitantes — Primeira Vez'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AdminVisitantesScreen(),
                  )),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Meus Conteúdos'),
                  subtitle: const Text('Anexar material aos vídeos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MeusConteudosScreen(),
                  )),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Outdoors'),
                  subtitle: const Text('Banners do slideshow da tela de Início'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const OutdoorsAdminScreen(),
                  )),
                ),
              ],
              if (profile.ministerios
                  .any((m) => m.ehLider && ministeriosComEscalaServico.contains(m.ministerio))) ...[
                ...profile.ministerios
                    .where((m) => m.ehLider && ministeriosComEscalaServico.contains(m.ministerio))
                    .map((m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_note_outlined),
                          title: Text('Escala mensal — ${m.ministerio.labelMinisterio}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EscalaGradeScreen(ministerio: m.ministerio),
                          )),
                        )),
              ],
              if (profile.ministerios.any((m) => m.ehLider)) ...[
                ...profile.ministerios.where((m) => m.ehLider).map((m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bar_chart_outlined),
                      title: Text('Dashboard — ${m.ministerio.labelMinisterio}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DashboardMinisterioScreen(ministerio: m.ministerio),
                      )),
                    )),
              ],
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
}