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

/// Phase 23 (FC) — a [ChangeNotifier] that fires on every emission of an
/// arbitrary [Stream]. Merged into [GoRouter.refreshListenable] so the router
/// re-evaluates the maintenance gate when the [AppSettingsCubit] state changes
/// (e.g. maintenance flips on/off after a foreground-resume fetch), navigating
/// gated users to — or away from — the maintenance screen automatically.
class StreamRefreshListenable extends ChangeNotifier {
  StreamRefreshListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

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

  // Spec 005 D-01 — the password-reset COMPLETION screen is reachable in every
  // auth state. Supabase's recovery link mints a real session, so AuthBloc
  // resolves to Authenticated / PendingApproval / Rejected / Suspended the
  // moment the link is processed; without this bypass the account-status
  // redirects (or the `_authOnlyPaths` → home rule) would throw the user off
  // the "choose a new password" screen before they could finish. The page
  // itself handles the no-session case with an "expired link" state.
  if (path == AppRoutes.resetPasswordComplete) return null;

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
// Phase 23 FC: `/maintenance` (the gate target) and `/about` (the public
// about/support surface) are anonymous-readable — never bounce them to /login.
// Phase 14 FR-015 + SC-008 and Phase 15 ("anonymous-accessible, no auth gate on
// map viewing"): `/search` and `/map` are anonymous-readable too. They were
// missed when the bottom-nav shell was introduced — Phase 15 shipped before any
// shell existed — which left a guest tapping the Search/Map tab silently
// ejected to /login. The map's whole server-side jitter mechanism exists to
// serve anonymous clients, so gating the screen contradicted the backend.
const _publicPaths = {
  '/',
  '/onboarding',
  '/splash',
  '/maintenance',
  '/about',
  '/search',
  '/map',
};

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

/// Phase 18 — gate for `/admin/reports` route. Requires `reports.manage`
/// permission; redirects to `/admin?denied=reports` otherwise.
/// Mirrors [requireListingReviewRedirect] (lines 112–124 above).
String? requireReportsManageRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final checker = getIt<PermissionChecker>();
  if (!checker.has(PermissionKeys.reportsManage)) {
    return '/admin?denied=reports';
  }
  return null;
}

/// Phase 20 — gate for `/admin/audit-logs` route. Requires the data-driven
/// `audit_logs.view` permission; redirects to `/admin?denied=audit_logs`
/// otherwise. Mirrors [requireReportsManageRedirect]. The swapped audit_logs
/// RLS policy (20260601120004) re-checks the same gate at the wire.
String? requireAuditLogsViewRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final checker = getIt<PermissionChecker>();
  if (!checker.has(PermissionKeys.auditLogsView)) {
    return '/admin?denied=audit_logs';
  }
  return null;
}

/// Phase 19 — gate for `/admin/agencies` route. Requires any of
/// `agencies.view`, `agencies.approve`, or `agencies.suspend`; redirects to
/// `/admin?denied=agencies` otherwise.
/// Mirrors [requireListingReviewRedirect] (lines 112–124 above).
String? requireAgenciesManageRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final checker = getIt<PermissionChecker>();
  if (!checker.any(const <String>[
    PermissionKeys.agenciesView,
    PermissionKeys.agenciesApprove,
    PermissionKeys.agenciesSuspend,
  ])) {
    return '/admin?denied=agencies';
  }
  return null;
}

/// Phase 21 — gate for `/admin/ads` route. Requires the data-driven
/// `ads.manage` permission; redirects to `/admin?denied=ads` otherwise.
/// Mirrors [requireAuditLogsViewRedirect].
String? requireAdsManageRedirect(BuildContext context, GoRouterState state) {
  final checker = getIt<PermissionChecker>();
  if (!checker.has(PermissionKeys.adsManage)) {
    return '/admin?denied=ads';
  }
  return null;
}

/// Phase 23 — gate for `/admin/settings` route. Requires the data-driven
/// `settings.manage` permission; redirects to `/admin?denied=settings` otherwise.
/// Mirrors [requireAuditLogsViewRedirect].
String? requireSettingsManageRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final checker = getIt<PermissionChecker>();
  if (!checker.has(PermissionKeys.settingsManage)) {
    return '/admin?denied=settings';
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
