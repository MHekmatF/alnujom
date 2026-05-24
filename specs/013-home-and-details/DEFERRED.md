# Phase 13 Deferred Items

## D-01 — Follow-up alias removal: `AppRoutes.shellHome` / `AppRouteNames.shellHome`

**Introduced by**: T041 (Sub-Phase F — Routing rewire)

**Status**: Retained per R-69 — interim back-compat aliases are intentional for one PR lifetime.

**Detail**: Sub-Phase F renamed `AppRoutes.shellHome` → `AppRoutes.home` (value `'/'`) and
`AppRouteNames.shellHome` → `AppRouteNames.home` (value `'home'`). Both old names are retained
as `static const shellHome = home;` aliases in `lib/core/routing/app_router.dart`.

**In-tree consumers still on the alias (3 call sites across 2 files)**:
- `lib/features/auth/presentation/pages/publisher_approval_pending_page.dart` line 37:
  `context.go(AppRoutes.shellHome)` — resolves correctly via alias.
- `lib/features/listing_form/presentation/pages/listing_form_page.dart` lines 78, 81, 91:
  three `context.go(AppRoutes.shellHome)` calls — all resolve correctly via alias.

**Decision**: Left on alias intentionally (not migrated in this commit) to keep the diff minimal
for the Phase 13 PR review. The alias resolves to `AppRoutes.home` (`'/'`) at compile time — no
behavioral difference.

**Remediation**: In a follow-up PR (or Phase 14 prep), replace all four `AppRoutes.shellHome`
references with `AppRoutes.home` and delete the `static const shellHome = home;` lines from both
`AppRoutes` and `AppRouteNames`.

**Responsible phase**: Phase 14 (search surface) or a standalone cleanup PR — whichever touches
`listing_form_page.dart` or `publisher_approval_pending_page.dart` first.
