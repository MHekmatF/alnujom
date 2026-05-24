import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../security/permission_checker.dart';
import '../security/permission_keys.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../shared/domain/value_objects/account_status.dart';
import '../../shared/domain/value_objects/publisher_status.dart';
import 'app_router.dart';

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
// Phase 13 FR-008 + FR-010: `/` (HomePage) and `/listings/:id`
// (ListingDetailsPage) are anonymous-readable per US1/US2/US4. The `/listings/`
// prefix check covers the deep-link entry case per Q4=D.
const _publicPaths = {'/', '/onboarding', '/splash'};

String? _redirectIfProtected(String path) {
  if (_authOnlyPaths.contains(path) || _publicPaths.contains(path)) return null;
  if (path.startsWith('/listings/')) return null;
  return '/login';
}

String? _redirectAuthenticated(String path) {
  if (_authOnlyPaths.contains(path)) return AppRoutes.home;
  final hasAdminAccess = getIt<PermissionChecker>().any(
    PermissionKeys.adminCategoryKeys,
  );
  if ((path == '/admin' || path.startsWith('/admin/')) && !hasAdminAccess) {
    return AppRoutes.home;
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

String? requireCurrenciesManageRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final checker = getIt<PermissionChecker>();
  if (!checker.has(PermissionKeys.currenciesManage)) {
    return '/admin';
  }
  return null;
}

/// Phase 12 — gate for `/admin/listing-review/...` routes. Requires either
/// `listings.approve` OR `listings.reject` (one is enough to view + act on
/// the queue; the Edge Function re-checks the specific permission on call).
String? requireListingReviewRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final checker = getIt<PermissionChecker>();
  if (!checker.any(const <String>[
    PermissionKeys.listingsApprove,
    PermissionKeys.listingsReject,
  ])) {
    return '/admin?denied=listing_review';
  }
  return null;
}

/// Phase 12 / US6 — login-only gate for the publisher moderation history page.
/// Owner-only access is enforced server-side; no publisher-status check needed.
String? requirePublisherLoginRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final authState = getIt<AuthBloc>().state;
  if (authState is! Authenticated) {
    return AppRoutes.login;
  }
  return null;
}

String? requirePublisherStatusRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final authState = getIt<AuthBloc>().state;
  if (authState is! Authenticated) {
    return AppRoutes.login;
  }

  if (authState.profile.accountStatus != AccountStatus.approved) {
    return switch (authState.profile.accountStatus) {
      AccountStatus.pending => AppRoutes.pending,
      AccountStatus.rejected => AppRoutes.rejected,
      AccountStatus.suspended => AppRoutes.suspended,
      _ => AppRoutes.home,
    };
  }

  if (authState.profile.publisherStatus != PublisherStatus.approved) {
    return AppRoutes.publisherApprovalPending;
  }

  return null;
}
