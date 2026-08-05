import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/contribuicao_model.dart';
import '../../providers/contribuicao_provider.dart';
import '../../widgets/awake_app_bar.dart';

const _dadosBancarios = 'Banco Santander\n'
    'Ag. 3306 - C.C 13000184-9\n'
    'Favorecido: Comunidade Batista Shallom em Meriti\n'
    'CNPJ: 28.786.515.0001-88';

// Codigo Pix "copia e cola" (BR Code) gerado a partir da chave
// shallom.financeiro@gmail.com. E um codigo ESTATICO/reutilizavel,
// sem valor fixo -- a pessoa que contribui digita o valor no proprio
// banco. Se um dia a chave Pix mudar, so trocar essa constante.
const _codigoPix =
    '00020101021126500014br.gov.bcb.pix0128shallom.financeiro@gmail.com'
    '5204000053039865802BR5918COMUNIDADE SHALLOM6015SAO JOAO DE MER'
    '62070503***630438AA';

class _ProjetoApoiado {
  final String imagem;
  final String nome;
  final String responsavel;
  const _ProjetoApoiado({required this.imagem, required this.nome, required this.responsavel});
}

const _projetosApoiados = [
  _ProjetoApoiado(
    imagem: 'assets/images/projetos/shallom_humaita_amazonia.png',
    nome: 'Shallom Humaitá Amazônia',
    responsavel: 'Pr. Alberto',
  ),
  _ProjetoApoiado(
    imagem: 'assets/images/projetos/conexao_asia_africa_jocum.png',
    nome: 'Conexão Ásia/África Tajiquistão — JOCUM',
    responsavel: 'Pr. Marcos e esposa',
  ),
  _ProjetoApoiado(
    imagem: 'assets/images/projetos/mais_missao_igreja_sofredora.png',
    nome: '+Mais — Missão em apoio à igreja sofredora',
    responsavel: 'Pr. Mário — missões em países muçulmanos',
  ),
  _ProjetoApoiado(
    imagem: 'assets/images/projetos/centro_recuperacao.png',
    nome: 'Centro de Recuperação',
    responsavel: 'Pr. Alonso',
  ),
  _ProjetoApoiado(
    imagem: 'assets/images/projetos/missoes_nacionais.png',
    nome: 'Missões Nacionais',
    responsavel: '',
  ),
  _ProjetoApoiado(
    imagem: 'assets/images/projetos/missoes_mundiais.png',
    nome: 'Missões Mundiais',
    responsavel: '',
  ),
  _ProjetoApoiado(
    imagem: 'assets/images/projetos/carreta_missionaria.png',
    nome: 'Carreta Missionária',
    responsavel: '',
  ),
];

class FinanceiroScreen extends ConsumerWidget {
  const FinanceiroScreen({super.key});

  void _copiarDadosBancarios(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _dadosBancarios));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados bancários copiados.')),
    );
  }

  void _abrirPix(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contribuir via Pix', style: Theme.of(dialogContext).textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(data: _codigoPix, size: 220),
            ),
            const SizedBox(height: 16),
            const Text(
              'Escaneie com a câmera do seu banco, ou copie o código abaixo '
              'e cole na opção "Pix Copia e Cola".',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: _codigoPix));
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Código Pix copiado!')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar código Pix'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirCartao(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contribuição por cartão chega em breve por aqui.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contribuicoesAsync = ref.watch(minhasContribuicoesProvider);
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Contribua', showQrButton: false),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(minhasContribuicoesProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _abrirPix(context),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Via Pix'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _abrirCartao(context),
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Via cartão'),
                  ),
                ),
              ],
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
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _projetosApoiados.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final projeto = _projetosApoiados[index];
                  return SizedBox(
                    width: 150,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(projeto.imagem, fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              projeto.nome,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            if (projeto.responsavel.isNotEmpty)
                              Text(
                                projeto.responsavel,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Text('Minhas contribuições', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Só você vê esse histórico.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            contribuicoesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Erro ao carregar: $err'),
              ),
              data: (contribuicoes) {
                if (contribuicoes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nenhuma contribuição registrada ainda.'),
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
                            const Text('Total contribuído',
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
                            title: Text(formatoMoeda.format(c.valor)),
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
        ),
      ),
    );
  }
}
