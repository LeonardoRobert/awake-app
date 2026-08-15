import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  String? get currentUserEmail => currentUser?.email;

  Future<AuthResponse> signUp({
    required String email,
    required String senha,
    required String nome,
    required DateTime dataNascimento,
    required EstadoCivil estadoCivil,
    required Sexo sexo,
    GrupoCasais? grupoCasais,
    String? telefone,
    String? endereco,
    String? tempoParticipacao,
    required List<String> ministerios,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: senha,
      data: {'nome': nome},
    );

    // A trigger handle_new_user (ver supabase/schema.sql) cria a linha em
    // profiles automaticamente. Aqui completamos os campos adicionais.
    // A categoria (Genesis/Next/One) e calculada sozinha no banco a
    // partir da data de nascimento e do estado civil.
    if (response.user != null) {
      final userId = response.user!.id;
      final campos = {
        'nome': nome,
        'telefone': telefone,
        'endereco': endereco,
        'data_nascimento': dataNascimento.toIso8601String().split('T').first,
        'tempo_participacao': tempoParticipacao,
        'estado_civil': estadoCivil.name,
        'sexo': sexo.name,
        'grupo_casais': grupoCasais?.valorBanco,
      };

      // Logo apos o signUp, a sessao nova as vezes ainda nao "assentou"
      // a tempo do RLS reconhecer auth.uid() == id direito -- o UPDATE
      // roda sem erro nenhum, so nao acha a linha e bate 0 linhas em
      // silencio (Postgres nao avisa erro nesse caso). Confirma com
      // .select() e tenta de novo com um respiro curto se vier vazio.
      var atualizados = await _client.from('profiles').update(campos).eq('id', userId).select();
      for (var tentativa = 0; atualizados.isEmpty && tentativa < 4; tentativa++) {
        await Future.delayed(const Duration(milliseconds: 400));
        atualizados = await _client.from('profiles').update(campos).eq('id', userId).select();
      }

      for (final ministerio in ministerios) {
        for (var tentativa = 0; tentativa < 4; tentativa++) {
          try {
            await _client.from('profile_ministerios').upsert(
              {
                'profile_id': userId,
                'ministerio': ministerio,
                'papel': 'membro',
              },
              onConflict: 'profile_id,ministerio',
            );
            break;
          } catch (_) {
            if (tentativa == 3) rethrow;
            await Future.delayed(const Duration(milliseconds: 400));
          }
        }
      }
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String senha,
  }) {
    return _client.auth.signInWithPassword(email: email, password: senha);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  /// Apaga a PROPRIA conta pra sempre (hard delete) -- chama a Edge
  /// Function `apagar-conta`, que roda com a service role key (so ela
  /// tem permissao de apagar de auth.users; o app nunca tem essa
  /// chave). A funcao so apaga o usuario dono do token que ela mesma
  /// recebe, nunca um id passado por fora -- ninguem apaga a conta de
  /// outra pessoa por aqui. Com as FKs de profiles/auth.users ajustadas
  /// (supabase/sql/2026_fix_fk_delete_perfil.sql), apagar o usuario ja
  /// cai em cascata por tudo (perfil, filhos, escalas, etc.) sozinho.
  Future<void> apagarMinhaConta() async {
    final resposta = await _client.functions.invoke('apagar-conta');
    if (resposta.status != 200) {
      final corpo = resposta.data;
      final mensagem = corpo is Map && corpo['error'] != null ? corpo['error'] : 'Erro desconhecido';
      throw Exception(mensagem);
    }
  }

  /// Manda um e-mail de recuperacao de senha. `redirectTo` deve ser uma
  /// URL cadastrada em Authentication > URL Configuration no Supabase.
  Future<void> resetPassword(String email, {required String redirectTo}) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  /// Usada na tela de "definir nova senha", depois que a pessoa clica no
  /// link do e-mail de recuperacao. Tambem usada direto na tela de
  /// Editar Perfil, pra trocar a senha sem precisar sair do app.
  Future<void> updatePassword(String novaSenha) {
    return _client.auth.updateUser(UserAttributes(password: novaSenha));
  }

  /// Troca o e-mail de login (usado na tela de Editar Perfil). O
  /// Supabase manda um link de confirmacao pro endereco novo -- o
  /// e-mail so' passa a valer de verdade depois que a pessoa clicar
  /// nesse link (comportamento padrao do projeto no Supabase).
  Future<void> updateEmail(String novoEmail) {
    return _client.auth.updateUser(UserAttributes(email: novoEmail));
  }

  /// Atualiza campos do proprio perfil (usado na tela de Editar Perfil).
  Future<void> updateProfileFields(Map<String, dynamic> campos) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('profiles').update(campos).eq('id', user.id);
  }

  /// Marca que a pessoa ja viu o tour de introducao (nao aparece de novo).
  Future<void> marcarTourVisto() async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('profiles').update({'tour_visto': true}).eq('id', user.id);
  }

  /// Valida o codigo de lider no backend e, se correto, eleva o papel
  /// do usuario atual para 'lider' NO MINISTERIO informado. Lanca
  /// excecao se o codigo for invalido.
  Future<void> solicitarPapelLider(String codigo, {required String ministerio}) {
    return _client.rpc('solicitar_papel_lider', params: {
      'p_codigo': codigo,
      'p_ministerio': ministerio,
    });
  }

  Future<ProfileModel?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;

    final ministeriosData = await _client
        .from('profile_ministerios')
        .select('ministerio, papel')
        .eq('profile_id', user.id);

    final ministerios = (ministeriosData as List)
        .map((m) => MinisterioMembership(
              ministerio: (m as Map<String, dynamic>)['ministerio'] as String,
              ehLider: m['papel'] == 'lider',
            ))
        .toList();

    return ProfileModel.fromMap(data, ministerios: ministerios);
  }

  /// Envia a foto de perfil pro Storage e ja atualiza o perfil com a
  /// nova URL. Cada pessoa so consegue mexer na propria pasta (RLS),
  /// por isso o caminho comeca com o proprio id.
  Future<String> uploadFotoPerfil(Uint8List bytes, String nomeArquivo) async {
    final userId = currentUser!.id;
    final extensao = nomeArquivo.contains('.') ? nomeArquivo.split('.').last : 'jpg';
    final caminho = '$userId/foto.$extensao';

    await _client.storage.from('avatars').uploadBinary(
          caminho,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _client.storage.from('avatars').getPublicUrl(caminho);
    // Anexa um "carimbo" de tempo na URL soh pra forcar o app a buscar
    // a imagem nova (senao ele pode continuar mostrando a antiga, que
    // ficou guardada em cache com a mesma URL de sempre).
    final urlComCarimbo = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

    await _client.from('profiles').update({'foto_url': urlComCarimbo}).eq('id', userId);
    return urlComCarimbo;
  }
}
