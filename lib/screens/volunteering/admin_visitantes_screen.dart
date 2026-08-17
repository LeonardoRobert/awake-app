import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ---- copiar pro WhatsApp ----

  /// Texto pronto pra colar no WhatsApp -- nome, contato e situação de
  /// fé são o que mais importa pra quem vai fazer o acompanhamento.
  String _textoParaWhatsApp(VisitanteModel v) {
    final nome = v.dados['Nome completo']?.toString() ?? '(sem nome)';
    final contato = v.dados['Celular/WhatsApp']?.toString() ?? '—';
    final situacao = v.dados['Situação de fé']?.toString() ?? '—';
    return 'Nome: $nome\nContato: $contato\nSituação de fé: $situacao';
  }

  Future<void> _copiar(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiado! Já pode colar no WhatsApp.')),
      );
    }
  }

  // ---- calculos das estatisticas ----

  int? _idade(VisitanteModel v) {
    final texto = v.dados['Data de nascimento']?.toString();
    if (texto == null || texto.isEmpty) return null;
    final nascimento = DateTime.tryParse(texto);
    if (nascimento == null) return null;
    final hoje = DateTime.now();
    var idade = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }
    return idade;
  }

  /// Conta quantas vezes cada valor aparece num campo, ordenado do
  /// mais comum pro menos comum -- usado pra "Situacao de fe" e
  /// "Como conheceu".
  List<MapEntry<String, int>> _contagemPorCampo(List<VisitanteModel> lista, String campo) {
    final contagem = <String, int>{};
    for (final v in lista) {
      final valor = v.dados[campo]?.toString();
      if (valor == null || valor.isEmpty) continue;
      // Agrupa qualquer "Outro: xyz" sob um unico rotulo "Outro",
      // pra nao espalhar o grafico em dezenas de respostas unicas.
      final chave = valor.startsWith('Outro:') ? 'Outro' : valor;
      contagem[chave] = (contagem[chave] ?? 0) + 1;
    }
    final entradas = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entradas;
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

            // ---- estatisticas novas ----
            final idades = lista.map(_idade).whereType<int>().toList();
            final mediaIdade =
                idades.isEmpty ? null : (idades.reduce((a, b) => a + b) / idades.length);

            final porSexo = _contagemPorCampo(lista, 'Sexo');
            final porFe = _contagemPorCampo(lista, 'Situação de fé');
            final porComoConheceu = _contagemPorCampo(lista, 'Como conheceu');

            final situacaoMaisComum = porFe.isEmpty ? null : porFe.first;
            final comoConheceuMaisComum = porComoConheceu.isEmpty ? null : porComoConheceu.first;

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
                Text('Perfil dos visitantes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _linhaEstatistica(
                          'Idade média',
                          mediaIdade == null ? '—' : '${mediaIdade.toStringAsFixed(0)} anos',
                        ),
                        _linhaEstatistica(
                          'Situação de fé mais comum',
                          situacaoMaisComum == null
                              ? '—'
                              : '${situacaoMaisComum.key} (${situacaoMaisComum.value})',
                        ),
                        _linhaEstatistica(
                          'Como mais conheceram a igreja',
                          comoConheceuMaisComum == null
                              ? '—'
                              : '${comoConheceuMaisComum.key} (${comoConheceuMaisComum.value})',
                        ),
                        if (porSexo.isNotEmpty) ...[
                          const Divider(height: 24),
                          Text('Sexo', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          ...porSexo.map((e) => _barraProporcao(e.key, e.value, lista.length)),
                        ],
                        if (porFe.isNotEmpty) ...[
                          const Divider(height: 24),
                          Text('Situação de fé — tudo', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          ...porFe.map((e) => _barraProporcao(e.key, e.value, lista.length)),
                        ],
                        if (porComoConheceu.isNotEmpty) ...[
                          const Divider(height: 24),
                          Text('Como conheceu — tudo', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          ...porComoConheceu.map((e) => _barraProporcao(e.key, e.value, lista.length)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Todos os visitantes', style: Theme.of(context).textTheme.titleMedium),
                ..._agruparPorDia(lista).expand((grupo) {
                  final dataFormatada =
                      DateFormat('EEEE, dd/MM/yyyy', 'pt_BR').format(grupo.first.criadoEm);
                  final textoDoDia = grupo.map(_textoParaWhatsApp).join('\n\n');
                  return [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(dataFormatada, style: Theme.of(context).textTheme.titleSmall),
                          ),
                          TextButton.icon(
                            onPressed: () => _copiar(
                              'Visitantes de $dataFormatada (${grupo.length}):\n\n$textoDoDia',
                            ),
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Copiar dia'),
                          ),
                        ],
                      ),
                    ),
                    ...grupo.map(_cardVisitante),
                  ];
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Agrupa por dia do cadastro (a lista ja vem ordenada do mais
  /// recente pro mais antigo, e a ordem se mantem dentro de cada
  /// grupo).
  List<List<VisitanteModel>> _agruparPorDia(List<VisitanteModel> lista) {
    final porDia = <String, List<VisitanteModel>>{};
    final ordemDias = <String>[];
    for (final v in lista) {
      final chave = DateFormat('yyyy-MM-dd').format(v.criadoEm);
      if (!porDia.containsKey(chave)) {
        porDia[chave] = [];
        ordemDias.add(chave);
      }
      porDia[chave]!.add(v);
    }
    return ordemDias.map((chave) => porDia[chave]!).toList();
  }

  Widget _cardVisitante(VisitanteModel v) {
    final idade = _idade(v);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(v.dados['Nome completo']?.toString() ?? '(sem nome)'),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(v.criadoEm)}'
          '${idade != null ? ' • $idade anos' : ''}'
          '${v.nomeRegistrador != null ? ' • registrado por ${v.nomeRegistrador}' : ''}',
        ),
        trailing: v.lido ? null : const Icon(Icons.circle, color: Colors.red, size: 10),
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
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${e.value}'.isEmpty ? '—' : '${e.value}'),
                        ],
                      ),
                    )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _copiar(_textoParaWhatsApp(v)),
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copiar'),
                    ),
                    if (!v.lido)
                      TextButton(
                        onPressed: () async {
                          await VisitanteService().marcarComoLido(v.id);
                          _recarregar();
                        },
                        child: const Text('Marcar como lido'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaEstatistica(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(rotulo)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraProporcao(String rotulo, int quantidade, int total) {
    final proporcao = total > 0 ? quantidade / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(rotulo, style: const TextStyle(fontSize: 13))),
              Text('$quantidade', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: proporcao, minHeight: 6),
          ),
        ],
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