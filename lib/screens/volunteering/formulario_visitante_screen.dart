import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/erro_amigavel.dart';
import '../../services/visitante_service.dart';
import '../../widgets/awake_app_bar.dart';

const _opcoesFe = [
  'Sou cristão e estou ativo na igreja',
  'Sou cristão, mas estou afastado',
  'Estou conhecendo a fé cristã',
  'Não sou cristão',
  'Prefiro não responder',
];

const _opcoesComoConheceu = [
  'Convite de um amigo ou familiar',
  'Redes sociais',
  'Google / Internet',
  'Já conhecia a igreja',
  'Evento ou ação da igreja',
  'Vim acompanhado de alguém',
  'Outro',
];

/// Formulario "Seja Bem-vindo!" -- preenchido pelo voluntario
/// escalado na Recepcao/Primeira Vez, sobre a pessoa que visitou.
class FormularioVisitanteScreen extends StatefulWidget {
  const FormularioVisitanteScreen({super.key});

  @override
  State<FormularioVisitanteScreen> createState() => _FormularioVisitanteScreenState();
}

class _FormularioVisitanteScreenState extends State<FormularioVisitanteScreen> {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _outroController = TextEditingController();
  DateTime? _dataNascimento;
  String? _sexo;
  String? _situacaoFe;
  String? _comoConheceu;
  bool _enviando = false;

  Future<void> _escolherDataNascimento() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Data de nascimento',
    );
    if (data != null) setState(() => _dataNascimento = data);
  }

  Future<void> _enviar() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o nome completo.')));
      return;
    }
    if (_telefoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o celular/WhatsApp.')));
      return;
    }
    if (_sexo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecione o sexo.')));
      return;
    }
    if (_situacaoFe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione como a pessoa se identifica em relação à fé.')),
      );
      return;
    }
    if (_comoConheceu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione como a pessoa conheceu a igreja.')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await VisitanteService().registrar({
        'Nome completo': _nomeController.text.trim(),
        'Celular/WhatsApp': _telefoneController.text.trim(),
        'Data de nascimento':
            _dataNascimento != null ? DateFormat('yyyy-MM-dd').format(_dataNascimento!) : '',
        'Sexo': _sexo,
        'Situação de fé': _situacaoFe,
        'Como conheceu': _comoConheceu == 'Outro' && _outroController.text.trim().isNotEmpty
            ? 'Outro: ${_outroController.text.trim()}'
            : _comoConheceu,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visitante registrado! Obrigado por servir.')),
        );
        setState(() {
          _nomeController.clear();
          _telefoneController.clear();
          _outroController.clear();
          _dataNascimento = null;
          _sexo = null;
          _situacaoFe = null;
          _comoConheceu = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao registrar: ${mensagemDeErroAmigavel(e)}')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _pergunta(String titulo, Widget campo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          campo,
        ],
      ),
    );
  }

  Widget _opcoesRadio<T>(List<T> opcoes, T? valor, ValueChanged<T?> onChanged) {
    return Column(
      children: opcoes
          .map((o) => RadioListTile<T>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(o.toString()),
                value: o,
                groupValue: valor,
                onChanged: onChanged,
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Registrar visitante', showQrButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Seja Bem-vindo! 👋', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Preenche os dados da pessoa que visitou hoje.'),
            const SizedBox(height: 24),

            _pergunta(
              'Nome completo',
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(hintText: 'Como podemos chamar você?'),
              ),
            ),

            _pergunta(
              'Celular / WhatsApp',
              TextField(
                controller: _telefoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '(21) 99999-9999'),
              ),
            ),

            _pergunta(
              'Data de nascimento',
              InkWell(
                onTap: _escolherDataNascimento,
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _dataNascimento == null
                        ? 'Selecionar data'
                        : DateFormat('dd/MM/yyyy').format(_dataNascimento!),
                  ),
                ),
              ),
            ),

            _pergunta(
              'Sexo',
              _opcoesRadio(['Masculino', 'Feminino'], _sexo, (v) => setState(() => _sexo = v)),
            ),

            _pergunta(
              'Como você se identifica atualmente em relação à fé?',
              _opcoesRadio(_opcoesFe, _situacaoFe, (v) => setState(() => _situacaoFe = v)),
            ),

            _pergunta(
              'Como você conheceu a Comunidade Batista Shallom?',
              Column(
                children: [
                  _opcoesRadio(
                    _opcoesComoConheceu,
                    _comoConheceu,
                    (v) => setState(() => _comoConheceu = v),
                  ),
                  if (_comoConheceu == 'Outro')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextField(
                        controller: _outroController,
                        decoration: const InputDecoration(hintText: 'Qual?'),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            FilledButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Registrar visitante'),
            ),
          ],
        ),
      ),
    );
  }
}