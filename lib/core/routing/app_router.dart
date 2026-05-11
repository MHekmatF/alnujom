import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../debug/theme_gallery_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../shell/shell_home_page.dart';
import '../flags/app_flags.dart';
import '../logging/app_logger.dart';
import 'auth_redirect.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const pending = '/pending';
  static const rejected = '/rejected';
  static const suspended = '/suspended';
  static const home = '/home';
  static const admin = '/admin';
  static const adminApprovals = '/admin/approvals';
  static const resetPassword = '/reset-password';
  static const shellHome = '/';
  static const themeGallery = '/_debug/theme-gallery';
}

abstract final class AppRouteNames {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const register = 'register';
  static const pending = 'pending';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
  static const home = 'home';
  static const admin = 'admin';
  static const adminApprovals = 'admin-approvals';
  static const resetPassword = 'reset-password';
  static const shellHome = 'shell-home';
  static const themeGallery = 'theme-gallery';
}

/// Placeholder page used for routes whose real page is created in a later phase.
/// Replaced one-by-one as US1/US3/US4 land their real pages.
Widget _placeholder(String label) => Scaffold(
  appBar: AppBar(title: Text(label)),
  body: Center(child: Text(label)),
);

GoRouter buildAppRouter({required AppLogger logger, required AuthBloc authBloc}) {
  final refreshListenable = AuthBlocListenable(authBloc);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshListenable,
    redirect: (context, state) => authRedirect(authBloc, context, state),
    routes: [
      // ─── Phase 5 auth routes ───
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => _placeholder('Splash'),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRouteNames.onboarding,
        builder: (context, state) => _placeholder('Onboarding'),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        builder: (context, state) => _placeholder('Login'),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRouteNames.register,
        builder: (context, state) => _placeholder('Register'),
      ),
      GoRoute(
        path: AppRoutes.pending,
        name: AppRouteNames.pending,
        builder: (context, state) => _placeholder('Pending Approval'),
      ),
      GoRoute(
        path: AppRoutes.rejected,
        name: AppRouteNames.rejected,
        builder: (context, state) => _placeholder('Rejected'),
      ),
      GoRoute(
        path: AppRoutes.suspended,
        name: AppRouteNames.suspended,
        builder: (context, state) => _placeholder('Suspended'),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRouteNames.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        name: AppRouteNames.admin,
        builder: (context, state) => _placeholder('Admin'),
        routes: [
          GoRoute(
            path: 'approvals',
            name: AppRouteNames.adminApprovals,
            builder: (context, state) => _placeholder('Account Approvals'),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: AppRouteNames.resetPassword,
        builder: (context, state) => _placeholder('Reset Password'),
      ),

      // ─── Phase 1–4 legacy routes (kept for design tools) ───
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
