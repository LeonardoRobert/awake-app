import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contribuicao_model.dart';
import '../../providers/contribuicao_provider.dart';
import '../../widgets/awake_app_bar.dart';

const _dadosBancarios = 'Banco Santander\n'
    'Ag. 3306 - C.C 13000184-9\n'
    'Favorecido: Comunidade Batista Shallom em Meriti\n'
    'CNPJ: 28.786.515.0001-88';

const _chavePix = 'shallom.financeiro@gmail.com';
const _nomeRecebedor = 'COMUNIDADE SHALLOM';
const _cidadeRecebedor = 'SAO JOAO DE MER';

// Links de pagamento do PagBank -- um por valor fixo (o PagBank nao
// deixa a pessoa editar o valor na hora, entao criamos varias opcoes
// em vez de um valor so).
const _opcoesCartao = [
  (valor: 'R\$ 10', link: 'https://pag.ae/822FezHEv'),
  (valor: 'R\$ 20', link: 'https://pag.ae/822FdrAba'),
  (valor: 'R\$ 50', link: 'https://pag.ae/822FdPysH'),
  (valor: 'R\$ 100', link: 'https://pag.ae/822Feg44v'),
];

const _imagensProjetos = [
  'assets/images/projetos/shallom_humaita_amazonia.png',
  'assets/images/projetos/conexao_asia_africa_jocum.png',
  'assets/images/projetos/mais_missao_igreja_sofredora.png',
  'assets/images/projetos/centro_recuperacao.png',
  'assets/images/projetos/missoes_nacionais.png',
  'assets/images/projetos/missoes_mundiais.png',
  'assets/images/projetos/carreta_missionaria.png',
];

// =========================================================
// Gerador de codigo Pix (BR Code / EMV) -- monta um codigo novo,
// com o VALOR ja embutido nele, seguindo o padrao oficial do Banco
// Central. Sem valor embutido (generico), a pessoa digita o valor
// no proprio banco; com valor, o banco dela ja abre com o valor
// certo, só falta confirmar.
// =========================================================
String _tlv(String id, String value) {
  final tamanho = value.length.toString().padLeft(2, '0');
  return '$id$tamanho$value';
}

