import 'package:flutter/material.dart';
import '../services/visitante_service.dart';
import '../screens/volunteering/formulario_visitante_screen.dart';

/// So aparece pra quem esta escalado na area "Primeira Vez" -- fica
/// sempre visivel (nao some depois de usar uma vez), porque a pessoa
/// vai usar isso toda vez que receber um visitante novo.
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
