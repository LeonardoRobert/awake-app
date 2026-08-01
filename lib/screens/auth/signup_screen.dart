import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _tempoParticipacaoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _codigoLiderController = TextEditingController();
  DateTime? _dataNascimento;
  EstadoCivil? _estadoCivil;
  bool _aceitouTermos = false;
  bool _quersSerLider = false;
  bool _loading = false;
  String? _errorMessage;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 15, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dataNascimento = picked);
  }

  bool get _isMenorDeIdade {
    if (_dataNascimento == null) return false;
    final idade = DateTime.now().difference(_dataNascimento!).inDays ~/ 365;
    return idade < 18;
  }

  /// Preview de categoria (Genesis/Next/One) so para feedback visual —
  /// o calculo oficial e feito no banco (ver supabase/schema.sql).
  String? get _categoriaPreview {
    if (_estadoCivil == EstadoCivil.noivo || _estadoCivil == EstadoCivil.casado) {
      return 'One';
    }
    if (_dataNascimento == null) return null;
    final idade = DateTime.now().difference(_dataNascimento!).inDays ~/ 365;
    if (idade >= 13 && idade <= 16) return 'Genesis';
    if (idade >= 17) return 'Next';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataNascimento == null) {
      setState(() => _errorMessage = 'Informe a data de nascimento.');
      return;
    }
    if (_estadoCivil == null) {
      setState(() => _errorMessage = 'Informe seu estado civil.');
      return;
    }
    if (!_aceitouTermos) {
      setState(() => _errorMessage = 'E necessario aceitar os termos para continuar.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // 1) cria a conta e o perfil (sempre como membro, por padrao)
      await authService.signUp(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        nome: _nomeController.text.trim(),
        dataNascimento: _dataNascimento!,
        estadoCivil: _estadoCivil!,
        telefone: _telefoneController.text.trim(),
        endereco: _enderecoController.text.trim(),
        tempoParticipacao: _tempoParticipacaoController.text.trim(),
      );

      // 2) se a pessoa marcou "quero ser lider", valida o codigo no
      // backend e eleva o papel (ver supabase/schema.sql: solicitar_papel_lider)
      if (_quersSerLider) {
        try {
          await authService.solicitarPapelLider(_codigoLiderController.text.trim());
        } catch (_) {
          // Cadastro continua valido como membro mesmo se o codigo
          // estiver errado — so avisamos e seguimos.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Codigo de lider invalido. Sua conta foi criada como membro; '
                  'peca o codigo certo e tente de novo depois.',
                ),
              ),
            );
          }
        }
      }
      // O redirect do GoRouter cuida da navegacao apos cadastro.
    } catch (e) {
      setState(() => _errorMessage = 'Nao foi possivel concluir o cadastro. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Voce e...', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Membro')),
                    ButtonSegment(value: true, label: Text('Lider')),
                  ],
                  selected: {_quersSerLider},
                  onSelectionChanged: (value) => setState(() => _quersSerLider = value.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'E-mail invalido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefoneController,
                  decoration: const InputDecoration(labelText: 'Telefone (WhatsApp)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _enderecoController,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tempoParticipacaoController,
                  decoration: const InputDecoration(
                    labelText: 'Há quanto tempo você está no Awake?',
                    hintText: 'Ex: 6 meses, 2 anos, sou novo...',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Minimo de 6 caracteres' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Data de nascimento'),
                    child: Text(
                      _dataNascimento == null
                          ? 'Selecionar data'
                          : DateFormat('dd/MM/yyyy').format(_dataNascimento!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EstadoCivil>(
                  value: _estadoCivil,
                  decoration: const InputDecoration(labelText: 'Estado civil'),
                  items: const [
                    DropdownMenuItem(value: EstadoCivil.solteiro, child: Text('Solteiro(a)')),
                    DropdownMenuItem(value: EstadoCivil.namorando, child: Text('Namorando')),
                    DropdownMenuItem(value: EstadoCivil.noivo, child: Text('Noivo(a)')),
                    DropdownMenuItem(value: EstadoCivil.casado, child: Text('Casado(a)')),
                    DropdownMenuItem(value: EstadoCivil.outro, child: Text('Outro')),
                  ],
                  onChanged: (v) => setState(() => _estadoCivil = v),
                  validator: (v) => v == null ? 'Selecione uma opção' : null,
                ),
                if (_categoriaPreview != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Seu grupo: $_categoriaPreview',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                if (_isMenorDeIdade) ...[
                  const SizedBox(height: 8),
                  const Text(
                    // TODO: implementar fluxo completo de consentimento do responsavel
                    // (ex: campo com nome/contato do responsavel, ou aprovacao manual pelo lider).
                    'Por ser menor de idade, o cadastro requer ciencia de um responsavel. '
                    'Confirme com um responsavel antes de continuar.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
                if (_quersSerLider) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codigoLiderController,
                    decoration: const InputDecoration(
                      labelText: 'Codigo de lider',
                      helperText: 'Pedido com o responsavel pelo Awake',
                    ),
                    validator: (v) {
                      if (!_quersSerLider) return null;
                      return (v == null || v.trim().isEmpty) ? 'Informe o codigo de lider' : null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _aceitouTermos,
                  onChanged: (v) => setState(() => _aceitouTermos = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Li e aceito os termos de uso e privacidade'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Criar conta'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Ja tem conta? Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
