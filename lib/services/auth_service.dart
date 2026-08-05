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
      await _client.from('profiles').update({
        'nome': nome,
        'telefone': telefone,
        'endereco': endereco,
        'data_nascimento': dataNascimento.toIso8601String().split('T').first,
        'tempo_participacao': tempoParticipacao,
        'estado_civil': estadoCivil.name,
        'sexo': sexo.name,
        'grupo_casais': grupoCasais?.valorBanco,
      }).eq('id', response.user!.id);

      for (final ministerio in ministerios) {
        await _client.from('profile_ministerios').upsert(
          {
            'profile_id': response.user!.id,
            'ministerio': ministerio,
            'papel': 'membro',
          },
          onConflict: 'profile_id,ministerio',
        );
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

  /// Manda um e-mail de recuperacao de senha. `redirectTo` deve ser uma
  /// URL cadastrada em Authentication > URL Configuration no Supabase.
  Future<void> resetPassword(String email, {required String redirectTo}) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  /// Usada na tela de "definir nova senha", depois que a pessoa clica no
  /// link do e-mail de recuperacao.
  Future<void> updatePassword(String novaSenha) {
    return _client.auth.updateUser(UserAttributes(password: novaSenha));
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
