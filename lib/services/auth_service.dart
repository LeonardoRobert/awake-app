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
    String? telefone,
    String? endereco,
    String? tempoParticipacao,
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
      }).eq('id', response.user!.id);
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

  /// Valida o codigo de lider no backend e, se correto, eleva o papel
  /// do usuario atual para 'lider'. Lanca excecao se o codigo for invalido
  /// (ver supabase/schema.sql: solicitar_papel_lider).
  Future<void> solicitarPapelLider(String codigo) {
    return _client.rpc('solicitar_papel_lider', params: {'p_codigo': codigo});
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
    return ProfileModel.fromMap(data);
  }
}
