import '../../../../core/di/injection.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../core/security/permission_keys.dart';
import '../bloc/app_settings_cubit.dart';

/// Phase 23 (FC / T024) — the maintenance redirect rule, composed into the
/// global `redirect` in `app_router.dart`.
///
/// **Single enforcement point** for maintenance mode. Reads the already-loaded
/// snapshot from the [AppSettingsCubit] singleton synchronously (NO network
/// fetch — the redirect runs on every navigation and must stay cheap; the
/// fetch is owned by the cubit's `load()` at app-start/resume).
///
/// INVARIANT 1 — bypass is `settings.manage` ONLY:
/// - maintenance OFF                       → `null` (no redirect).
/// - maintenance ON + holds `settings.manage` → `null` (BYPASS — the operator
///   who flipped it on is never locked out). This is the ONLY bypass.
/// - maintenance ON + anyone else (incl. anonymous) → [maintenanceRoute].
///
/// INVARIANT 2 — fail-open: when the settings fetch failed, the cubit serves
/// [AppSettings.safeDefaults] (maintenance OFF), so `maintenanceActive` is
/// `false` and this returns `null`. A fetch error never produces a redirect.
///
/// Returns the maintenance path to redirect to, or `null` to allow navigation.
/// When already on [maintenanceRoute], returns `null` to avoid a redirect loop.
String? maintenanceRedirect(String currentPath) {
  final cubit = getIt<AppSettingsCubit>();
  if (!cubit.maintenanceActive) return null;

  // Bypass: only `settings.manage` holders pass the gate (the sole exception).
  if (getIt<PermissionChecker>().has(PermissionKeys.settingsManage)) {
    return null;
  }

  // Already on the maintenance screen — do not redirect onto itself.
  if (currentPath == maintenanceRoute) return null;

  return maintenanceRoute;
}

/// The route path for the full-screen maintenance gate.
const String maintenanceRoute = '/maintenance';
