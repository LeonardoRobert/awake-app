import 'package:flutter/material.dart';
import '../../core/erro_amigavel.dart';
import '../../models/profile_model.dart';
import '../../services/escala_servico_service.dart';
import '../../services/ministerio_presenca_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Check-in em massa pro lider de um ministerio que NAO e' Awake
/// (Homens, Mulheres, Danca, Intercessao, etc) -- escolhe o tipo de
/// ocasiao de HOJE e cola uma lista de nomes, em vez de marcar
/// individualmente. So' conta membros do proprio ministerio (pra
/// alimentar metricas de participacao/ausencia no dashboard dele).
class CheckinMinisterioScreen extends StatefulWidget {
  final String ministerio;
  const CheckinMinisterioScreen({super.key, required this.ministerio});

  @override
  State<CheckinMinisterioScreen> createState() => _CheckinMinisterioScreenState();
}

class _CheckinMinisterioScreenState extends State<CheckinMinisterioScreen> {
  final _service = MinisterioPresencaService();
  final _escalaServicoService = EscalaServicoService();
  final _nomesController = TextEditingController();

  late Future<List<String>> _futuroCatalogo;
  String? _tipoSelecionado;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _futuroCatalogo = _service.listarCatalogo(widget.ministerio);
  }

  @override
  void dispose() {
    _nomesController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final tipo = _tipoSelecionado;
    if (tipo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Escolha o tipo de ocasião.')));
      return;
    }
    final nomes = _nomesController.text
        .split('\n')
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (nomes.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cole ao menos um nome.')));
      return;
    }

    setState(() => _enviando = true);
    try {
      final encontrados = <String>[];
      final naoEncontrados = <String>[];

      for (final nome in nomes) {
        final resultados =
            await _escalaServicoService.buscarPessoasDoMinisterio(widget.ministerio, nome);
        final exatos = resultados.where((p) => p.nome.toLowerCase() == nome.toLowerCase()).toList();
        final pessoa = exatos.length == 1
            ? exatos.first
            : (resultados.length == 1 ? resultados.first : null);

        if (pessoa == null) {
          naoEncontrados.add(nome);
        } else {
          encontrados.add(pessoa.id);
        }
      }

      if (encontrados.isNotEmpty) {
        await _service.checkinEmMassa(
          ministerio: widget.ministerio,
          tipoOcasiao: tipo,
          profileIds: encontrados,
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resultado'),
          content: Text(
            naoEncontrados.isEmpty
                ? '${encontrados.length} pessoa(s) registrada(s) com sucesso.'
                : '${encontrados.length} registrada(s). Não encontrados no '
                    '${widget.ministerio.labelMinisterio} (verifique o nome exato):'
                    '\n\n${naoEncontrados.join('\n')}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      if (mounted) setState(() => _nomesController.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemDeErroAmigavel(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AwakeAppBar(title: 'Check-in — ${widget.ministerio.labelMinisterio}'),
      body: FutureBuilder<List<String>>(
        future: _futuroCatalogo,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar: ${mensagemDeErroAmigavel(snapshot.error!)}'));
          }
          final tipos = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Ocasião de hoje', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tipos.map((tipo) {
                  return ChoiceChip(
                    label: Text(tipo),
                    selected: _tipoSelecionado == tipo,
                    onSelected: (_) => setState(() => _tipoSelecionado = tipo),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Quem esteve presente', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Um nome por linha. Cada um precisa bater com uma pessoa já '
                'cadastrada no ${widget.ministerio.labelMinisterio} -- quem não '
                'bater fica de fora.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nomesController,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  hintText: 'Ana Souza\nBruno Lima\nCarla Mendes...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrar presença'),
              ),
            ],
          );
        },
      ),
    );
  }
}
