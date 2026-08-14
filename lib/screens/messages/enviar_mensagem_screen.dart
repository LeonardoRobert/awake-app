import 'package:flutter/material.dart';
import '../../core/erro_amigavel.dart';
import '../../services/mensagem_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela de envio, usada tanto pra Pedido de Oracao quanto Testemunho
/// (o conteudo e praticamente identico, so muda o titulo/rotulo).
class EnviarMensagemScreen extends StatefulWidget {
  final String tabela;
  final String titulo;
  final String rotuloCampo;
  final String textoExplicativo;

  const EnviarMensagemScreen({
    super.key,
    required this.tabela,
    required this.titulo,
    required this.rotuloCampo,
    required this.textoExplicativo,
  });

  @override
  State<EnviarMensagemScreen> createState() => _EnviarMensagemScreenState();
}

class _EnviarMensagemScreenState extends State<EnviarMensagemScreen> {
  final _controller = TextEditingController();
  bool _anonimo = false;
  bool _enviando = false;

  Future<void> _enviar() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Escreva algo antes de enviar.')));
      return;
    }

    setState(() => _enviando = true);
    try {
      await MensagemService(widget.tabela).enviar(
        texto: _controller.text,
        anonimo: _anonimo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enviado! Obrigado por compartilhar.')),
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
      appBar: AwakeAppBar(title: widget.titulo, showQrButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.textoExplicativo, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: widget.rotuloCampo,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonimo,
              onChanged: (v) => setState(() => _anonimo = v),
              title: const Text('Enviar de forma anônima'),
              subtitle: const Text('Se desligado, seu nome vai junto'),
            ),
            const SizedBox(height: 12),
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
