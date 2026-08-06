import 'package:flutter/material.dart';
import '../services/questionario_service.dart';
import '../screens/volunteering/questionario_novo_servo_screen.dart';

/// So aparece no Menu se a pessoa: (1) ja se inscreveu em pelo menos
/// uma escala do Awake alguma vez, e (2) ainda nao respondeu o
/// questionario. Se nenhuma das duas condicoes bater, nao renderiza
/// nada (SizedBox vazio).
class LinkQuestionarioNovoServo extends StatelessWidget {
  const LinkQuestionarioNovoServo({super.key});

  @override
  Widget build(BuildContext context) {
    final service = QuestionarioService();
    return FutureBuilder<List<bool>>(
      future: Future.wait([
        service.jaSeInscreveuEmAlgumaEscala(),
        service.jaRespondeu(),
      ]),
      builder: (context, snapshot) {
        final dados = snapshot.data;
        if (dados == null) return const SizedBox.shrink();
        final jaSeInscreveu = dados[0];
        final jaRespondeu = dados[1];
        if (!jaSeInscreveu || jaRespondeu) return const SizedBox.shrink();

        return Column(
          children: [
            Card(
              color: Colors.amber.withOpacity(0.15),
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('Questionário de novo servo'),
                subtitle: const Text('Preenche rapidinho, é só a primeira vez'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const QuestionarioNovoServoScreen(),
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
