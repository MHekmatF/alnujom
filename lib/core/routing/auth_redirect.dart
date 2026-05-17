import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../security/permission_checker.dart';
import '../security/permission_keys.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';

/// A [ChangeNotifier] that fires whenever [AuthBloc] emits a new state.
///
/// Pass this as [GoRouter.refreshListenable] so the router re-evaluates the
/// redirect function on every auth state change.
class AuthBlocListenable extends ChangeNotifier {
  AuthBlocListenable(AuthBloc authBloc) {
    notifyListeners();
    _sub = authBloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// go_router redirect function driven by [AuthBloc] state.
///
/// Called on every navigation. Returns the redirect path or null (no redirect).
FutureOr<String?> authRedirect(
  AuthBloc authBloc,
  BuildContext context,
  GoRouterState state,
) {
  final authState = authBloc.state;
  final path = state.uri.path;

  return switch (authState) {
    Unauthenticated() => _redirectIfProtected(path),
    Authenticating() => null,
    Authenticated() => _redirectAuthenticated(path),
    PendingApproval() => path == '/pending' ? null : '/pending',
    Rejected() => path == '/rejected' ? null : '/rejected',
    Suspended() => path == '/suspended' ? null : '/suspended',
    AuthError() => _redirectIfProtected(path),
  };
}

const _authOnlyPaths = {'/login', '/register', '/reset-password'};
const _publicPaths = {'/onboarding', '/splash'};

String? _redirectIfProtected(String path) {
  if (_authOnlyPaths.contains(path) || _publicPaths.contains(path)) return null;
  return '/login';
}

String? _redirectAuthenticated(String path) {
  if (_authOnlyPaths.contains(path) || path == '/') return '/home';
  final hasAdminAccess = getIt<PermissionChecker>().any(
    PermissionKeys.adminCategoryKeys,
  );
  if ((path == '/admin' || path.startsWith('/admin/')) && !hasAdminAccess) {
    return '/home';
  }
  return null;
}

String? requireSuperAdminRedirect(BuildContext context, GoRouterState state) {
  final checker = getIt<PermissionChecker>();
  if (!checker.any(PermissionKeys.superAdminCategoryKeys)) {
    return '/admin';
  }
  return null;
}

String? requireLocationsManageRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final checker = getIt<PermissionChecker>();
  if (!checker.has(PermissionKeys.locationsManage)) {
    return '/admin';
  }
  return null;
}
