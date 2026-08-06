import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../services/escala_servico_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/awake_app_bar.dart';

class DashboardMinisterioScreen extends StatefulWidget {
  final String ministerio;
  const DashboardMinisterioScreen({super.key, required this.ministerio});

  @override
  State<DashboardMinisterioScreen> createState() => _DashboardMinisterioScreenState();
}

class _DashboardMinisterioScreenState extends State<DashboardMinisterioScreen> {
  final _client = SupabaseService.client;
  bool _carregando = true;

  int _totalMembros = 0;
  int _novosNoMes = 0;
  Map<String, int> _rankingParticipacao = {};
  double? _taxaPreenchimento;

  bool get _temEscalaDeServico => ministeriosComEscalaServico.contains(widget.ministerio);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    final membros = await _client
        .from('profile_ministerios')
        .select('profile_id, criado_em, profiles(nome)')
        .eq('ministerio', widget.ministerio);

    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);

    _totalMembros = (membros as List).length;
    _novosNoMes = membros.where((m) {
      final criadoEm = DateTime.tryParse((m as Map<String, dynamic>)['criado_em'] as String? ?? '');
      return criadoEm != null && !criadoEm.isBefore(inicioMes);
    }).length;

    if (_temEscalaDeServico) {
      final escalas = await _client
          .from('escalas_servico')
          .select('id')
          .eq('ministerio', widget.ministerio)
          .order('data_ocorrencia', ascending: false)
          .limit(8);

      final escalaIds = (escalas as List).map((e) => (e as Map<String, dynamic>)['id']).toList();

      if (escalaIds.isNotEmpty) {
        final posicoes = await _client
            .from('escala_servico_posicoes')
            .select(
              'profile_id, profile_id_2, '
              'profiles!escala_servico_posicoes_profile_id_fkey(nome), '
              'profiles2:profiles!escala_servico_posicoes_profile_id_2_fkey(nome)',
            )
            .inFilter('escala_id', escalaIds);

        var total = 0;
        var preenchidas = 0;
        final contagem = <String, int>{};

        for (final p in posicoes as List) {
          final mapa = p as Map<String, dynamic>;
          total++;
          final nome1 = (mapa['profiles'] as Map<String, dynamic>?)?['nome'] as String?;
          final nome2 = (mapa['profiles2'] as Map<String, dynamic>?)?['nome'] as String?;
          if (nome1 != null) {
            preenchidas++;
            contagem[nome1] = (contagem[nome1] ?? 0) + 1;
          }
          if (nome2 != null) {
            contagem[nome2] = (contagem[nome2] ?? 0) + 1;
          }
        }

        _taxaPreenchimento = total == 0 ? null : preenchidas / total;
        final entradas = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        _rankingParticipacao = {for (final e in entradas.take(10)) e.key: e.value};
      }
    }

    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AwakeAppBar(
        title: 'Dashboard — ${widget.ministerio.labelMinisterio}',
        showQrButton: false,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CardNumero(numero: _totalMembros, rotulo: 'Membros no total'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CardNumero(numero: _novosNoMes, rotulo: 'Novos esse mês'),
                      ),
                    ],
                  ),
                  if (_temEscalaDeServico) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Taxa de preenchimento',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Nas últimas 8 escalas — quantas posições ficaram '
                              'preenchidas de fato',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _taxaPreenchimento ?? 0,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _taxaPreenchimento == null
                                  ? 'Sem escalas registradas ainda'
                                  : '${(_taxaPreenchimento! * 100).toStringAsFixed(0)}% preenchido',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Quem mais serviu (últimas 8 escalas)',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_rankingParticipacao.isEmpty)
                      const Text('Ninguém escalado ainda nesse período.')
                    else
                      ..._rankingParticipacao.entries.map((e) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.emoji_events_outlined),
                            title: Text(e.key),
                            trailing: Text('${e.value}x'),
                          )),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Esse ministério ainda não usa o sistema de escalas — '
                      'só mostramos os dados de membros por enquanto.',
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _CardNumero extends StatelessWidget {
  final int numero;
  final String rotulo;
  const _CardNumero({required this.numero, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text('$numero', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(rotulo, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
