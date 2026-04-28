import 'package:injectable/injectable.dart';

@singleton
final class EnvConfig {
  const EnvConfig();

  String get supabaseUrl => const String.fromEnvironment('SUPABASE_URL');

  String get supabaseAnonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY');

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
