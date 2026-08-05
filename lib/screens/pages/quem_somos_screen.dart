import 'package:flutter/material.dart';
import '../../widgets/awake_app_bar.dart';

/// O texto abaixo e um RASCUNHO pra voce revisar e ajustar como
/// preferir -- eu nao tinha o texto oficial "quem somos" da igreja,
/// entao escrevi algo generico. Procura por "TEXTO_QUEM_SOMOS" pra
/// achar rapido e trocar.
const _textoQuemSomos = '''
Somos a Comunidade Batista Shallom, uma igreja que existe para levar
as pessoas a um encontro genuíno com Deus, formando uma comunidade de
fé, amor e propósito.

Dentro da Shallom, ministramos a diferentes públicos: o Awake reúne
os jovens; os ministérios de Homens e Mulheres cuidam da caminhada de
cada um nessa fase da vida; e cuidamos com carinho também das
crianças e das famílias da nossa igreja.

Acreditamos que a igreja é, antes de tudo, gente cuidando de gente —
por isso, seja muito bem-vindo(a). Este é o seu lugar.
''';

class QuemSomosScreen extends StatelessWidget {
  const QuemSomosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Quem somos nós', showQrButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          _textoQuemSomos.trim(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
      ),
    );
  }
}
