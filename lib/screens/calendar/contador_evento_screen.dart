import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/erro_amigavel.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../widgets/awake_app_bar.dart';

/// Contador manual de presença -- pra eventos "gerais" (EBD, Culto de
/// Celebração, Culto da Família) onde não dá pra escanear QR Code de
/// todo mundo. O admin escolhe o evento de HOJE, vai apertando +/-
/// (só na tela, não grava nada ainda) e manda pro banco de uma vez só
/// no botão "Enviar", quando terminar de contar. Esse dado alimenta a
/// aba Shallom do painel de gestão.
class ContadorEventoScreen extends StatefulWidget {
  const ContadorEventoScreen({super.key});

  @override
  State<ContadorEventoScreen> createState() => _ContadorEventoScreenState();
}

/// Só esses 3 tipos entram aqui -- os mesmos que a aba Shallom do
/// gestão.html mostra (EBD/Culto de Celebração/Culto da Família).
const _tiposContagemManual = [EventTipo.ebd, EventTipo.cultoCelebracao, EventTipo.cultoFamilia];

class _ContadorEventoScreenState extends State<ContadorEventoScreen> {
  final _service = EventService();
  late Future<List<({EventModel evento, DateTime data})>> _futuroEventosDeHoje;

  ({EventModel evento, DateTime data})? _selecionado;
  int _contagem = 0;
  bool _carregandoContagem = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _futuroEventosDeHoje = _buscarEventosDeHoje();
  }

  Future<List<({EventModel evento, DateTime data})>> _buscarEventosDeHoje() async {
    final eventos = await _service.listUpcoming();
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final fimDoDia = hoje.add(const Duration(hours: 23, minutes: 59));

    final resultado = <({EventModel evento, DateTime data})>[];
    for (final evento in eventos) {
      if (!_tiposContagemManual.contains(evento.tipo)) continue;
      for (final data in evento.occurrencesBetween(hoje, fimDoDia)) {
        resultado.add((evento: evento, data: data));
      }
    }
    resultado.sort((a, b) => a.data.compareTo(b.data));
    return resultado;
  }

  Future<void> _selecionar(({EventModel evento, DateTime data}) item) async {
    setState(() {
      _selecionado = item;
      _carregandoContagem = true;
    });
    try {
      // Comeca do que ja tiver sido enviado antes (ex: alguem ja
      // contou uma parte e mandou, e agora vai continuar contando).
      final contagem = await _service.buscarContagemEvento(
        eventoId: item.evento.id,
        dataOcorrencia: item.data,
      );
      if (mounted) setState(() => _contagem = contagem);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemDeErroAmigavel(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoContagem = false);
    }
  }

  /// So' mexe no numero da tela -- nao grava nada no banco ainda.
  void _ajustar(int delta) {
    setState(() => _contagem = (_contagem + delta).clamp(0, 999999));
  }

  Future<void> _enviar() async {
    final selecionado = _selecionado;
    if (selecionado == null || _enviando) return;

    setState(() => _enviando = true);
    try {
      await _service.definirContagemEvento(
        eventoId: selecionado.evento.id,
        dataOcorrencia: selecionado.data,
        valor: _contagem,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contagem enviada!')),
        );
        setState(() {
          _selecionado = null;
          _contagem = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemDeErroAmigavel(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selecionado = _selecionado;

    return Scaffold(
      appBar: AwakeAppBar(
        title: selecionado == null ? 'Contador de evento' : selecionado.evento.titulo,
        showQrButton: false,
      ),
      body: selecionado != null ? _buildContador(selecionado) : _buildSelecaoDeEvento(),
    );
  }

  Widget _buildSelecaoDeEvento() {
    return FutureBuilder<List<({EventModel evento, DateTime data})>>(
      future: _futuroEventosDeHoje,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro ao carregar: ${mensagemDeErroAmigavel(snapshot.error!)}'));
        }
        final itens = snapshot.data ?? [];
        if (itens.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nenhum EBD, Culto de Celebração ou Culto da Família hoje.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itens.length,
          itemBuilder: (context, index) {
            final item = itens[index];
            return Card(
              child: ListTile(
                title: Text(item.evento.titulo),
                subtitle: Text(DateFormat('HH:mm').format(item.data)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selecionar(item),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContador(({EventModel evento, DateTime data}) selecionado) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat("EEEE, dd 'de' MMMM 'às' HH:mm", 'pt_BR').format(selecionado.data),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            _carregandoContagem
                ? const CircularProgressIndicator()
                : Text(
                    '$_contagem',
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                  ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BotaoContador(
                  icon: Icons.remove,
                  onPressed: _carregandoContagem ? null : () => _ajustar(-1),
                ),
                const SizedBox(width: 24),
                _BotaoContador(
                  icon: Icons.add,
                  onPressed: _carregandoContagem ? null : () => _ajustar(1),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _carregandoContagem || _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _selecionado = null;
                _contagem = 0;
              }),
              child: const Text('Escolher outro evento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoContador extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _BotaoContador({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(shape: const CircleBorder()),
        child: Icon(icon, size: 32),
      ),
    );
  }
}
