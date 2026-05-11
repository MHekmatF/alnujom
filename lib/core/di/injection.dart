import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../logging/app_logger.dart';
import '../routing/app_router.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: r'$initGetIt',
  preferRelativeImports: true,
  asExtension: false,
)
Future<void> configureDependencies() async {
  $initGetIt(getIt);
}

@module
abstract class RouterModule {
  @singleton
  GoRouter router(AppLogger logger, AuthBloc authBloc) =>
      buildAppRouter(logger: logger, authBloc: authBloc);
}
