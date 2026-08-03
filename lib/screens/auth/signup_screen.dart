import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/cep_service.dart';

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

class _CepFormatter extends TextInputFormatter {
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
      if (i == 4 && i != digitos.length - 1) buffer.write('-');
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
  int _passo = 0; // 0, 1, 2

  final _formKeyPasso1 = GlobalKey<FormState>();
  final _formKeyPasso2 = GlobalKey<FormState>();
  final _formKeyPasso3 = GlobalKey<FormState>();

  // Passo 1
  final _nomeController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  DateTime? _dataNascimento;
  EstadoCivil? _estadoCivil;

  // Passo 2
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _cepController = TextEditingController();
  final _ruaController = TextEditingController();
  final _bairroController = TextEditingController();
  final _numeroController = TextEditingController();
  String _cidadeUf = '';
  bool _buscandoCep = false;
  String? _erroCep;

  // Passo 3
  bool _ehNovo = false;
  bool _quersSerLider = false;
  final _codigoLiderController = TextEditingController();
  bool _aceitouTermos = false;

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
    _cepController.addListener(_onCepChanged);
  }

  void _onCepChanged() {
    final digitos = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 8) {
      _buscarEndereco(digitos);
    }
  }

  Future<void> _buscarEndereco(String cep) async {
    setState(() {
      _buscandoCep = true;
      _erroCep = null;
    });

    final endereco = await CepService().buscar(cep);

    if (!mounted) return;
    setState(() {
      _buscandoCep = false;
      if (endereco == null) {
        _erroCep = 'CEP não encontrado — preencha manualmente.';
      } else {
        _ruaController.text = endereco.rua;
        _bairroController.text = endereco.bairro;
        _cidadeUf = '${endereco.cidade}/${endereco.estado}';
      }
    });
  }

  bool get _isMenorDeIdade {
    if (_dataNascimento == null) return false;
    final idade = DateTime.now().difference(_dataNascimento!).inDays ~/ 365;
    return idade < 18;
  }

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

  void _proximoPasso() {
    final formAtual = [_formKeyPasso1, _formKeyPasso2, _formKeyPasso3][_passo];
    if (!formAtual.currentState!.validate()) return;

    if (_passo == 0) {
      if (_dataNascimento == null) {
        setState(() => _errorMessage = 'Informe uma data de nascimento válida (dd/mm/aaaa).');
        return;
      }
      if (_estadoCivil == null) {
        setState(() => _errorMessage = 'Informe seu estado civil.');
        return;
      }
    }

    setState(() {
      _errorMessage = null;
      _passo++;
    });
  }

  void _passoAnterior() {
    setState(() {
      _errorMessage = null;
      _passo--;
    });
  }

  String get _enderecoCompleto {
    final partes = <String>[];
    if (_ruaController.text.trim().isNotEmpty) {
      var linha = _ruaController.text.trim();
      if (_numeroController.text.trim().isNotEmpty) {
        linha += ', nº ${_numeroController.text.trim()}';
      }
      partes.add(linha);
    }
    if (_bairroController.text.trim().isNotEmpty) {
      partes.add('Bairro ${_bairroController.text.trim()}');
    }
    if (_cidadeUf.isNotEmpty) partes.add(_cidadeUf);
    if (_cepController.text.trim().isNotEmpty) partes.add('CEP ${_cepController.text.trim()}');
    return partes.join(' - ');
  }

  Future<void> _submit() async {
    if (!_formKeyPasso3.currentState!.validate()) return;
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
        endereco: _enderecoCompleto,
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

      if (_ehNovo) {
        context.go('/treinamentos');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Não foi possível concluir o cadastro. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulos = ['Quem é você', 'Contato', 'Awake'];

    return Scaffold(
      appBar: AppBar(title: Text('Criar conta — Passo ${_passo + 1} de 3')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_passo + 1) / 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(titulos[_passo], style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: IndexedStack(
                  index: _passo,
                  children: [
                    _buildPasso1(),
                    _buildPasso2(),
                    _buildPasso3(),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_passo > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _passoAnterior,
                        child: const Text('Voltar'),
                      ),
                    ),
                  if (_passo > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : (_passo < 2 ? _proximoPasso : _submit),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_passo < 2 ? 'Próximo' : 'Criar conta'),
                    ),
                  ),
                ],
              ),
            ),
            if (_passo == 0)
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Já tem conta? Entrar'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasso1() {
    return Form(
      key: _formKeyPasso1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nomeController,
            decoration: const InputDecoration(labelText: 'Nome completo'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
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
              'Por ser menor de idade, o cadastro requer ciência de um responsável. '
              'Confirme com um responsável antes de continuar.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
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
        ],
      ),
    );
  }

  Widget _buildPasso2() {
    return Form(
      key: _formKeyPasso2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            controller: _senhaController,
            decoration: const InputDecoration(labelText: 'Senha'),
            obscureText: true,
            validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
          ),
          const SizedBox(height: 24),
          Text('Endereço', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: _cepController,
            decoration: InputDecoration(
              labelText: 'CEP',
              hintText: '00000-000',
              suffixIcon: _buscandoCep
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [_CepFormatter()],
          ),
          if (_erroCep != null) ...[
            const SizedBox(height: 4),
            Text(_erroCep!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _ruaController,
            decoration: const InputDecoration(labelText: 'Rua'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _bairroController,
                  decoration: const InputDecoration(labelText: 'Bairro'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _numeroController,
                  decoration: const InputDecoration(labelText: 'Número'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (_cidadeUf.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_cidadeUf, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildPasso3() {
    return Form(
      key: _formKeyPasso3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Você já participa do Awake?', style: TextStyle(fontWeight: FontWeight.w600)),
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
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _aceitouTermos,
                onChanged: (v) => setState(() => _aceitouTermos = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    children: [
                      const Text('Li e aceito os '),
                      GestureDetector(
                        onTap: () => context.push('/termos'),
                        child: Text(
                          'termos de uso e privacidade',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
