import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/event_model.dart';
import '../providers/contribuicao_provider.dart';

/// Tarja com o nome do evento ingressado (ex: "Conferência Awake 2026")
/// e uma barra mostrando quanto a pessoa ja pagou daquele valor total.
/// Aparece pra todo mundo que ve o evento, mesmo com 0% pago ainda --
/// a barra so anda quando o Admin Financeiro lanca um pagamento pra
/// essa pessoa vinculado a esse evento.
class TarjaEventoIngressado extends ConsumerWidget {
  final EventModel evento;
  const TarjaEventoIngressado({super.key, required this.evento});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valorTotal = evento.valorTotal ?? 0;
    final totalPagoAsync = ref.watch(totalPagoEventoProvider(evento.id));
    final totalPago = totalPagoAsync.value ?? 0;
    final progresso =
        valorTotal > 0 ? (totalPago / valorTotal).clamp(0.0, 1.0) : 0.0;
    final porcentagem = (progresso * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () =>
          context.push('/eventos/${evento.id}', extra: evento.dataInicio),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_num_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evento.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 8,
                backgroundColor: Colors.black.withOpacity(0.08),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              totalPagoAsync.isLoading
                  ? 'Carregando...'
                  : '$porcentagem% pago — R\$ ${totalPago.toStringAsFixed(2)} de '
                      'R\$ ${valorTotal.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
