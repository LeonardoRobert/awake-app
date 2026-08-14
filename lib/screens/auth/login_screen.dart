import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/erro_amigavel.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(
            email: _emailController.text.trim(),
            senha: _senhaController.text,
          );
      // O redirect do GoRouter cuida da navegacao apos login.
    } catch (e) {
      setState(() => _errorMessage = 'Não foi possível entrar. Verifique seu e-mail e senha.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _esqueciSenha() async {
    final emailController = TextEditingController(text: _emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Esqueci minha senha'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Seu e-mail cadastrado'),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(emailController.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !email.contains('@')) return;

    try {
      // Sempre redireciona pra versao web do app (mesmo se o pedido foi
      // feito no Android) -- e o caminho mais simples de garantir que o
      // link do e-mail abre um lugar que sabe processar a redefinicao.
      // Essa URL precisa estar cadastrada no Supabase em
      // Authentication > URL Configuration > Redirect URLs.
      const redirectTo = 'https://leonardorobert.github.io/awake-app/app/';
      await ref.read(authServiceProvider).resetPassword(email, redirectTo: redirectTo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se esse e-mail estiver cadastrado, você vai receber um link pra redefinir a senha.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar o e-mail: ${mensagemDeErroAmigavel(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // O cartao do login e sempre claro (fundo branco fixo) -- por
    // isso, o texto dentro dele tambem precisa ser sempre do tema
    // claro, mesmo que a pessoa tenha deixado o modo escuro ligado
    // antes de sair (senao o texto fica branco sobre fundo branco).
    return Theme(
      data: AppTheme.light(ehAwake: false),
      child: Scaffold(
        backgroundColor: AwakeColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/shallom_logo_white.png',
                    height: 48,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AwakeColors.offWhite,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('E-mail', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => (value == null || !value.contains('@'))
                              ? 'Informe um e-mail válido'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Senha', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _senhaController,
                          decoration: const InputDecoration(),
                          obscureText: true,
                          validator: (value) => (value == null || value.length < 6)
                              ? 'Mínimo de 6 caracteres'
                              : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _esqueciSenha,
                            style: TextButton.styleFrom(foregroundColor: AwakeColors.navy),
                            child: const Text('Esqueci minha senha'),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Entrar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/cadastro'),
                      style: TextButton.styleFrom(foregroundColor: AwakeColors.offWhite),
                      child: const Text('Não tem conta? Cadastre-se'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
