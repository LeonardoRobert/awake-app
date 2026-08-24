import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/erro_amigavel.dart';
import '../../models/escala_servico_model.dart';
import '../../models/signup_model.dart';
import '../../providers/shift_provider.dart';

/// Tela do lider: lista quem se inscreveu numa ocorrencia (semana)
/// especifica de uma escala -- e permite escalar manualmente alguem
/// que nao se inscreveu sozinho.
class LeaderShiftDetailScreen extends ConsumerStatefulWidget {
  final String escalaId;
  final DateTime data;

  const LeaderShiftDetailScreen({
    super.key,
    required this.escalaId,
    required this.data,
  });

  @override
  ConsumerState<LeaderShiftDetailScreen> createState() => _LeaderShiftDetailScreenState();
}

class _LeaderShiftDetailScreenState extends ConsumerState<LeaderShiftDetailScreen> {
  bool _escalando = false;

  Future<void> _abrirBuscaDeMembro() async {
    final selecionado = await showDialog<PessoaBusca>(
      context: context,
      builder: (context) => _DialogBuscaMembro(),
    );
    if (selecionado == null) return;

    setState(() => _escalando = true);
    try {
      await ref.read(shiftServiceProvider).inscreverComoLider(
            userId: selecionado.id,
            escalaId: widget.escalaId,
            dataOcorrencia: widget.data,
          );
      ref.invalidate(
        signupsForOccurrenceProvider((escalaId: widget.escalaId, data: widget.data)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selecionado.nome} escalado(a)!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemDeErroAmigavel(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _escalando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signupsAsync = ref.watch(
      signupsForOccurrenceProvider((escalaId: widget.escalaId, data: widget.data)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Inscritos — ${DateFormat('dd/MM/yyyy').format(widget.data)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Fazer check-in',
            onPressed: () => context.push('/checkin'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _escalando ? null : _abrirBuscaDeMembro,
        icon: _escalando
            ? const SizedBox(
                height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.person_add_alt_1),
        label: const Text('Escalar alguém'),
      ),
      body: signupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: ${mensagemDeErroAmigavel(err)}')),
        data: (signups) {
          if (signups.isEmpty) {
            return const Center(child: Text('Ninguém se inscreveu ainda.'));
          }
          return ListView.builder(
            itemCount: signups.length,
            itemBuilder: (context, index) {
              final signup = signups[index];
              final feito = signup.status == SignupStatus.checkInFeito;
              return ListTile(
                leading: Icon(
                  feito ? Icons.check_circle : Icons.person,
                  color: feito ? Colors.green : null,
                ),
                title: Text(signup.userNome ?? 'Membro'),
                subtitle: Text(signup.status.label),
              );
            },
          );
        },
      ),
    );
  }
}

class _DialogBuscaMembro extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DialogBuscaMembro> createState() => _DialogBuscaMembroState();
}

class _DialogBuscaMembroState extends ConsumerState<_DialogBuscaMembro> {
  final _controller = TextEditingController();
  List<PessoaBusca> _resultados = [];
  bool _buscando = false;

  Future<void> _buscar(String query) async {
    setState(() => _buscando = true);
    final resultados = await ref.read(shiftServiceProvider).buscarMembroPorNome(query);
    if (mounted) {
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escalar quem?'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nome da pessoa',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _buscar,
            ),
            const SizedBox(height: 12),
            if (_buscando) const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ) else if (_resultados.isEmpty && _controller.text.trim().length >= 2)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Ninguém encontrado.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resultados.length,
                  itemBuilder: (context, index) {
                    final pessoa = _resultados[index];
                    return ListTile(
                      title: Text(pessoa.nome),
                      onTap: () => Navigator.of(context).pop(pessoa),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
