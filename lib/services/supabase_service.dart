import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cliente_http_retentativa_sessao.dart';
import '../core/env.dart';

/// Inicializacao e acesso central ao cliente Supabase.
class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      httpClient: ClienteHttpComRetentativaDeSessao(http.Client()),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
