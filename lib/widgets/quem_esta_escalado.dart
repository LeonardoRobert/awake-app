import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../services/escala_servico_service.dart';

/// Mostra, dentro dos detalhes de um evento, quem esta escalado em
/// cada um dos ministerios de servico -- so leitura (a RLS ja garante
/// que so aparece pra quem tem visibilidade daquele ministerio; pra
/// quem nao tem, a secao correspondente fica vazia/oculta sozinha).
class QuemEstaEscalado extends StatelessWidget {
  final String eventoId;
  final DateTime dataOcorrencia;

  const QuemEstaEscalado({
    super.key,
    required this.eventoId,
    required this.dataOcorrencia,
  });

  @override
  Widget build(BuildContext context) {
    final service = EscalaServicoService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ministeriosComEscalaServico.map((ministerio) {
        return FutureBuilder(
          future: service.listarPosicoesSeExistir(
            ministerio: ministerio,
            eventoId: eventoId,
            dataOcorrencia: dataOcorrencia,
          ),
          builder: (context, snapshot) {
            final posicoes = snapshot.data;
            if (posicoes == null || posicoes.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escalados — ${ministerio.labelMinisterio}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...posicoes.map((p) {
                    final nomes = [
                      if (p.nomePessoa != null) p.nomePessoa!,
                      if (p.nomePessoa2 != null) p.nomePessoa2!,
                    ].join(' e ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${p.funcao}: ${nomes.isEmpty ? "—" : nomes}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
