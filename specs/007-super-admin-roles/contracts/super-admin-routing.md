# Contract: Super-Admin Tile Visibility, Routing & Route Guards

**Owner**: Phase 7 (`lib/features/admin/presentation/pages/admin_home_page.dart`, `lib/core/routing/auth_redirect.dart`, `lib/app.dart` go_router config).
**Consumers**: every authenticated session that opens the admin home page or attempts a deep-link to a super-admin route.
**Stability**: Tile placement and route paths are stable for v1.

---

## Purpose

Defines the three gating surfaces for the Phase 7 super-admin UI: (1) the visibility of the "Super-admin" tile on the Phase 6 `AdminHomePage`; (2) the four new go_router routes under `/admin/super-admin/...`; (3) the per-route redirect guard that enforces `PermissionChecker.any(PermissionKeys.superAdminCategoryKeys)`.

## Tile visibility (FR-011)

```dart
// in admin_home_page.dart
if (permissionChecker.any(PermissionKeys.superAdminCategoryKeys)) {
  tiles.add(AdminHomeTile(
    icon: Icons.shield,  // Phase 2 design-token icon
    title: AppLocalizations.of(context)!.adminTileSuperAdmin,
    onTap: () => context.go('/admin/super-admin/roles'),
  ));
}
```

The tile is rendered iff the signed-in user holds AT LEAST ONE of the five super-admin-category permission keys: `roles.view`, `roles.create`, `roles.update`, `roles.delete`, `permissions.manage`. In v1, only the seeded `super_admin` role holds all five (FR-006 Phase 6); admin / moderator / user / owner / agent / agency_admin hold none.

## Routes

```dart
// in app.dart go_router config, under the existing /admin parent
GoRoute(
  path: '/admin/super-admin/roles',
  redirect: _requireSuperAdmin,
  builder: (context, state) => const RolesListPage(),
  routes: [
    GoRoute(
      path: ':roleId',
      redirect: _requireSuperAdmin,
      builder: (context, state) => RoleEditorPage(roleId: state.pathParameters['roleId']!),
    ),
    GoRoute(
      path: 'create',
      redirect: _requireSuperAdmin,
      builder: (context, state) => const CreateRolePage(),
    ),
  ],
),
GoRoute(
  path: '/admin/super-admin/assign',
  redirect: _requireSuperAdmin,
  builder: (context, state) => const AssignRolePage(),
),
```

## Redirect helper

```dart
// in lib/core/routing/auth_redirect.dart (extended from Phase 6's pattern)
String? _requireSuperAdmin(BuildContext context, GoRouterState state) {
  final checker = getIt<PermissionChecker>();
  if (!checker.any(PermissionKeys.superAdminCategoryKeys)) {
    return '/admin';  // bounce to the admin home (Phase 6 pattern)
  }
  return null;  // proceed
}
```

The helper returns `/admin` on failure — matching Phase 6's pattern for `/admin/approvals` when the user lacks `users.approve`. The user lands on the Phase 6 admin home (which may or may not be visible to them depending on their other permissions); if they have no admin permissions at all, the admin home itself is hidden by the home-page admin tile visibility check.

## Defense-in-depth layers

Per FR-008 / FR-009 + the spec's three-layer principle:

1. **UI layer**: `AdminHomePage` hides the "Super-admin" tile if the user lacks the super-admin-category permissions.
2. **Route guard layer**: each `/admin/super-admin/...` route has the `_requireSuperAdmin` redirect; deep-link attempts are bounced.
3. **Page-level layer**: each page checks `PermissionChecker.has(<specific-key>)` for each affordance inside (e.g., the "Create" button on `RolesListPage` requires `rolesCreate`; the "Delete" affordance requires `rolesDelete`; the permission-checklist Save requires `permissionsManage`).
4. **Server layer (RLS)**: the Phase 7 write-side RLS policies on `roles`, `role_permissions`, `user_roles` reject writes by under-privileged sessions.
5. **Server layer (RPC re-check)**: the three Phase 7 RPCs re-check the same permission keys inside their function bodies — this is the path the Flutter app actually takes, and it's the binding gate.

A user who defeats one layer hits the next. The UI hiding is UX-friendly; the route guard is the deep-link guard; the RLS + RPC re-check is the security boundary.

## Permission-cache propagation

When a super_admin grants a role to a user that imparts super-admin-category permissions:

- The affected user's `PermissionChecker` cache refreshes via Phase 6's three observation points (R-17).
- The "Super-admin" tile appears within a few seconds of the affected user foregrounding the app (spec SC-011).
- The route guards immediately admit the affected user once the cache reflects the new permissions.

## Verification (Manual UI walk on Infinix Note 8)

1. Sign in as a regular `user` account → confirm `/admin` not reachable (home page admin tile hidden); attempt deep-link `/admin/super-admin/roles` → bounced.
2. Sign in as a `moderator` (granted via Supabase MCP `execute_sql` in setup) → confirm `/admin` reachable (admin tile visible); confirm "Super-admin" tile is NOT in the admin home; attempt deep-link → bounced.
3. Sign in as an `admin` (post-Phase-6 backfill admin) → same as moderator (admin lacks the super-admin-category keys).
4. Sign in as the bootstrapped `super_admin` → confirm "Super-admin" tile visible on admin home; tap it → `RolesListPage` opens; navigate to `/admin/super-admin/roles/<role_id>` directly → editor opens; navigate to `/admin/super-admin/assign` → assign page opens.
5. From the super_admin's session, foreground/background the app after another super_admin grants `moderator` to a regular user on a second device → the affected user's session shows the admin tile within seconds (SC-011).
