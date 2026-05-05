import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../debug/theme_gallery_page.dart';
import '../../shell/shell_home_page.dart';
import '../flags/app_flags.dart';
import '../logging/app_logger.dart';

abstract final class AppRoutes {
  static const shellHome = '/';
  static const themeGallery = '/_debug/theme-gallery';
}

abstract final class AppRouteNames {
  static const shellHome = 'shell-home';
  static const themeGallery = 'theme-gallery';
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
      if (kDesignToolsEnabled)
        GoRoute(
          path: AppRoutes.themeGallery,
          name: AppRouteNames.themeGallery,
          builder: (context, state) => const ThemeGalleryPage(),
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
