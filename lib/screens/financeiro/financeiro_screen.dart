import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/contribuicao_model.dart';
import '../../providers/contribuicao_provider.dart';
import '../../widgets/awake_app_bar.dart';

/// Tela de Financeiro -- comum a qualquer pessoa (nao so Awake). Mostra
/// o proprio historico de contribuicoes (privado, ninguem ve o de
/// outra pessoa) e, sempre visivel, os dados pra contribuir.
///
/// O LANCAMENTO de novas contribuicoes (feito pelo Admin Financeiro)
/// e uma tela separada, construida na Fase 6.
class FinanceiroScreen extends ConsumerWidget {
  const FinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contribuicoesAsync = ref.watch(minhasContribuicoesProvider);
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: const AwakeAppBar(title: 'Financeiro', showQrButton: false),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(minhasContribuicoesProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                            const Text('Total contribuído', style: TextStyle(fontWeight: FontWeight.w600)),
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
            const SizedBox(height: 32),
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
                    const SelectableText(
                      'Banco Santander\n'
                      'Ag. 3306 - C.C 13000184-9\n'
                      'Favorecido: Comunidade Batista Shallom em Meriti\n'
                      'CNPJ: 28.786.515.0001-88',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(
                          text: 'Banco Santander\n'
                              'Ag. 3306 - C.C 13000184-9\n'
                              'Favorecido: Comunidade Batista Shallom em Meriti\n'
                              'CNPJ: 28.786.515.0001-88',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dados bancários copiados.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar dados bancários'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
