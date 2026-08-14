import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/erro_amigavel.dart';
import '../../providers/auth_provider.dart';

/// Tela aberta quando a pessoa clica no link de recuperacao de senha
/// recebido por e-mail. O Supabase, ao detectar esse link, ja cria uma
/// sessao temporaria de recuperacao -- so falta pedir a senha nova.
class RedefinirSenhaScreen extends ConsumerStatefulWidget {
  const RedefinirSenhaScreen({super.key});

  @override
  ConsumerState<RedefinirSenhaScreen> createState() => _RedefinirSenhaScreenState();
}

class _RedefinirSenhaScreenState extends ConsumerState<RedefinirSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _loading = false;
  String? _erro;
  bool _sucesso = false;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      await ref.read(authServiceProvider).updatePassword(_senhaController.text);
      setState(() => _sucesso = true);
    } catch (e) {
      setState(() => _erro = 'Não foi possível salvar a nova senha: ${mensagemDeErroAmigavel(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sucesso
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Senha atualizada! Você já pode entrar com a nova senha.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Ir para o login'),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Digite sua nova senha.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senhaController,
                        decoration: const InputDecoration(labelText: 'Nova senha'),
                        obscureText: true,
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmarController,
                        decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
                        obscureText: true,
                        validator: (v) => (v != _senhaController.text)
                            ? 'As senhas não são iguais'
                            : null,
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 12),
                        Text(_erro!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _salvar,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar nova senha'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
