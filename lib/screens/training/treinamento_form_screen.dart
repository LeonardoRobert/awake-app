import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/erro_amigavel.dart';
import '../../models/treinamento_model.dart';
import '../../providers/treinamento_provider.dart';

/// Tela do admin para criar ou editar um treinamento.
/// Se `treinamentoParaEditar` for informado, entra em modo de edicao.
class TreinamentoFormScreen extends ConsumerStatefulWidget {
  final TreinamentoModel? treinamentoParaEditar;
  const TreinamentoFormScreen({super.key, this.treinamentoParaEditar});

  @override
  ConsumerState<TreinamentoFormScreen> createState() => _TreinamentoFormScreenState();
}

class _TreinamentoFormScreenState extends ConsumerState<TreinamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _urlController;
  bool _saving = false;

  bool get _isEdicao => widget.treinamentoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final t = widget.treinamentoParaEditar;
    _tituloController = TextEditingController(text: t?.titulo ?? '');
    _descricaoController = TextEditingController(text: t?.descricao ?? '');
    _urlController = TextEditingController(text: t?.urlVideo ?? '');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(treinamentoServiceProvider);
      if (_isEdicao) {
        await service.update(
          widget.treinamentoParaEditar!.id,
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          urlVideo: _urlController.text.trim(),
        );
      } else {
        await service.create(
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          urlVideo: _urlController.text.trim(),
        );
      }
      ref.invalidate(treinamentosProvider);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdicao ? 'Editar treinamento' : 'Novo treinamento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex: Quem somos nós, Treinamento de Recepção...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Link do YouTube',
                  hintText: 'https://www.youtube.com/watch?v=...',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o link do vídeo' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdicao ? 'Salvar alterações' : 'Publicar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
