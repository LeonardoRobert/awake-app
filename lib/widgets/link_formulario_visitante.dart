import 'package:flutter/material.dart';
import '../services/visitante_service.dart';
import '../screens/volunteering/formulario_visitante_screen.dart';

/// So aparece pra quem esta escalado na area "Primeira Vez" NO
/// PROPRIO DIA da escala (esta_na_escala_primeira_vez() no banco --
/// ver 2026_primeira_vez_so_no_dia.sql) -- ou pra lider do Awake, que
/// ve sempre, independente de estar escalado.
class LinkFormularioVisitante extends StatelessWidget {
  const LinkFormularioVisitante({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: VisitanteService().podeRegistrarVisitante(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();

        return Column(
          children: [
            Card(
              color: Colors.amber.withOpacity(0.15),
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Registrar visitante'),
                subtitle: const Text('Primeira Vez — cadastra quem você recebeu'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FormularioVisitanteScreen(),
                )),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
