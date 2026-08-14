import 'package:flutter/material.dart';
import '../../core/erro_amigavel.dart';
import '../../services/questionario_service.dart';
import '../../widgets/awake_app_bar.dart';

/// PERGUNTAS DE EXEMPLO -- troca pelas de verdade assim que o Leo
/// mandar o questionario oficial. Cada pergunta vira uma chave no
/// JSON salvo (campo "respostas"), entao dá pra trocar livremente
/// sem precisar mexer no banco de novo.
const _perguntas = [
  'Por que você quer servir?',
  'Você já serviu em algum ministério antes? Qual?',
  'Tem alguma disponibilidade ou restrição de horário que devemos saber?',
];

class QuestionarioNovoServoScreen extends StatefulWidget {
  const QuestionarioNovoServoScreen({super.key});

  @override
  State<QuestionarioNovoServoScreen> createState() => _QuestionarioNovoServoScreenState();
}

class _QuestionarioNovoServoScreenState extends State<QuestionarioNovoServoScreen> {
  final _controllers = List.generate(_perguntas.length, (_) => TextEditingController());
  bool _enviando = false;

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final respostas = <String, dynamic>{
        for (var i = 0; i < _perguntas.length; i++) _perguntas[i]: _controllers[i].text.trim(),
      };
      await QuestionarioService().enviar(respostas);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enviado! Obrigado por servir com a gente.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar: ${mensagemDeErroAmigavel(e)}')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Questionário de novo servo', showQrButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Que alegria ter você servindo! Preenche rapidinho essas perguntas.',
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < _perguntas.length; i++) ...[
              Text(_perguntas[i], style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(controller: _controllers[i], maxLines: 3),
              const SizedBox(height: 20),
            ],
            FilledButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
