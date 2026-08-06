import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/visitante_model.dart';
import '../../services/visitante_service.dart';
import '../../widgets/awake_app_bar.dart';

class AdminVisitantesScreen extends StatefulWidget {
  const AdminVisitantesScreen({super.key});

  @override
  State<AdminVisitantesScreen> createState() => _AdminVisitantesScreenState();
}

class _AdminVisitantesScreenState extends State<AdminVisitantesScreen> {
  late Future<List<VisitanteModel>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = VisitanteService().listarTodos();
  }

  Future<void> _recarregar() async {
    setState(() => _futuro = VisitanteService().listarTodos());
    await _futuro;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Visitantes — Primeira Vez', showQrButton: false),
      body: RefreshIndicator(
        onRefresh: _recarregar,
        child: FutureBuilder<List<VisitanteModel>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final lista = snapshot.data ?? [];
            if (lista.isEmpty) {
              return const Center(child: Text('Nenhum visitante registrado ainda.'));
            }

            final agora = DateTime.now();
            final inicioSemana = agora.subtract(Duration(days: agora.weekday % 7));
            final inicioSemanaData =
                DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);

            final estaSemana =
                lista.where((v) => !v.criadoEm.isBefore(inicioSemanaData)).length;
            final esteMes = lista
                .where((v) => v.criadoEm.year == agora.year && v.criadoEm.month == agora.month)
                .length;
            final naoLidos = lista.where((v) => !v.lido).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _CardResumo(numero: lista.length, rotulo: 'No total'),
                    _CardResumo(numero: esteMes, rotulo: 'Esse mês'),
                    _CardResumo(numero: estaSemana, rotulo: 'Essa semana'),
                    _CardResumo(numero: naoLidos, rotulo: 'Não lidos'),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Todos os visitantes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...lista.map((v) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(v.dados['Nome completo']?.toString() ?? '(sem nome)'),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(v.criadoEm)}'
                          '${v.nomeRegistrador != null ? ' • registrado por ${v.nomeRegistrador}' : ''}',
                        ),
                        trailing:
                            v.lido ? null : const Icon(Icons.circle, color: Colors.red, size: 10),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...v.dados.entries.map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.key,
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text('${e.value}'.isEmpty ? '—' : '${e.value}'),
                                        ],
                                      ),
                                    )),
                                if (!v.lido)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () async {
                                        await VisitanteService().marcarComoLido(v.id);
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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$numero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
