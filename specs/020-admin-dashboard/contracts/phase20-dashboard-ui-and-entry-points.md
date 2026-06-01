# Contract: Dashboard UI, tiles, counters & entry points (Phase 20)

Defines the Flutter-side surface: the section set, each tile's gate + destination, the counter bindings, and the routing additions. Consumed by P3 (audit-log viewer + route) and P4 (dashboard grid).

## Entry point

- Route: **existing** `/admin` (`AppRoutes.admin` → `AdminHomePage`). The dashboard is an in-place rewrite of `admin_home_page.dart` (FR-001) — no new dashboard route.
- Access guard: **existing** `authRedirect` blocks any caller lacking every `PermissionKeys.adminCategoryKeys` key from `/admin*` (reused, not rebuilt).

## Section tiles

Each tile renders only when `PermissionChecker.any(keys)` is true. Enabled tiles `context.push(route)`; coming-soon tiles are disabled and non-navigating.

| Section | Gate keys (any-of) | Destination | Counter |
|---------|--------------------|-------------|---------|
| Users | `users.view`, `users.approve` | `AppRoutes.adminApprovals` | pending_users |
| Listings | `listings.view_all`, `listings.approve`, `listings.reject`, `listings.edit_any` | `AppRoutes.adminListingReviewPending` | pending_listings, active_listings |
| Reports | `reports.manage` | `AppRoutes.adminReports` | open_reports |
| Agencies | `agencies.view`, `agencies.approve`, `agencies.suspend` | `AppRoutes.adminAgencies` | — |
| Inquiries | `inquiries.view_all` | `AppRoutes.adminInquiries` | new_inquiries_24h |
| Locations | `locations.manage` | `AppRoutes.locationsAdmin` | — |
| Currencies | `currencies.manage` | `AppRoutes.currenciesAdmin` | — |
| Roles & Permissions (combined) | `roles.view`/`create`/`update`/`delete`, `permissions.manage` (`superAdminCategoryKeys`) | `AppRoutes.superAdminRoles` | — |
| Audit logs | `audit_logs.view` | **`AppRoutes.adminAuditLogs`** (NEW, P3) | — |
| Ads | `ads.manage` | — (coming-soon) | — |
| Settings | `settings.manage` | — (coming-soon) | — |

Notes: Roles & Permissions stays one combined "super-admin" tile (Clarification Q3). Ads/Settings are disabled coming-soon (Clarification Q1). Audit logs routes to the new viewer (Clarification Q2).

## Counter bindings

- A counter renders next to / on its section tile only when its `DashboardCounts` field is non-`null`.
- `null` → omit the counter (caller not permitted). `0` → render `0` (FR-010).
- Tap on a counter (or the tile's primary action) deep-links to the filtered queue (FR-009): pending_listings → `AppRoutes.adminListingReviewPending`; open_reports → `AppRoutes.adminReports`; pending_users → `AppRoutes.adminApprovals`; new_inquiries_24h → `AppRoutes.adminInquiries`.

## Refresh

- `DashboardCubit` loads on entry and on pull-to-refresh; NO timer, NO Realtime (FR-011/FR-020). Loading / empty-zero / error states are localized; tiles remain navigable when counts fail (FR-012).

## Routing additions (P3 only)

```
AppRoutes.adminAuditLogs      = '/admin/audit-logs';   // NEW
AppRouteNames.adminAuditLogs  = 'admin-audit-logs';    // NEW
// GoRoute under '/admin': path 'audit-logs', redirect: requireAuditLogsViewRedirect,
//   builder: (_, __) => const AuditLogsViewerPage()
// requireAuditLogsViewRedirect: mirrors requireReportsManageRedirect; needs audit_logs.view,
//   else redirect '/admin?denied=audit_logs'.
```

## Localization

~25 new keys across both `app_ar.arb` + `app_en.arb`: admin-home title (exists — reuse), each tile label (most exist — reuse; new: audit-logs, ads, settings, coming-soon suffix), each counter label, loading/empty/error strings, audit-log viewer title + column/field labels + empty-state. New keys MUST be additive and namespaced (e.g., `dashboardCounterPendingUsers`, `auditLogsTitle`) to avoid collisions between the P3 and P4 ARB edits.

## Acceptance checks

See spec SC-001..SC-012 and quickstart.
