import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  EstadoCivil? _estadoCivil;
  bool _buscandoCep = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _telefoneController = TextEditingController(text: widget.perfil.telefone ?? '');
    _estadoCivil = widget.perfil.estadoCivil;

    // O endereco fica guardado como um texto so ("Rua X, no Y - Bairro Z...").
    // Aqui deixamos os campos em branco pra pessoa preencher de novo se
    // quiser mudar -- mais simples do que tentar "desmontar" o texto antigo.
    _cepController = TextEditingController();
    _ruaController = TextEditingController();
    _bairroController = TextEditingController();
    _numeroController = TextEditingController();
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
      };

      if (_ruaController.text.trim().isNotEmpty) {
        var endereco = _ruaController.text.trim();
        if (_numeroController.text.trim().isNotEmpty) {
          endereco += ', nº ${_numeroController.text.trim()}';
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
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
                    decoration: const InputDecoration(labelText: 'Número'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
