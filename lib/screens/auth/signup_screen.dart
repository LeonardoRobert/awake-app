import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';

/// Aplica a mascara dd/mm/aaaa enquanto a pessoa digita a data de
/// nascimento, sem precisar de nenhum pacote externo.
class _DataNascimentoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 8) digitos = digitos.substring(0, 8);

    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      buffer.write(digitos[i]);
      if ((i == 1 || i == 3) && i != digitos.length - 1) {
        buffer.write('/');
      }
    }

    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Converte "dd/mm/aaaa" pra DateTime, validando se a data existe de
/// verdade (evita aceitar algo tipo 31/02/2024).
DateTime? _parseDataNascimento(String texto) {
  final partes = texto.split('/');
  if (partes.length != 3) return null;

  final dia = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  final ano = int.tryParse(partes[2]);
  if (dia == null || mes == null || ano == null) return null;
  if (mes < 1 || mes > 12) return null;
  if (ano < 1900 || ano > DateTime.now().year) return null;

  final data = DateTime(ano, mes, dia);
  if (data.year != ano || data.month != mes || data.day != dia) return null;
  return data;
}

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
  final _dataNascimentoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _codigoLiderController = TextEditingController();

  DateTime? _dataNascimento;
  EstadoCivil? _estadoCivil;
  bool _ehNovo = false;
  bool _aceitouTermos = false;
  bool _quersSerLider = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dataNascimentoController.addListener(() {
      setState(() {
        _dataNascimento = _parseDataNascimento(_dataNascimentoController.text);
      });
    });
  }

  bool get _isMenorDeIdade {
    if (_dataNascimento == null) return false;
    final idade = DateTime.now().difference(_dataNascimento!).inDays ~/ 365;
    return idade < 18;
  }

  /// Preview de categoria (Genesis/Next/One) so para feedback visual --
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
      setState(() => _errorMessage = 'Informe uma data de nascimento válida (dd/mm/aaaa).');
      return;
    }
    if (_estadoCivil == null) {
      setState(() => _errorMessage = 'Informe seu estado civil.');
      return;
    }
    if (!_aceitouTermos) {
      setState(() => _errorMessage = 'É necessário aceitar os termos para continuar.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      await authService.signUp(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        nome: _nomeController.text.trim(),
        dataNascimento: _dataNascimento!,
        estadoCivil: _estadoCivil!,
        telefone: _telefoneController.text.trim(),
        endereco: _enderecoController.text.trim(),
        tempoParticipacao: _ehNovo ? 'Novo(a) no Awake' : 'Já participa',
      );

      if (_quersSerLider) {
        try {
          await authService.solicitarPapelLider(_codigoLiderController.text.trim());
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Código de líder inválido. Sua conta foi criada como membro; '
                  'peça o código certo e tente de novo depois.',
                ),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      // Quem e novo no Awake vai direto pro conteudo de apresentacao
      // (Treinamentos), em vez de cair direto na tela principal.
      if (_ehNovo) {
        context.go('/treinamentos');
      }
      // Se nao for novo, o redirect do GoRouter ja cuida de levar pra Home.
    } catch (e) {
      setState(() => _errorMessage = 'Não foi possível concluir o cadastro. Tente novamente.');
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
                const Text('Você é...', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Membro')),
                    ButtonSegment(value: true, label: Text('Líder')),
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
                  validator: (v) => (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
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
                const Text('Você já participa do Awake?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Sou novo(a)')),
                    ButtonSegment(value: false, label: Text('Já participo')),
                  ],
                  selected: {_ehNovo},
                  onSelectionChanged: (value) => setState(() => _ehNovo = value.first),
                ),
                if (_ehNovo) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Depois de concluir o cadastro, vamos te mostrar um vídeo rápido '
                    'sobre quem somos.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dataNascimentoController,
                  decoration: const InputDecoration(
                    labelText: 'Data de nascimento',
                    hintText: 'dd/mm/aaaa',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_DataNascimentoFormatter()],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe a data de nascimento';
                    if (_parseDataNascimento(v) == null) return 'Data inválida';
                    return null;
                  },
                ),
                if (_isMenorDeIdade) ...[
                  const SizedBox(height: 8),
                  const Text(
                    // TODO: implementar fluxo completo de consentimento do responsavel
                    'Por ser menor de idade, o cadastro requer ciência de um responsável. '
                    'Confirme com um responsável antes de continuar.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
                if (_quersSerLider) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codigoLiderController,
                    decoration: const InputDecoration(
                      labelText: 'Código de líder',
                      helperText: 'Pedido com o responsável pelo Awake',
                    ),
                    validator: (v) {
                      if (!_quersSerLider) return null;
                      return (v == null || v.trim().isEmpty) ? 'Informe o código de líder' : null;
                    },
                  ),
                ],
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
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Já tem conta? Entrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}