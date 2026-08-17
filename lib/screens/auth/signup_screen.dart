import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/erro_amigavel.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/cep_service.dart';
import '../../services/filho_service.dart';

/// Aplica a mascara dd/mm/aaaa enquanto a pessoa digita uma data,
/// sem precisar de nenhum pacote externo.
class _DataFormatter extends TextInputFormatter {
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
DateTime? _parseData(String texto) {
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

int _calcularIdade(DateTime nascimento) {
  final hoje = DateTime.now();
  var anos = hoje.year - nascimento.year;
  final aniversarioJaPassou = hoje.month > nascimento.month ||
      (hoje.month == nascimento.month && hoje.day >= nascimento.day);
  if (!aniversarioJaPassou) anos--;
  return anos;
}

class _FilhoRascunho {
  final String nome;
  final DateTime dataNascimento;
  _FilhoRascunho({required this.nome, required this.dataNascimento});

  int get idade => _calcularIdade(dataNascimento);
}

/// Todos os ministerios que uma pessoa pode liderar -- e uma lista
/// separada da de "participa"/"serve", porque lideranca nao exige que
/// a pessoa tenha marcado aquele ministerio antes (ex: alguem pode
/// liderar o Awake e so "participar" de Homens).
const _todosMinisteriosLideranca = [
  ('awake', 'Awake'),
  ('homens', 'Homens'),
  ('mulheres', 'Mulheres'),
  ('coral', 'Coral'),
  ('danca', 'Dança'),
  ('diaconos', 'Diáconos'),
  ('intercessao', 'Intercessão'),
  ('louvor', 'Louvor'),
  ('midia', 'Mídia'),
  ('multimidia', 'Multimídia'),
  ('teatro', 'Teatro'),
];

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  int _passo = 0; // 0=Quem e voce, 1=Ministerio, 2=Contato, 3=Criar conta

  final _formKeyPasso0 = GlobalKey<FormState>();
  final _formKeyPasso1 = GlobalKey<FormState>();
  final _formKeyPasso2 = GlobalKey<FormState>();
  final _formKeyPasso3 = GlobalKey<FormState>();

  // Passo 0 -- Quem e voce
  final _nomeController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  DateTime? _dataNascimento;
  Sexo? _sexo;
  EstadoCivil? _estadoCivil;
  bool _temFilhos = false;
  final List<_FilhoRascunho> _filhos = [];

  // Passo 1 -- Ministerio
  bool _preSelecaoMinisterioAplicada = false;
  final Set<String> _ministeriosSelecionados = {}; // 'awake' | 'homens' | 'mulheres'
  GrupoCasais? _grupoCasais;
  final Set<String> _areasServico = {}; // 'coral', 'danca', 'diaconos', etc.

  // Passo 2 -- Contato
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _cepController = TextEditingController();
  final _ruaController = TextEditingController();
  final _bairroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  bool _semNumero = false;
  String _cidadeUf = '';
  bool _buscandoCep = false;
  String? _erroCep;

  // Passo 3 -- Criar conta
  final Map<String, bool> _ehNovoPorMinisterio = {}; // true = novo(a)
  bool _querSerLider = false;
  final Map<String, bool> _liderPorMinisterio = {};
  final _codigoLiderController = TextEditingController();
  bool _aceitouTermos = false;

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dataNascimentoController.addListener(() {
      setState(() {
        _dataNascimento = _parseData(_dataNascimentoController.text);
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
    return _calcularIdade(_dataNascimento!) < 18;
  }

  String? get _categoriaPreview {
    if (_estadoCivil == EstadoCivil.noivo || _estadoCivil == EstadoCivil.casado) {
      return 'One';
    }
    if (_dataNascimento == null) return null;
    final idade = _calcularIdade(_dataNascimento!);
    if (idade >= 13 && idade <= 16) return 'Genesis';
    if (idade >= 17) return 'Next';
    return null;
  }

  /// So roda uma vez, na primeira vez que a pessoa chega no Passo de
  /// Ministerio -- pre-marca um ministerio com base no que ela
  /// respondeu no Passo 0, mas ela ainda pode mudar livremente depois.
  void _aplicarPreSelecaoMinisterioSeNecessario() {
    if (_preSelecaoMinisterioAplicada) return;
    _preSelecaoMinisterioAplicada = true;

    final casado = _estadoCivil == EstadoCivil.casado || _estadoCivil == EstadoCivil.noivo;
    final idade = _dataNascimento != null ? _calcularIdade(_dataNascimento!) : null;

    if (casado) {
      if (_sexo == Sexo.masculino) _ministeriosSelecionados.add('homens');
      if (_sexo == Sexo.feminino) _ministeriosSelecionados.add('mulheres');
    } else if (idade != null && idade > 30) {
      if (_sexo == Sexo.masculino) _ministeriosSelecionados.add('homens');
      if (_sexo == Sexo.feminino) _ministeriosSelecionados.add('mulheres');
    } else {
      _ministeriosSelecionados.add('awake');
    }
  }

  Future<void> _abrirDialogoAdicionarFilho() async {
    final nomeController = TextEditingController();
    final dataController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<_FilhoRascunho>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar filho(a)'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: dataController,
                decoration: const InputDecoration(
                  labelText: 'Data de nascimento',
                  hintText: 'dd/mm/aaaa',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [_DataFormatter()],
                validator: (v) {
                  if (v == null || _parseData(v) == null) return 'Data inválida';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(_FilhoRascunho(
                nome: nomeController.text.trim(),
                dataNascimento: _parseData(dataController.text)!,
              ));
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      setState(() => _filhos.add(resultado));
    }
  }

  void _proximoPasso() {
    final formAtual = [_formKeyPasso0, _formKeyPasso1, _formKeyPasso2, _formKeyPasso3][_passo];
    if (!formAtual.currentState!.validate()) return;

    if (_passo == 0) {
      if (_dataNascimento == null) {
        setState(() => _errorMessage = 'Informe uma data de nascimento válida (dd/mm/aaaa).');
        return;
      }
      if (_sexo == null) {
        setState(() => _errorMessage = 'Selecione o sexo.');
        return;
      }
      if (_estadoCivil == null) {
        setState(() => _errorMessage = 'Informe seu estado civil.');
        return;
      }
      // Aplica a pre-selecao de ministerio bem na hora de entrar no
      // proximo passo, ja com todos os dados do Passo 0 preenchidos.
      _aplicarPreSelecaoMinisterioSeNecessario();
    }

    if (_passo == 1) {
      if (_ministeriosSelecionados.isEmpty) {
        setState(() => _errorMessage = 'Selecione pelo menos um ministério.');
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
      if (_semNumero) {
        linha += ', s/nº';
      } else if (_numeroController.text.trim().isNotEmpty) {
        linha += ', nº ${_numeroController.text.trim()}';
      }
      if (_complementoController.text.trim().isNotEmpty) {
        linha += ' (${_complementoController.text.trim()})';
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

      // Se ao menos um ministerio foi marcado como "sou novo(a)", leva
      // a pessoa pro video de boas-vindas depois do cadastro.
      final algumEhNovo = _ehNovoPorMinisterio.values.any((v) => v);
      final resumoParticipacao = _ministeriosSelecionados
          .map((m) => '${m.labelMinisterio}: '
              '${_ehNovoPorMinisterio[m] == true ? "Novo(a)" : "Já participa"}')
          .join('; ');

      await authService.signUp(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        nome: _nomeController.text.trim(),
        dataNascimento: _dataNascimento!,
        estadoCivil: _estadoCivil!,
        sexo: _sexo!,
        grupoCasais: _grupoCasais,
        telefone: _telefoneController.text.trim(),
        endereco: _enderecoCompleto,
        tempoParticipacao: resumoParticipacao,
        ministerios: [..._ministeriosSelecionados, ..._areasServico],
      );

      // Cadastra os filhos informados no Passo 0 (usa a sessao que
      // acabou de ser criada pelo signUp acima).
      final filhoService = FilhoService();
      for (final filho in _filhos) {
        await filhoService.adicionar(nome: filho.nome, dataNascimento: filho.dataNascimento);
      }

      // Solicita lideranca pra cada ministerio marcado, usando o
      // mesmo codigo unico -- nao precisa ter marcado esse ministerio
      // antes como "participa"/"serve" pra poder liderar ele.
      final ministeriosOndeQuerSerLider =
          _liderPorMinisterio.entries.where((e) => e.value).map((e) => e.key).toList();

      if (ministeriosOndeQuerSerLider.isNotEmpty) {
        final falharam = <String>[];
        for (final ministerio in ministeriosOndeQuerSerLider) {
          try {
            await authService.solicitarPapelLider(
              _codigoLiderController.text.trim(),
              ministerio: ministerio,
            );
          } catch (_) {
            falharam.add(ministerio.labelMinisterio);
          }
        }

        // Usa um dialogo (esperado com await) em vez de SnackBar --
        // logo depois daqui o app navega pra outra tela (ou o proprio
        // router redireciona sozinho pra fora do cadastro assim que a
        // sessao existe), e isso apagava o SnackBar antes da pessoa
        // conseguir ler.
        if (falharam.isNotEmpty && mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Código de líder inválido'),
              content: Text(
                'Não deu pra confirmar liderança em: ${falharam.join(", ")}. '
                'Sua conta foi criada normalmente como membro -- peça pra um '
                'admin te promover a líder direto no gestão, ou peça o código '
                'certo com a liderança.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        }
      }

      if (!mounted) return;

      if (algumEhNovo) {
        context.go('/treinamentos');
      }
    } on AuthApiException catch (e) {
      final mensagem = e.code == 'user_already_exists'
          ? 'Esse e-mail já está cadastrado. Tente entrar, ou use outro e-mail.'
          : 'Não foi possível concluir o cadastro: ${e.message}';
      setState(() => _errorMessage = mensagem);
    } catch (e) {
      // Mostra o erro de verdade (em vez de uma mensagem generica) --
      // assim da pra saber exatamente o que deu errado.
      setState(() => _errorMessage = 'Não foi possível concluir o cadastro: ${mensagemDeErroAmigavel(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulos = ['Quem é você', 'Ministério', 'Contato', 'Criar conta'];
    const totalPassos = 4;

    return Scaffold(
      appBar: AppBar(title: Text('Criar conta — Passo ${_passo + 1} de $totalPassos')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_passo + 1) / totalPassos),
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
                    _buildPassoQuemEhVoce(),
                    _buildPassoMinisterio(),
                    _buildPassoContato(),
                    _buildPassoCriarConta(),
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
                          : (_passo < totalPassos - 1 ? _proximoPasso : _submit),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_passo < totalPassos - 1 ? 'Próximo' : 'Criar conta'),
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

  // ===========================================================
  // Passo 0 -- Quem e voce
  // ===========================================================
  Widget _buildPassoQuemEhVoce() {
    return Form(
      key: _formKeyPasso0,
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
            inputFormatters: [_DataFormatter()],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Informe a data de nascimento';
              if (_parseData(v) == null) return 'Data inválida';
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
          DropdownButtonFormField<Sexo>(
            value: _sexo,
            decoration: const InputDecoration(labelText: 'Sexo'),
            items: const [
              DropdownMenuItem(value: Sexo.masculino, child: Text('Masculino')),
              DropdownMenuItem(value: Sexo.feminino, child: Text('Feminino')),
            ],
            onChanged: (v) => setState(() => _sexo = v),
            validator: (v) => v == null ? 'Selecione uma opção' : null,
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
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _temFilhos,
            onChanged: (v) => setState(() => _temFilhos = v),
            title: const Text('Tenho filhos'),
            subtitle: const Text('Usado pra liberar conteúdo de Crianças e de Embaixadores e Mensageiras'),
          ),
          if (_temFilhos) ...[
            const SizedBox(height: 8),
            ..._filhos.asMap().entries.map((entry) {
              final index = entry.key;
              final filho = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(filho.nome),
                  subtitle: Text('${filho.idade} anos'),
                  trailing: IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _filhos.removeAt(index)),
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _abrirDialogoAdicionarFilho,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar filho(a)'),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================
  // Passo 1 -- Ministerio
  // ===========================================================
  Widget _buildPassoMinisterio() {
    return Form(
      key: _formKeyPasso1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Qual ministério você faz parte?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Já deixamos marcado o mais provável — pode mudar à vontade. Pode marcar até 2',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _ministerioChip('awake', 'Awake'),
              _ministerioChip('homens', 'Homens'),
              _ministerioChip('mulheres', 'Mulheres'),
            ],
          ),
          if (_categoriaPreview != null) ...[
            const SizedBox(height: 8),
            Text(
              'Se marcar Awake, seu grupo lá será: $_categoriaPreview',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
          // So pergunta o grupo de casais pra quem e casado e NAO
          // marcou Awake -- quem e casado e Awake ja cai
          // automaticamente no grupo "One", sem precisar escolher nada.
          if (_estadoCivil == EstadoCivil.casado &&
              !_ministeriosSelecionados.contains('awake')) ...[
            const SizedBox(height: 24),
            const Text('Qual grupo de casais vocês participam?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<GrupoCasais?>(
              value: _grupoCasais,
              decoration: const InputDecoration(labelText: 'Grupo'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Ainda não tenho grupo')),
                DropdownMenuItem(
                  value: GrupoCasais.henriquePatricia,
                  child: Text('Grupo do Henrique e Patrícia'),
                ),
                DropdownMenuItem(
                  value: GrupoCasais.ivaldoSonja,
                  child: Text('Grupo do Ivaldo e Sonja'),
                ),
                DropdownMenuItem(
                  value: GrupoCasais.marceloAndreia,
                  child: Text('Grupo do Marcelo e Andréia'),
                ),
              ],
              onChanged: (v) => setState(() => _grupoCasais = v),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Em qual ministério você serve?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Opcional — pode marcar quantos fizerem sentido',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _areaServicoChip('coral', 'Coral'),
              _areaServicoChip('danca', 'Dança'),
              _areaServicoChip('diaconos', 'Diáconos'),
              _areaServicoChip('intercessao', 'Intercessão'),
              _areaServicoChip('louvor', 'Louvor'),
              _areaServicoChip('midia', 'Mídia'),
              _areaServicoChip('multimidia', 'Multimídia'),
              _areaServicoChip('teatro', 'Teatro'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ministerioChip(String valor, String label) {
    final selecionado = _ministeriosSelecionados.contains(valor);
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (marcado) {
        setState(() {
          if (marcado) {
            if (_ministeriosSelecionados.length >= 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Você pode marcar no máximo 2 ministérios.')),
              );
              return;
            }
            _ministeriosSelecionados.add(valor);
          } else {
            _ministeriosSelecionados.remove(valor);
          }
        });
      },
    );
  }

  Widget _areaServicoChip(String valor, String label) {
    final selecionado = _areasServico.contains(valor);
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (marcado) {
        setState(() {
          if (marcado) {
            _areasServico.add(valor);
          } else {
            _areasServico.remove(valor);
          }
        });
      },
    );
  }

  // ===========================================================
  // Passo 2 -- Contato
  // ===========================================================
  Widget _buildPassoContato() {
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
                  enabled: !_semNumero,
                  decoration: const InputDecoration(labelText: 'Número'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _semNumero,
            onChanged: (v) => setState(() {
              _semNumero = v ?? false;
              if (_semNumero) _numeroController.clear();
            }),
            title: const Text('Sem número'),
          ),
          if (_semNumero) ...[
            TextFormField(
              controller: _complementoController,
              decoration: const InputDecoration(
                labelText: 'Complemento (opcional)',
                hintText: 'Ex: Casa 2, Fundos, Próximo ao mercado...',
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_cidadeUf.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_cidadeUf, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  // ===========================================================
  // Passo 3 -- Criar conta
  // ===========================================================
  Widget _buildPassoCriarConta() {
    return Form(
      key: _formKeyPasso3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Seu(s) ministério(s): '
            '${_ministeriosSelecionados.map((m) => m.labelMinisterio).join(', ')}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          for (final ministerio in _ministeriosSelecionados) ...[
            Text('Você já participa do ${ministerio.labelMinisterio}?',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Sou novo(a)')),
                ButtonSegment(value: false, label: Text('Já participo')),
              ],
              selected: {_ehNovoPorMinisterio[ministerio] ?? true},
              onSelectionChanged: (value) =>
                  setState(() => _ehNovoPorMinisterio[ministerio] = value.first),
            ),
            const SizedBox(height: 20),
          ],
          const Text('Você é líder?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (!_querSerLider)
            OutlinedButton.icon(
              onPressed: () => setState(() => _querSerLider = true),
              icon: const Icon(Icons.add_moderator_outlined),
              label: const Text('Clique aqui se você lidera'),
            )
          else ...[
            Text(
              'De qual ministério? Pode marcar mais de um',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _todosMinisteriosLideranca
                  .map((m) => FilterChip(
                        label: Text(m.$2),
                        selected: _liderPorMinisterio[m.$1] ?? false,
                        onSelected: (marcado) =>
                            setState(() => _liderPorMinisterio[m.$1] = marcado),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codigoLiderController,
              decoration: const InputDecoration(
                labelText: 'Código de líder',
                helperText: 'O mesmo código, pedido com a liderança da igreja',
              ),
              validator: (v) {
                if (!_liderPorMinisterio.values.any((x) => x)) return null;
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
