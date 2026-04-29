import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shell/shell_home_page.dart';
import '../logging/app_logger.dart';

abstract final class AppRoutes {
  static const shellHome = '/';
}

abstract final class AppRouteNames {
  static const shellHome = 'shell-home';
}

GoRouter buildAppRouter({required AppLogger logger}) {
  return GoRouter(
    initialLocation: AppRoutes.shellHome,
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(
        path: AppRoutes.shellHome,
        name: AppRouteNames.shellHome,
        builder: (context, state) => const ShellHomePage(),
      ),
    ],
    errorBuilder: (context, state) {
      logger.warning(
        'Unknown route: ${state.uri}',
        error: state.error,
        tag: 'AppRouter',
      );
      return Scaffold(
        body: Center(child: Text(state.error?.toString() ?? 'Unknown route')),
      );
    },
  );
}
