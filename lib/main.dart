import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/di/injection.dart';
import 'core/errors/result.dart';
import 'core/logging/app_logger.dart';
import 'core/network/supabase_client_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  final logger = getIt<AppLogger>();
  logger.info('Dependency injection configured.', tag: 'Bootstrap');

  final env = getIt<EnvConfig>();
  final wrapper = getIt<SupabaseClientWrapper>();
  final initResult = await wrapper.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
  );

  if (initResult case FailureResult(:final failure)) {
    logger.warning(failure.message, tag: 'SupabaseClientWrapper');
  }

  runApp(const App());
}
