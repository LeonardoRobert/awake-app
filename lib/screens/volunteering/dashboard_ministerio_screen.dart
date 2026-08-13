import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../services/escala_servico_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Ministerios de "faixa etaria" -- os demais (que tiverem escala de
/// servico ou nao) sao tratados como "area de servico" pra fins do
/// cruzamento mostrado no dashboard.
const _faixasEtarias = ['awake', 'homens', 'mulheres'];

const _labelEstadoCivil = {
  'solteiro': 'Solteiro(a)',
  'namorando': 'Namorando',
  'noivo': 'Noivo(a)',
  'casado': 'Casado(a)',
  'outro': 'Outro',
  'nao_informado': 'Não informado',
};

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
  double? _mediaIdade;
  Map<String, int> _estadosCivis = {};
  /// Faixa-etaria -> contagem de "tambem serve em" (por area de
  /// servico). Area de servico -> contagem de "faixa etaria de onde
  /// vem" (awake/homens/mulheres).
  Map<String, int> _distribuicaoCruzada = {};
  double? _percentualServindo;
  Map<String, int> _rankingParticipacao = {};
  double? _taxaPreenchimento;

  bool get _ehFaixaEtaria => _faixasEtarias.contains(widget.ministerio);
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
        .select('profile_id, criado_em, profiles(nome, data_nascimento, estado_civil)')
        .eq('ministerio', widget.ministerio);
    final listaMembros = (membros as List).cast<Map<String, dynamic>>();
    final profileIds = listaMembros.map((m) => m['profile_id'] as String).toList();

    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);

    _totalMembros = listaMembros.length;
    _novosNoMes = listaMembros.where((m) {
      final criadoEm = DateTime.tryParse(m['criado_em'] as String? ?? '');
      return criadoEm != null && !criadoEm.isBefore(inicioMes);
    }).length;

    // Idade media + estado civil, a partir dos proprios dados de profiles
    // (ja e leitura aberta pra qualquer logado, nao precisa de policy nova).
    final idades = <int>[];
    final contagemEstadoCivil = <String, int>{};
    for (final m in listaMembros) {
      final perfil = m['profiles'] as Map<String, dynamic>?;
      final nascStr = perfil?['data_nascimento'] as String?;
      final nasc = nascStr != null ? DateTime.tryParse(nascStr) : null;
      if (nasc != null) {
        var idade = agora.year - nasc.year;
        if (agora.month < nasc.month || (agora.month == nasc.month && agora.day < nasc.day)) {
          idade--;
        }
        idades.add(idade);
      }
      final estadoCivil = (perfil?['estado_civil'] as String?) ?? 'nao_informado';
      contagemEstadoCivil[estadoCivil] = (contagemEstadoCivil[estadoCivil] ?? 0) + 1;
    }
    _mediaIdade = idades.isEmpty ? null : idades.reduce((a, b) => a + b) / idades.length;
    _estadosCivis = contagemEstadoCivil;

    // Cruzamento com outros ministerios de cada membro -- pra faixa
    // etaria, mostra em quais areas de servico eles tambem estao; pra
    // area de servico, mostra de qual faixa etaria eles vem.
    if (profileIds.isNotEmpty) {
      final outrosVinculos = await _client
          .from('profile_ministerios')
          .select('profile_id, ministerio')
          .inFilter('profile_id', profileIds)
          .neq('ministerio', widget.ministerio);

      final contagemCruzada = <String, int>{};
      for (final v in outrosVinculos as List) {
        final ministerio = (v as Map<String, dynamic>)['ministerio'] as String;
        final relevante = _ehFaixaEtaria
            ? !_faixasEtarias.contains(ministerio) // areas de servico
            : _faixasEtarias.contains(ministerio); // faixa etaria
        if (!relevante) continue;
        contagemCruzada[ministerio] = (contagemCruzada[ministerio] ?? 0) + 1;
      }
      _distribuicaoCruzada = contagemCruzada;
    } else {
      _distribuicaoCruzada = {};
    }

    if (_temEscalaDeServico) {
      final escalas = await _client
          .from('escalas_servico')
          .select('id')
          .eq('ministerio', widget.ministerio)
          .order('data_ocorrencia', ascending: false)
          .limit(8);

      final escalaIds = (escalas as List).map((e) => (e as Map<String, dynamic>)['id']).toList();

      // Comeca todo mundo do ministerio em 0, pra o ranking mostrar
      // tambem quem nunca foi escalado -- nao so quem ja apareceu.
      final contagem = <String, int>{
        for (final m in listaMembros)
          ((m['profiles'] as Map<String, dynamic>?)?['nome'] as String? ?? '(sem nome)'): 0,
      };
      var total = 0;
      var preenchidas = 0;

      if (escalaIds.isNotEmpty) {
        final posicoes = await _client
            .from('escala_servico_posicoes')
            .select(
              'profile_id, profile_id_2, '
              'profiles!escala_servico_posicoes_profile_id_fkey(nome), '
              'profiles2:profiles!escala_servico_posicoes_profile_id_2_fkey(nome)',
            )
            .inFilter('escala_id', escalaIds);

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
      }

      _taxaPreenchimento = total == 0 ? null : preenchidas / total;
      _percentualServindo = _totalMembros == 0
          ? null
          : contagem.values.where((v) => v > 0).length / _totalMembros;
      _rankingParticipacao = contagem;
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
                  if (_mediaIdade != null) ...[
                    const SizedBox(height: 8),
                    _CardNumero(
                      numero: _mediaIdade!.round(),
                      rotulo: 'Idade média (anos)',
                    ),
                  ],
                  if (_estadosCivis.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Estado civil', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _CardPorcentagens(contagem: _estadosCivis, total: _totalMembros, labels: _labelEstadoCivil),
                  ],
                  if (_distribuicaoCruzada.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _ehFaixaEtaria ? 'Também servem em' : 'De onde vêm (faixa etária)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _CardPorcentagens(
                      contagem: _distribuicaoCruzada,
                      total: _totalMembros,
                      labelFn: (k) => k.labelMinisterio,
                    ),
                  ],
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
                            if (_percentualServindo != null) ...[
                              const SizedBox(height: 16),
                              const Text('Quem está servindo',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                'Dos membros do ministério, quantos apareceram '
                                'em pelo menos 1 posição nas últimas 8 escalas',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: _percentualServindo!,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(_percentualServindo! * 100).toStringAsFixed(0)}% estão servindo',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SecaoRanking(rankingCompleto: _rankingParticipacao),
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

/// Lista de barras de porcentagem a partir de uma contagem bruta --
/// usada tanto pra estado civil quanto pro cruzamento entre grupos.
class _CardPorcentagens extends StatelessWidget {
  final Map<String, int> contagem;
  final int total;
  final Map<String, String>? labels;
  final String Function(String chave)? labelFn;

  const _CardPorcentagens({
    required this.contagem,
    required this.total,
    this.labels,
    this.labelFn,
  });

  String _label(String chave) => labelFn?.call(chave) ?? labels?[chave] ?? chave;

  @override
  Widget build(BuildContext context) {
    final entradas = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: entradas.map((e) {
            final pct = total == 0 ? 0.0 : e.value / total;
            return ListTile(
              dense: true,
              title: Text(_label(e.key)),
              trailing: Text(
                '${e.value} · ${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// "Mais participativos" / "Menos participativos", a partir de um
/// ranking que ja inclui todo mundo do ministerio (mesmo quem nunca
/// foi escalado, com contagem 0).
class _SecaoRanking extends StatelessWidget {
  final Map<String, int> rankingCompleto;
  const _SecaoRanking({required this.rankingCompleto});

  @override
  Widget build(BuildContext context) {
    if (rankingCompleto.isEmpty) {
      return const Text('Ninguém cadastrado nesse ministério ainda.');
    }
    final entradas = rankingCompleto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maisAtivos = entradas.take(10).toList();
    final menosAtivos = entradas.reversed.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mais participativos (últimas 8 escalas)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ListaRanking(entradas: maisAtivos),
        const SizedBox(height: 24),
        Text('Menos participativos (últimas 8 escalas)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ListaRanking(entradas: menosAtivos),
      ],
    );
  }
}

class _ListaRanking extends StatelessWidget {
  final List<MapEntry<String, int>> entradas;
  const _ListaRanking({required this.entradas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: entradas
            .map((e) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(e.key),
                  trailing: Text('${e.value}x'),
                ))
            .toList(),
      ),
    );
  }
}
