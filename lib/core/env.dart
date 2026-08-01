/// Configuracoes de ambiente do app.
///
/// Preencha estes valores com os dados do seu projeto Supabase
/// (Settings > API) e do seu app OneSignal (Settings > Keys & IDs).
///
/// Voce pode tanto substituir os defaultValue abaixo diretamente,
/// quanto rodar o app passando --dart-define, exemplo:
///
/// flutter run \
///   --dart-define=SUPABASE_URL=https://seuprojeto.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=sua-anon-key \
///   --dart-define=ONESIGNAL_APP_ID=seu-onesignal-app-id
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://SEU-PROJETO.supabase.co', // TODO: preencher
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'SUA_ANON_KEY_AQUI', // TODO: preencher
  );

  static const oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'SEU_ONESIGNAL_APP_ID', // TODO: preencher
  );
}
