import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/questionario_model.dart';
import '../../services/questionario_service.dart';
import '../../widgets/awake_app_bar.dart';

class AdminQuestionariosScreen extends StatefulWidget {
  const AdminQuestionariosScreen({super.key});

  @override
  State<AdminQuestionariosScreen> createState() => _AdminQuestionariosScreenState();
}

class _AdminQuestionariosScreenState extends State<AdminQuestionariosScreen> {
  late Future<List<QuestionarioNovoServo>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = QuestionarioService().listarTodos();
  }

  Future<void> _recarregar() async {
    setState(() => _futuro = QuestionarioService().listarTodos());
    await _futuro;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Questionários de novos servos', showQrButton: false),
      body: RefreshIndicator(
        onRefresh: _recarregar,
        child: FutureBuilder<List<QuestionarioNovoServo>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final lista = snapshot.data ?? [];
            if (lista.isEmpty) {
              return const Center(child: Text('Nenhum questionário respondido ainda.'));
            }

            final naoLidos = lista.where((q) => !q.lido).length;
            final esteMes = lista.where((q) {
              final agora = DateTime.now();
              return q.criadoEm.year == agora.year && q.criadoEm.month == agora.month;
            }).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: _CardResumo(numero: lista.length, rotulo: 'No total')),
                    const SizedBox(width: 8),
                    Expanded(child: _CardResumo(numero: esteMes, rotulo: 'Esse mês')),
                    const SizedBox(width: 8),
                    Expanded(child: _CardResumo(numero: naoLidos, rotulo: 'Não lidos')),
                  ],
                ),
                const SizedBox(height: 20),
                ...lista.map((q) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(q.nomePessoa ?? '(sem nome)'),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(q.criadoEm)),
                        trailing:
                            q.lido ? null : const Icon(Icons.circle, color: Colors.red, size: 10),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...q.respostas.entries.map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.key,
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text('${e.value}'),
                                        ],
                                      ),
                                    )),
                                if (!q.lido)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () async {
                                        await QuestionarioService().marcarComoLido(q.id);
                                        _recarregar();
                                      },
                                      child: const Text('Marcar como lido'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CardResumo extends StatelessWidget {
  final int numero;
  final String rotulo;
  const _CardResumo({required this.numero, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text('$numero',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
