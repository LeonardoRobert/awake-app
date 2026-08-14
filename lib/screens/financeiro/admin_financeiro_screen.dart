import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/erro_amigavel.dart';
import '../../models/contribuicao_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contribuicao_provider.dart';
import '../../services/contribuicao_service.dart';

/// Painel do Admin Financeiro -- pensado pra uso no NAVEGADOR (tela
/// grande), pra lancar dizimos/ofertas de qualquer pessoa. So quem
/// tem o cargo "Admin Financeiro" acessa.
///
/// Acesso direto: /admin/financeiro
class AdminFinanceiroScreen extends ConsumerStatefulWidget {
  const AdminFinanceiroScreen({super.key});

  @override
  ConsumerState<AdminFinanceiroScreen> createState() => _AdminFinanceiroScreenState();
}

class _AdminFinanceiroScreenState extends ConsumerState<AdminFinanceiroScreen> {
  late Future<List<PessoaResumo>> _futuroPessoas;
  final _buscaController = TextEditingController();
  PessoaResumo? _pessoaSelecionada;

  @override
  void initState() {
    super.initState();
    _futuroPessoas = ref.read(contribuicaoServiceProvider).listarPessoas();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;

    if (profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile == null || !profile.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Essa página é restrita ao Admin.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Painel Financeiro')),
      body: FutureBuilder<List<PessoaResumo>>(
        future: _futuroPessoas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar pessoas: ${snapshot.error}'));
          }

          final pessoas = snapshot.data ?? [];
          final busca = _buscaController.text.trim().toLowerCase();
          final pessoasFiltradas = busca.isEmpty
              ? pessoas
              : pessoas.where((p) => p.nome.toLowerCase().contains(busca)).toList();

          return Row(
            children: [
              // Coluna esquerda: busca + lista de pessoas
              SizedBox(
                width: 340,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _buscaController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar pessoa',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: pessoasFiltradas.length,
                        itemBuilder: (context, index) {
                          final pessoa = pessoasFiltradas[index];
                          return ListTile(
                            selected: _pessoaSelecionada?.id == pessoa.id,
                            title: Text(pessoa.nome),
                            onTap: () => setState(() => _pessoaSelecionada = pessoa),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Coluna direita: lancamento + historico da pessoa
              Expanded(
                child: _pessoaSelecionada == null
                    ? const Center(
                        child: Text('Selecione uma pessoa à esquerda para lançar uma contribuição.'),
                      )
                    : _PainelLancamento(
                        key: ValueKey(_pessoaSelecionada!.id),
                        pessoa: _pessoaSelecionada!,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Evento ingressado, versao resumida (so o que o seletor precisa).
class _EventoIngressadoResumo {
  final String id;
  final String titulo;
  final double valorTotal;
  _EventoIngressadoResumo({required this.id, required this.titulo, required this.valorTotal});
}

class _PainelLancamento extends ConsumerStatefulWidget {
  final PessoaResumo pessoa;
  const _PainelLancamento({super.key, required this.pessoa});

  @override
  ConsumerState<_PainelLancamento> createState() => _PainelLancamentoState();
}

class _PainelLancamentoState extends ConsumerState<_PainelLancamento> {
  late Future<List<ContribuicaoModel>> _futuroContribuicoes;
  late Future<List<_EventoIngressadoResumo>> _futuroEventosIngressados;

  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();
  DateTime _data = DateTime.now();
  MeioPagamento _meioPagamento = MeioPagamento.pix;
  String? _eventoIdSelecionado;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _recarregar();
    _futuroEventosIngressados = _carregarEventosIngressados();
  }

  Future<List<_EventoIngressadoResumo>> _carregarEventosIngressados() async {
    final resposta = await Supabase.instance.client
        .from('eventos')
        .select('id, titulo, valor_total')
        .eq('ingressado', true)
        .order('data_inicio');
    return (resposta as List)
        .map((e) => _EventoIngressadoResumo(
              id: e['id'] as String,
              titulo: e['titulo'] as String,
              valorTotal: (e['valor_total'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  void _recarregar() {
    _futuroContribuicoes =
        ref.read(contribuicaoServiceProvider).listarPorPessoa(widget.pessoa.id);
  }

  Future<void> _lancar() async {
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }

    setState(() => _salvando = true);
    try {
      await ref.read(contribuicaoServiceProvider).lancar(
            profileId: widget.pessoa.id,
            data: _data,
            valor: valor,
            meioPagamento: _meioPagamento,
            observacao: _observacaoController.text.trim().isEmpty
                ? null
                : _observacaoController.text.trim(),
            eventoId: _eventoIdSelecionado,
          );
      _valorController.clear();
      _observacaoController.clear();
      setState(() {
        _eventoIdSelecionado = null;
        _recarregar();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Contribuição lançada!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao lançar: ${mensagemDeErroAmigavel(e)}')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir(String id) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    await ref.read(contribuicaoServiceProvider).excluir(id);
    setState(() => _recarregar());
  }

  Future<void> _escolherData() async {
    final novaData = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (novaData != null) setState(() => _data = novaData);
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.pessoa.nome, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Novo lançamento', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _valorController,
                            decoration: const InputDecoration(
                              labelText: 'Valor',
                              prefixText: 'R\$ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _escolherData,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data'),
                              child: Text(DateFormat('dd/MM/yyyy').format(_data)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<MeioPagamento>(
                      value: _meioPagamento,
                      decoration: const InputDecoration(labelText: 'Meio de pagamento'),
                      items: MeioPagamento.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _meioPagamento = v ?? MeioPagamento.pix),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _observacaoController,
                      decoration: const InputDecoration(labelText: 'Observação (opcional)'),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<_EventoIngressadoResumo>>(
                      future: _futuroEventosIngressados,
                      builder: (context, snapshot) {
                        final eventos = snapshot.data ?? [];
                        if (eventos.isEmpty) return const SizedBox.shrink();
                        return DropdownButtonFormField<String?>(
                          value: _eventoIdSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Vincular a um evento ingressado (opcional)',
                            helperText:
                                'Ex: parcela do retiro — atualiza a barra de progresso da pessoa',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Nenhum (dízimo/oferta comum)'),
                            ),
                            ...eventos.map((e) => DropdownMenuItem<String?>(
                                  value: e.id,
                                  child: Text(e.titulo),
                                )),
                          ],
                          onChanged: (v) => setState(() => _eventoIdSelecionado = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _salvando ? null : _lancar,
                      icon: _salvando
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Lançar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Histórico de ${widget.pessoa.nome}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<List<ContribuicaoModel>>(
              future: _futuroContribuicoes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lista = snapshot.data ?? [];
                if (lista.isEmpty) {
                  return const Text('Nenhum lançamento ainda.');
                }
                final total = lista.fold<double>(0, (soma, c) => soma + c.valor);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total: ${formatoMoeda.format(total)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...lista.map((c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(formatoMoeda.format(c.valor)),
                            subtitle: Text(
                              '${DateFormat("dd/MM/yyyy").format(c.data)} • ${c.meioPagamento.label}'
                              '${c.eventoId != null ? '\n🎟️ Evento ingressado' : ''}'
                              '${c.observacao != null && c.observacao!.isNotEmpty ? '\n${c.observacao}' : ''}',
                            ),
                            isThreeLine: (c.observacao != null && c.observacao!.isNotEmpty) ||
                                c.eventoId != null,
                            trailing: IconButton(
                              tooltip: 'Apagar lançamento',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _excluir(c.id),
                            ),
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