int _crc16CcittFalse(String payload) {
  int crc = 0xFFFF;
  for (final unidade in payload.codeUnits) {
    crc ^= (unidade << 8);
    for (var i = 0; i < 8; i++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc & 0xFFFF;
}

/// Gera um codigo Pix "Copia e Cola" com o valor ja embutido.
String gerarCodigoPixComValor(double valor) {
  final valorFormatado = valor.toStringAsFixed(2);
  final infoConta = _tlv('00', 'br.gov.bcb.pix') + _tlv('01', _chavePix);

  final buffer = StringBuffer()
    ..write(_tlv('00', '01')) // Payload Format Indicator
    ..write(_tlv('01', '12')) // Point of Initiation -- 12 = uso unico (valor fixo)
    ..write(_tlv('26', infoConta)) // Info da conta (GUI + chave Pix)
    ..write(_tlv('52', '0000')) // Categoria do comerciante
    ..write(_tlv('53', '986')) // Moeda (986 = BRL)
    ..write(_tlv('54', valorFormatado)) // Valor da transacao
    ..write(_tlv('58', 'BR')) // Pais
    ..write(_tlv('59', _nomeRecebedor)) // Nome do recebedor
    ..write(_tlv('60', _cidadeRecebedor)) // Cidade do recebedor
    ..write(_tlv('62', _tlv('05', '***'))); // Identificador da transacao (generico)

  final semCrc = '${buffer.toString()}6304';
  final crc = _crc16CcittFalse(semCrc).toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$semCrc$crc';
}

// A tesouraria decidiu nao adotar o historico digital de dizimo/oferta
// (conversa com o Leo em 13/08/2026) -- fica so escondido, nao apagado,
// pra caso mude de ideia. O resto da tela (Pix, cartao, projetos) fica.
const _mostrarMinhasContribuicoes = false;

class FinanceiroScreen extends ConsumerStatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  ConsumerState<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends ConsumerState<FinanceiroScreen> {
  // Sempre dia 1 -- so o mes/ano importam pra filtrar o historico.
  late DateTime _mesSelecionado;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesSelecionado = DateTime(agora.year, agora.month, 1);
  }

  bool get _ehMesAtual {
    final agora = DateTime.now();
    return _mesSelecionado.year == agora.year && _mesSelecionado.month == agora.month;
  }

  void _mudarMes(int delta) {
    setState(() {
      _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1);
    });
  }

  void _copiarDadosBancarios(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _dadosBancarios));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados bancários copiados.')),
    );
  }

  // ---------------------------------------------------------
  // Fluxo Pix: Dizimo ou Oferta -> valor -> QR Code dinamico
  // ---------------------------------------------------------
  void _abrirEscolhaPix(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Contribuir via Pix', style: Theme.of(dialogContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'É dízimo ou oferta?',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.church_outlined),
                title: const Text('Dízimo'),
                subtitle: const Text('Pode salvar um valor fixo pras próximas vezes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _abrirValorPix(context, ehDizimo: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: const Text('Oferta'),
                subtitle: const Text('Valor livre, cada vez que quiser'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _abrirValorPix(context, ehDizimo: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirValorPix(BuildContext context, {required bool ehDizimo}) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    double? valorSalvo;
    if (ehDizimo && userId != null) {
      final resposta = await client
          .from('profiles')
          .select('valor_dizimo_padrao')
          .eq('id', userId)
          .maybeSingle();
      final valorBruto = resposta?['valor_dizimo_padrao'];
      if (valorBruto != null) valorSalvo = (valorBruto as num).toDouble();
    }

    if (!context.mounted) return;

    final valorController = TextEditingController(
      text: valorSalvo != null ? valorSalvo.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    var salvarComoFixo = ehDizimo;

    final valorConfirmado = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ehDizimo ? 'Valor do dízimo' : 'Valor da oferta',
                style: Theme.of(dialogContext).textTheme.titleLarge,
              ),
              if (ehDizimo && valorSalvo != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Preenchido com o valor que você salvou — pode editar se quiser.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: valorController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
              ),
              if (ehDizimo) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: salvarComoFixo,
                  onChanged: (v) => setModalState(() => salvarComoFixo = v ?? false),
                  title: const Text('Salvar esse valor como meu dízimo fixo'),
                  subtitle: const Text('Já vem preenchido da próxima vez'),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  final valor = double.tryParse(valorController.text.replaceAll(',', '.'));
                  if (valor == null || valor <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Informe um valor válido.')),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(valor);
                },
                child: const Text('Gerar código Pix'),
              ),
            ],
          ),
        ),
      ),
    );

    if (valorConfirmado == null) return;

    if (ehDizimo && salvarComoFixo && userId != null) {
      await client
          .from('profiles')
          .update({'valor_dizimo_padrao': valorConfirmado})
          .eq('id', userId);
    }

    if (!context.mounted) return;
    _mostrarQrPix(context, valorConfirmado);
  }

  void _mostrarQrPix(BuildContext context, double valor) {
    final codigo = gerarCodigoPixComValor(valor);
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatoMoeda.format(valor), style: Theme.of(dialogContext).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(data: codigo, size: 200),
              ),
              const SizedBox(height: 16),
              Text(
                'Escaneie com a câmera do seu banco, ou copie o código abaixo — '
                'o valor já vem preenchido certinho.',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Código Pix copiado!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código Pix'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirCartao(BuildContext context, String link) async {
    await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
  }

  void _abrirMenuCartao(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Contribuir via cartão', style: Theme.of(dialogContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Escolhe o valor — abre no PagBank, com toda a segurança deles',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ..._opcoesCartao.map((opcao) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _abrirCartao(context, opcao.link);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(opcao.valor),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contribuicoesAsync = ref.watch(minhasContribuicoesProvider);
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Contribua', showQrButton: false),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(minhasContribuicoesProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => _abrirEscolhaPix(context),
              icon: const Icon(Icons.qr_code),
              label: const Text('Contribuir via Pix'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _abrirMenuCartao(context),
              icon: const Icon(Icons.credit_card),
              label: const Text('Contribuir via cartão'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            Text('Como contribuir', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Para ofertas e contribuições:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const SelectableText(_dadosBancarios),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _copiarDadosBancarios(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar dados bancários'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Projetos missionários que apoiamos',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagensProjetos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      _imagensProjetos[index],
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
            if (_mostrarMinhasContribuicoes) ...[
              const SizedBox(height: 32),
              Text('Minhas contribuições', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Só você vê esse histórico. Reseta a cada mês.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Mês anterior',
                    onPressed: () => _mudarMes(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    _capitalizar(DateFormat("MMMM 'de' yyyy", 'pt_BR').format(_mesSelecionado)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    tooltip: 'Próximo mês',
                    onPressed: _ehMesAtual ? null : () => _mudarMes(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              contribuicoesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Erro ao carregar: $err'),
                ),
                data: (todasContribuicoes) {
                  final contribuicoes = todasContribuicoes
                      .where((c) =>
                          c.data.year == _mesSelecionado.year && c.data.month == _mesSelecionado.month)
                      .toList();

                  if (contribuicoes.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nenhuma contribuição nesse mês.'),
                    );
                  }

                  final total = contribuicoes.fold<double>(0, (soma, c) => soma + c.valor);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total do mês',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                formatoMoeda.format(total),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...contribuicoes.map((c) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                '${formatoMoeda.format(c.valor)}'
                                '${c.tipo != null ? ' • ${c.tipo!.label}' : ''}',
                              ),
                              subtitle: Text(
                                '${DateFormat("dd/MM/yyyy", 'pt_BR').format(c.data)}'
                                '${c.horario != null ? ' às ${c.horario}' : ''}'
                                ' • ${c.meioPagamento.label}'
                                '${c.observacao != null && c.observacao!.isNotEmpty ? '\n${c.observacao}' : ''}',
                              ),
                              isThreeLine: c.observacao != null && c.observacao!.isNotEmpty,
                            ),
                          )),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _capitalizar(String texto) =>
      texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
}