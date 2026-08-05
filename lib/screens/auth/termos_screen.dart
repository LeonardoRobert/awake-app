import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/awake_app_bar.dart';

class TermosScreen extends ConsumerWidget {
  const TermosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Termos de Uso e Privacidade', showQrButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _Secao(
              titulo: '1. Sobre o aplicativo',
              texto:
                  'O Awake é um aplicativo de uso interno do ministério Awake, criado '
                  'para organizar calendário de eventos, escalas de voluntariado, '
                  'metas de participação e conteúdos de treinamento dos membros e '
                  'líderes.',
            ),
            _Secao(
              titulo: '2. Dados coletados',
              texto:
                  'Coletamos nome completo, data de nascimento, e-mail, telefone, '
                  'endereço e estado civil no momento do cadastro. Esses dados são '
                  'usados exclusivamente para organizar a participação da pessoa no '
                  'ministério (categorização por grupo, escalas, check-in em eventos '
                  'e cálculo de metas de constância).',
            ),
            _Secao(
              titulo: '3. Menores de idade',
              texto:
                  'Membros menores de 18 anos precisam do conhecimento e autorização '
                  'de um responsável legal para se cadastrar. Ao marcar a caixa de '
                  'aceite dos termos, o responsável (ou o próprio menor, sob '
                  'supervisão de um responsável) confirma estar ciente do uso do '
                  'aplicativo e do tratamento dos dados descritos aqui.',
            ),
            _Secao(
              titulo: '4. Uso dos dados',
              texto:
                  'Os dados cadastrados não são vendidos, compartilhados ou usados '
                  'para fins comerciais. Ficam disponíveis apenas para a liderança do '
                  'ministério, com o propósito de organizar a operação do Awake '
                  '(escalas, eventos, treinamentos e acompanhamento pastoral de '
                  'participação).',
            ),
            _Secao(
              titulo: '5. Privacidade entre membros',
              texto:
                  'Cada membro só visualiza os próprios dados de participação e '
                  'metas — não é possível ver informações de constância ou '
                  'frequência de outros membros. Líderes têm acesso a uma visão '
                  'agregada da participação da equipe, para fins de acompanhamento '
                  'pastoral.',
            ),
            _Secao(
              titulo: '6. QR Code pessoal',
              texto:
                  'Cada pessoa recebe um QR Code individual, usado exclusivamente '
                  'para confirmar presença em eventos e escalas (check-in). Esse '
                  'código não deve ser compartilhado publicamente.',
            ),
            _Secao(
              titulo: '7. Exclusão de conta e dados',
              texto:
                  'A qualquer momento, a pessoa pode solicitar a exclusão da própria '
                  'conta e dos dados associados, falando diretamente com a liderança '
                  'do Awake.',
            ),
            _Secao(
              titulo: '8. Contato',
              texto:
                  'Dúvidas sobre este termo ou sobre o tratamento de dados podem ser '
                  'esclarecidas diretamente com a liderança do ministério Awake.',
            ),
            SizedBox(height: 16),
            Text(
              'Este é um documento inicial, elaborado para uso interno do '
              'ministério. Recomenda-se revisão por um profissional da área '
              'jurídica antes do lançamento oficial em maior escala.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final String texto;
  const _Secao({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 6),
          Text(texto, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
