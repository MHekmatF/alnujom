# Contract: Locations Routing & Admin-Home Tile

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Spec**: [../spec.md](../spec.md) FR-012, FR-013

## Admin-home tile

The Phase 6 `AdminHomePage` (`lib/features/admin/presentation/pages/admin_home_page.dart`) MUST gain one new tile:

```dart
// Inside the tile list builder, after the Phase 5 admin-queue tile and the Phase 7 super-admin tile:
if (permissionChecker.has(PermissionKeys.locationsManage))
  AdminTile(
    icon: Icons.location_on_outlined,                                  // Phase 2 token icon
    title: l10n.locationsTileTitle,
    onTap: () => context.go('/admin/locations'),
  ),
```

The tile MUST be hidden (NOT dimmed) for users without `locations.manage`. The visibility check uses `PermissionChecker.has('locations.manage')` (Phase 6 helper) — no hardcoded role check.

## Four new go_router routes

Registered in `lib/app.dart` (or the equivalent `go_router` configuration file). Each route carries a redirect guard reading `PermissionChecker.has(PermissionKeys.locationsManage)`; failure redirects to the established admin-route unauthorized destination (matching Phase 6's `/admin` and Phase 7's `/admin/super-admin/...` pattern).

| Route | Page | Redirect guard | Params |
|---|---|---|---|
| `/admin/locations`                                              | `LocationsListPage`      | `PermissionChecker.has('locations.manage')` | — |
| `/admin/locations/:governorateId`                               | `GovernorateDetailPage`  | same | `governorateId` (path) |
| `/admin/locations/:governorateId/cities/:cityId`                | `CityDetailPage`         | same | `governorateId`, `cityId` (path) |
| `/admin/locations/form`                                         | `LocationFormPage`       | same | `mode`, `level`, `id`, `parentId` (query) |

The redirect helper MUST also handle the case where the route parameters are malformed or reference deleted entities — fall back to `/admin/locations` with a localized error toast.

## Route-guard precedent

Phase 6 / Phase 7 routes use a single helper (`lib/core/routing/auth_redirect.dart` or equivalent) that checks `PermissionChecker.any(<set of keys>)` and redirects to `/access-denied` (or the home tab) on failure. Phase 8 extends this helper with the four new routes; Phase 6 / Phase 7 route entries are not modified.

## Mid-session permission propagation (FR-011, R-17 from Phase 6)

The Phase 6 `PermissionChecker` cache-refresh observation points (cold start, auth-state token refresh, app foreground resume) carry forward unchanged. When an admin is granted `locations.manage` via Phase 7's `RoleEditorPage` mid-session:

1. The cache refreshes on the next observation point (typically foreground resume — within seconds).
2. The admin-home page re-renders with the Locations tile visible.
3. The router accepts navigation to `/admin/locations` once the cache reflects the grant.

No new lifecycle mechanism is needed in Phase 8.

## Verification

- Sign in as a regular user → admin-home is not visible (no admin tier at all).
- Sign in as a moderator (no `locations.manage`) → admin-home renders without Locations tile; deep link `/admin/locations` redirects.
- Sign in as an admin (`locations.manage` via §9.1) → admin-home renders with Locations tile; tap → `LocationsListPage` opens.
- Revoke `locations.manage` from the admin role via Phase 7's `RoleEditorPage` → on next foreground resume, the Locations tile disappears.
- Re-grant → on next foreground resume, the tile reappears.

## Constitution traceability

- Constitution VII (Dynamic Roles & Permissions): every gate consults the data-driven permission graph.
- Constitution III (Security-First Supabase): three-layer enforcement (tile hidden + route guard + RLS write deny).
- Phase 6 R-15 / R-17 invariants: PermissionChecker cache-refresh + admin-home tile pattern preserved.
