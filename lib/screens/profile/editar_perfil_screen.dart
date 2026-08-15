import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/erro_amigavel.dart';
import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/cep_service.dart';
import '../../widgets/awake_app_bar.dart';

class _CepFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 8) digitos = digitos.substring(0, 8);
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      buffer.write(digitos[i]);
      if (i == 4 && i != digitos.length - 1) buffer.write('-');
    }
    final texto = buffer.toString();
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

/// Edicao de perfil: telefone, endereco e estado civil sao editaveis
/// diretamente pela pessoa. Nome e data de nascimento ficam so pra
/// leitura aqui (correcao passa por um lider, pra evitar fraude de
/// idade/categoria).
class EditarPerfilScreen extends ConsumerStatefulWidget {
  final ProfileModel perfil;
  const EditarPerfilScreen({super.key, required this.perfil});

  @override
  ConsumerState<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends ConsumerState<EditarPerfilScreen> {
  late final TextEditingController _telefoneController;
  late final TextEditingController _cepController;
  late final TextEditingController _ruaController;
  late final TextEditingController _bairroController;
  late final TextEditingController _numeroController;
  late final TextEditingController _complementoController;
  bool _semNumero = false;
  EstadoCivil? _estadoCivil;
  Sexo? _sexo;
  GrupoCasais? _grupoCasais;
  bool _buscandoCep = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _telefoneController = TextEditingController(text: widget.perfil.telefone ?? '');
    _estadoCivil = widget.perfil.estadoCivil;
    _sexo = widget.perfil.sexo;
    _grupoCasais = widget.perfil.grupoCasais;

    // O endereco fica guardado como um texto so ("Rua X, no Y - Bairro Z...").
    // Aqui deixamos os campos em branco pra pessoa preencher de novo se
    // quiser mudar -- mais simples do que tentar "desmontar" o texto antigo.
    _cepController = TextEditingController();
    _ruaController = TextEditingController();
    _bairroController = TextEditingController();
    _numeroController = TextEditingController();
    _complementoController = TextEditingController();
    _cepController.addListener(() {
      final digitos = _cepController.text.replaceAll(RegExp(r'\D'), '');
      if (digitos.length == 8) _buscarEndereco(digitos);
    });
  }

  Future<void> _buscarEndereco(String cep) async {
    setState(() => _buscandoCep = true);
    final endereco = await CepService().buscar(cep);
    if (!mounted) return;
    setState(() {
      _buscandoCep = false;
      if (endereco != null) {
        _ruaController.text = endereco.rua;
        _bairroController.text = endereco.bairro;
      }
    });
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      final campos = <String, dynamic>{
        'telefone': _telefoneController.text.trim(),
        'estado_civil': _estadoCivil?.name,
        'sexo': _sexo?.name,
        'grupo_casais': _grupoCasais?.valorBanco,
      };

      if (_ruaController.text.trim().isNotEmpty) {
        var endereco = _ruaController.text.trim();
        if (_semNumero) {
          endereco += ', s/nº';
        } else if (_numeroController.text.trim().isNotEmpty) {
          endereco += ', nº ${_numeroController.text.trim()}';
        }
        if (_complementoController.text.trim().isNotEmpty) {
          endereco += ' (${_complementoController.text.trim()})';
        }
        if (_bairroController.text.trim().isNotEmpty) {
          endereco += ' - Bairro ${_bairroController.text.trim()}';
        }
        campos['endereco'] = endereco;
      }

      await ref.read(authServiceProvider).updateProfileFields(campos);
      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: ${mensagemDeErroAmigavel(e)}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _abrirAlterarEmail() async {
    final controller = TextEditingController();
    final novoEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alterar e-mail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enviaremos um link de confirmação pro e-mail novo -- ele só passa a '
              'valer depois que você clicar nesse link.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Novo e-mail'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (novoEmail == null || novoEmail.isEmpty || !mounted) return;
    try {
      await ref.read(authServiceProvider).updateEmail(novoEmail);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link de confirmação enviado pro e-mail novo.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao alterar e-mail: ${mensagemDeErroAmigavel(e)}')));
      }
    }
  }

  Future<void> _abrirAlterarSenha() async {
    final senhaController = TextEditingController();
    final confirmarController = TextEditingController();
    final erroEl = ValueNotifier<String?>(null);

    final novaSenha = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: senhaController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmarController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: erroEl,
              builder: (context, erro, _) => erro == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(erro, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (senhaController.text.length < 6) {
                erroEl.value = 'Mínimo de 6 caracteres.';
                return;
              }
              if (senhaController.text != confirmarController.text) {
                erroEl.value = 'As senhas não coincidem.';
                return;
              }
              Navigator.of(dialogContext).pop(senhaController.text);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (novaSenha == null || !mounted) return;
    try {
      await ref.read(authServiceProvider).updatePassword(novaSenha);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao alterar senha: ${mensagemDeErroAmigavel(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Editar perfil', showQrButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Nome (${widget.perfil.nome}) e data de nascimento só podem ser '
                'corrigidos por um líder.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            Text('E-mail', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ref.read(authServiceProvider).currentUserEmail ?? '—',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(onPressed: _abrirAlterarEmail, child: const Text('Alterar')),
              ],
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: _abrirAlterarSenha, child: const Text('Alterar senha')),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefoneController,
              decoration: const InputDecoration(labelText: 'Telefone (WhatsApp)'),
              keyboardType: TextInputType.phone,
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
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Sexo>(
              value: _sexo,
              decoration: const InputDecoration(labelText: 'Sexo'),
              items: const [
                DropdownMenuItem(value: Sexo.masculino, child: Text('Masculino')),
                DropdownMenuItem(value: Sexo.feminino, child: Text('Feminino')),
              ],
              onChanged: (v) => setState(() => _sexo = v),
            ),
            if (_estadoCivil == EstadoCivil.casado && !widget.perfil.pertenceAwake) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<GrupoCasais?>(
                value: _grupoCasais,
                decoration: const InputDecoration(labelText: 'Grupo de casais'),
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
            Text('Endereço', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Endereço atual: ${widget.perfil.endereco ?? "não informado"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cepController,
              decoration: InputDecoration(
                labelText: 'CEP (opcional, pra atualizar)',
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
            if (_semNumero)
              TextFormField(
                controller: _complementoController,
                decoration: const InputDecoration(
                  labelText: 'Complemento (opcional)',
                  hintText: 'Ex: Casa 2, Fundos, Próximo ao mercado...',
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _salvar,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar alterações'),
            ),
          ],
        ),
      ),
    );
  }
}
