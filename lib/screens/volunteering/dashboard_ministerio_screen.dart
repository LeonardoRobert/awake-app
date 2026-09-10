import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // Presenca em ocasioes do ministerio (Ensaio/Reuniao/Culto que
  // servimos/Outro -- ver "Ferramentas da Lideranca" -> check-in em
  // massa, supabase/sql/2026_checkin_ministerio.sql). Totalmente
  // separado da Escala de Servico acima: aqui e' "apareceu na
  // ocasiao", la e' "estava escalado pra servir".
  List<_OcasiaoComContagem> _historicoOcasioes = [];
  double? _mediaPresencaPorOcasiao;
  double? _mediaParticipacaoOcasioes;
  List<String> _pessoasAusentes = [];
  List<String> _pessoasSemParticiparEsseMes = [];

  bool get _ehFaixaEtaria => _faixasEtarias.contains(widget.ministerio);
  bool get _temEscalaDeServico => ministeriosComEscalaServico.contains(widget.ministerio);
  // O check-in em massa por ocasiao existe pra qualquer ministerio que
  // NAO seja Awake (que tem seu proprio check-in/contador, intocado).
  bool get _temOcasioesMinisterio => widget.ministerio != 'awake';

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

    if (_temOcasioesMinisterio) {
      final ocasioesData = await _client
          .from('ocasioes_ministerio')
          .select('id, data, tipo')
          .eq('ministerio', widget.ministerio)
          .order('data', ascending: false)
          .limit(20);
      final ocasioes = (ocasioesData as List).cast<Map<String, dynamic>>();
      final ocasiaoIds = ocasioes.map((o) => o['id'] as String).toList();

      final contagemPorOcasiao = <String, int>{for (final o in ocasioes) o['id'] as String: 0};
      final presentesPorOcasiao = <String, Set<String>>{};

      if (ocasiaoIds.isNotEmpty) {
        final presencasData = await _client
            .from('presencas_ministerio')
            .select('ocasiao_id, profile_id')
            .inFilter('ocasiao_id', ocasiaoIds);
        for (final p in presencasData as List) {
          final mapa = p as Map<String, dynamic>;
          final ocasiaoId = mapa['ocasiao_id'] as String;
          final profileId = mapa['profile_id'] as String;
          contagemPorOcasiao[ocasiaoId] = (contagemPorOcasiao[ocasiaoId] ?? 0) + 1;
          presentesPorOcasiao.putIfAbsent(ocasiaoId, () => {}).add(profileId);
        }
      }

      // Historico + medias usam so' as ultimas 8 ocasioes (mesma janela
      // usada pra Escala de Servico acima, pra ficar consistente).
      final ultimasOito = ocasioes.take(8).toList();
      _historicoOcasioes = ultimasOito
          .map((o) => _OcasiaoComContagem(
                data: DateTime.parse(o['data'] as String),
                tipo: o['tipo'] as String,
                contagem: contagemPorOcasiao[o['id'] as String] ?? 0,
              ))
          .toList();

      // Ocasiao com 0 presenca conta como "nao contabilizada"
      // automaticamente -- sai da media (evita que um check-in vazio/
      // enviado sem querer derrube o numero), mas continua aparecendo
      // no historico (com o badge de 0).
      final ocasioesContadas = ultimasOito
          .where((o) => (contagemPorOcasiao[o['id'] as String] ?? 0) > 0)
          .toList();

      if (ocasioesContadas.isEmpty) {
        _mediaPresencaPorOcasiao = null;
        _mediaParticipacaoOcasioes = null;
        _pessoasAusentes = [];
      } else {
        final contagens = ocasioesContadas.map((o) => contagemPorOcasiao[o['id'] as String] ?? 0);
        _mediaPresencaPorOcasiao = contagens.reduce((a, b) => a + b) / ocasioesContadas.length;
        _mediaParticipacaoOcasioes = _totalMembros == 0
            ? null
            : contagens.map((c) => c / _totalMembros).reduce((a, b) => a + b) / ocasioesContadas.length;

        final presentesNaJanela = <String>{
          for (final o in ocasioesContadas) ...?presentesPorOcasiao[o['id'] as String],
        };
        _pessoasAusentes = listaMembros
            .where((m) => !presentesNaJanela.contains(m['profile_id'] as String))
            .map((m) => (m['profiles'] as Map<String, dynamic>?)?['nome'] as String? ?? '(sem nome)')
            .toList();
      }

      // Alerta mensal: quem nao apareceu em NENHUMA ocasiao desse
      // ministerio dentro do mes corrente ate agora -- so' dashboard,
      // sem notificacao (ver conversa com o Leo). So' calcula se o
      // ministerio ja tem AO MENOS UMA ocasiao registrada -- sem isso,
      // "ninguem participou" seria so' ruido (o check-in nunca foi
      // usado ainda), nao um alerta de verdade.
      if (ocasioes.isEmpty) {
        _pessoasSemParticiparEsseMes = [];
      } else {
        final ocasioesDoMes =
            ocasioes.where((o) => !DateTime.parse(o['data'] as String).isBefore(inicioMes));
        final presentesNoMes = <String>{
          for (final o in ocasioesDoMes) ...?presentesPorOcasiao[o['id'] as String],
        };
        _pessoasSemParticiparEsseMes = listaMembros
            .where((m) => !presentesNoMes.contains(m['profile_id'] as String))
            .map((m) => (m['profiles'] as Map<String, dynamic>?)?['nome'] as String? ?? '(sem nome)')
            .toList();
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
                  ],
                  if (_temOcasioesMinisterio) ...[
                    const SizedBox(height: 16),
                    Text('Presença nas ocasiões do ministério',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'A partir do check-in em massa em "Ferramentas da Liderança" '
                      '(Ensaio, Reunião, Culto que servimos, etc).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (_historicoOcasioes.isEmpty)
                      const Text('Nenhum check-in registrado ainda.')
                    else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Média de presença por ocasião',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                'Nas últimas ${_historicoOcasioes.length} ocasiões registradas',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _mediaPresencaPorOcasiao!.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              if (_mediaParticipacaoOcasioes != null) ...[
                                const SizedBox(height: 16),
                                const Text('Média de participação',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  'Média de quanto dos membros aparece por ocasião',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: _mediaParticipacaoOcasioes!.clamp(0, 1),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(_mediaParticipacaoOcasioes! * 100).toStringAsFixed(0)}% em média',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Histórico de ocasiões',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: _historicoOcasioes
                              .map((o) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.event_available_outlined),
                                    title: Text(o.tipo),
                                    subtitle: Text(DateFormat('dd/MM/yyyy').format(o.data)),
                                    trailing: Text(
                                      o.contagem == 0 ? 'Não contabilizado' : '${o.contagem} presente(s)',
                                      style: o.contagem == 0
                                          ? TextStyle(color: Theme.of(context).disabledColor)
                                          : null,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      if (_pessoasAusentes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Ausentes nas últimas ${_historicoOcasioes.length} ocasiões',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _pessoasAusentes
                                  .map((nome) => Chip(label: Text(nome)))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                    if (_pessoasSemParticiparEsseMes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.red.withOpacity(0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Não participaram de nada esse mês',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _pessoasSemParticiparEsseMes
                                    .map((nome) => Chip(label: Text(nome)))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (!_temEscalaDeServico && !_temOcasioesMinisterio) ...[
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

class _OcasiaoComContagem {
  final DateTime data;
  final String tipo;
  final int contagem;
  const _OcasiaoComContagem({required this.data, required this.tipo, required this.contagem});
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
