# Contract: `lib/core/security/permission_keys.dart`

**Owner**: Phase 6 (the file is created in Phase 6).
**Consumers**: every Flutter call site that consults `PermissionChecker.has(...)` / `.any(...)` / `.all(...)`. Phase 6 consumers: the main-navigation admin tile, the admin home page tile visibility, the `/admin` route guard. Phase 7+ adds many more.
**Stability**: Per-key field names are stable for v1. New keys are added (never renamed, never removed) in the same PR that adds the corresponding migration / role-permission seed.

---

## Purpose

The Flutter-side mirror of the seeded `permissions.key` values. Hand-maintained constants give compile-time safety on the Flutter side and a single grep target for "every place that uses `users.approve`."

## Layout

```dart
/// Mirror of the 24 seeded permissions.key values from
/// docs/IMPLEMENTATION_PLAN.md §9.1 and supabase/migrations/20260515120002_create_permissions.sql.
///
/// Hand-maintained. When a future spec adds, removes, or renames a permission key
/// via migration, this file MUST be updated in the same PR. PR review catches drift.
abstract class PermissionKeys {
  PermissionKeys._();

  // Users category
  static const String usersView    = 'users.view';
  static const String usersApprove = 'users.approve';
  static const String usersReject  = 'users.reject';
  static const String usersSuspend = 'users.suspend';

  // Listings category
  static const String listingsViewAll   = 'listings.view_all';
  static const String listingsApprove   = 'listings.approve';
  static const String listingsReject    = 'listings.reject';
  static const String listingsEditAny   = 'listings.edit_any';
  static const String listingsDeleteAny = 'listings.delete_any';

  // Roles / Permissions category
  static const String rolesView         = 'roles.view';
  static const String rolesCreate       = 'roles.create';
  static const String rolesUpdate       = 'roles.update';
  static const String rolesDelete       = 'roles.delete';
  static const String permissionsManage = 'permissions.manage';

  // Locations / Currencies / Ads / Reports
  static const String locationsManage  = 'locations.manage';
  static const String currenciesManage = 'currencies.manage';
  static const String adsManage        = 'ads.manage';
  static const String reportsManage    = 'reports.manage';

  // Agencies
  static const String agenciesView    = 'agencies.view';
  static const String agenciesApprove = 'agencies.approve';
  static const String agenciesSuspend = 'agencies.suspend';

  // Settings / Audit / Inquiries
  static const String settingsManage   = 'settings.manage';
  static const String auditLogsView    = 'audit_logs.view';
  static const String inquiriesViewAll = 'inquiries.view_all';

  /// Every admin-category permission key. Used by the main-navigation admin-tile
  /// visibility check: `PermissionChecker.any(PermissionKeys.adminCategoryKeys)`.
  static const Set<String> adminCategoryKeys = <String>{
    usersView, usersApprove, usersReject, usersSuspend,
    listingsViewAll, listingsApprove, listingsReject, listingsEditAny, listingsDeleteAny,
    rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage,
    locationsManage, currenciesManage, adsManage, reportsManage,
    agenciesView, agenciesApprove, agenciesSuspend,
    settingsManage, auditLogsView, inquiriesViewAll,
  };
}
```

## Invariants

- **Field name convention**: camelCase of the dot-namespaced key. `users.approve` → `usersApprove`. `listings.view_all` → `listingsViewAll`.
- **24 named constants** matching the 24 seeded `permissions.key` values one-to-one.
- **`adminCategoryKeys` is the union of all 24** — every Phase 6 permission key is admin-category in practice; the constant exists for the convenience of the "any admin-tile" visibility check.
- **Abstract class with private constructor**: prevents instantiation. The class is a namespace for constants.

## Drift detection

- **At PR review time**: the reviewer cross-references the file against the seeded permission keys in `supabase/migrations/20260515120002_create_permissions.sql`.
- **At runtime**: a call to `PermissionChecker.has('some.key')` where the key is NOT in the seeded catalog returns `FALSE` silently — there is no compile-time check that the constant value exists in the DB. The runtime drift is only detectable via behavior (the UI gate never opens for that key, even for a super_admin).

## Forward references

- A future spec MAY codegen this file from the seeded `permissions` table (R-07 deferred this for v1). When codegen is added, the file becomes a build artifact; the abstract-class shape stays.
- Each future spec that adds a permission key MUST add the corresponding constant in the same PR.
