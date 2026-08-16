import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PreferenciaTema { claro, escuro, maisEscuro }

extension PreferenciaTemaLabel on PreferenciaTema {
  String get label {
    switch (this) {
      case PreferenciaTema.claro:
        return 'Claro';
      case PreferenciaTema.escuro:
        return 'Escuro';
      case PreferenciaTema.maisEscuro:
        return 'Mais escuro';
    }
  }

  String get descricao {
    switch (this) {
      case PreferenciaTema.claro:
        return 'Fundo claro, o padrão.';
      case PreferenciaTema.escuro:
        return 'Fundo escuro (azul-marinho).';
      case PreferenciaTema.maisEscuro:
        return 'Fundo preto de verdade — economiza bateria em tela AMOLED.';
    }
  }
}

// Chave antiga (bool: escuro ou nao) -- mantida so pra migrar quem ja
// tinha escolhido um tema antes dessa tela virar 3 opcoes, sem resetar
// a preferencia de ninguem.
const _chaveTemaEscuroAntiga = 'tema_escuro';
const _chavePreferenciaTema = 'preferencia_tema';

/// Controla o tema do app manualmente. Guarda a escolha no proprio
/// aparelho (SharedPreferences), entao continua igual mesmo depois de
/// fechar e abrir o app de novo.
class ThemeModeNotifier extends StateNotifier<PreferenciaTema> {
  ThemeModeNotifier() : super(PreferenciaTema.claro) {
    _carregarPreferencia();
  }

  Future<void> _carregarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(_chavePreferenciaTema);
    if (salvo != null) {
      state = PreferenciaTema.values.firstWhere(
        (v) => v.name == salvo,
        orElse: () => PreferenciaTema.claro,
      );
      return;
    }

    // Ninguem escolheu pela chave nova ainda -- confia na antiga
    // (bool), se existir, pra nao resetar quem ja tinha ativado o
    // modo escuro antes dessa tela virar 3 opcoes.
    final escuroAntigo = prefs.getBool(_chaveTemaEscuroAntiga);
    if (escuroAntigo == true) state = PreferenciaTema.escuro;
  }

  Future<void> definir(PreferenciaTema preferencia) async {
    state = preferencia;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chavePreferenciaTema, preferencia.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, PreferenciaTema>(
  (ref) => ThemeModeNotifier(),
);
