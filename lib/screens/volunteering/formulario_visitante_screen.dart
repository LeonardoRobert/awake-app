import 'package:flutter/material.dart';
import '../../services/visitante_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Campos de exemplo (padrao de "ficha de visitante") -- ajusta
/// livremente aqui se quiser mudar/adicionar algum.
class FormularioVisitanteScreen extends StatefulWidget {
  const FormularioVisitanteScreen({super.key});

  @override
  State<FormularioVisitanteScreen> createState() => _FormularioVisitanteScreenState();
}

class _FormularioVisitanteScreenState extends State<FormularioVisitanteScreen> {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _comoConheceuController = TextEditingController();
  final _observacoesController = TextEditingController();
  bool _enviando = false;

  Future<void> _enviar() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o nome do visitante.')));
      return;
    }

    setState(() => _enviando = true);
    try {
      await VisitanteService().registrar({
        'Nome completo': _nomeController.text.trim(),
        'Telefone/WhatsApp': _telefoneController.text.trim(),
        'Como conheceu a igreja / quem convidou': _comoConheceuController.text.trim(),
        'Observações': _observacoesController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visitante registrado! Obrigado por servir.')),
        );
        _nomeController.clear();
        _telefoneController.clear();
        _comoConheceuController.clear();
        _observacoesController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
            const Text('Que alegria receber essa pessoa! Preenche os dados dela aqui.'),
            const SizedBox(height: 20),
            const Text('Nome completo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: _nomeController),
            const SizedBox(height: 20),
            const Text('Telefone/WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: _telefoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            const Text('Como conheceu a igreja / quem convidou?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: _comoConheceuController),
            const SizedBox(height: 20),
            const Text('Observações (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: _observacoesController, maxLines: 3),
            const SizedBox(height: 24),
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
