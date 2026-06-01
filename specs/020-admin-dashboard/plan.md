# Implementation Plan: Admin Dashboard (Phase 20)

**Branch**: `main` (spec tracked via `.specify/feature.json` → `specs/020-admin-dashboard`) | **Date**: 2026-06-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/020-admin-dashboard/spec.md`

> **Setup-script note**: `setup-plan.ps1` aborts on `main` ("not on a feature branch") and, when forced, resolves the git-tracked `019-agencies` instead of the untracked `020-admin-dashboard`; running it once clobbered the committed Phase 19 `plan.md`, which was restored from git (`git checkout -- specs/019-agencies/plan.md`). This Phase 20 plan was authored directly against `.specify/feature.json`, the project's real active-feature pointer.

## Summary

Phase 20 upgrades the **existing** admin home (`lib/features/admin/presentation/pages/admin_home_page.dart`, today a permission-gated `ListView` of eight tiles) into a unified **admin dashboard**: a permission-gated tile **grid** that adds **five operational counters** (pending users, pending listings, open reports, new inquiries-24h, active listings), **quick-action deep links** from each counter into its filtered queue, **coming-soon tiles** for the not-yet-built Ads (Phase 21) and Settings (Phase 23) sections, and a brand-new minimal **read-only audit-log viewer** (the Audit-logs section's destination — no prior phase owned a viewer). Two small read-only backend migrations: (1) an `admin_dashboard_counts()` SECURITY DEFINER aggregate that enforces the caller's permissions server-side; (2) a one-statement swap of the existing `audit_logs_select_admin` RLS policy's predicate from the role-based `current_user_is_admin()` to the data-driven `current_user_has_permission('audit_logs.view')`, so the audit-log read gate matches the `audit_logs.view` tile gate the spec mandates (FR-021) and Principle VII (data-driven, not role-based). Refresh is on-entry + pull-to-refresh only (no timer; Realtime is Phase 22). Zero new dependencies, zero new permission keys, zero new tables, zero schema changes. The feature reuses the Phase 6 `PermissionChecker`/`current_user_has_permission` gates, the existing `/admin*` route guards (`authRedirect` over `PermissionKeys.adminCategoryKeys`), and the Phase 4 `audit_logs` table.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase); PL/pgSQL
**Primary Dependencies**: `supabase_flutter`, `flutter_bloc`, `get_it` + `injectable`, `go_router`, `equatable`, `intl`, `cached_network_image` (all already in `pubspec.yaml`; Phase 20 adds ZERO new deps per FR-018)
**Storage**: Supabase Postgres — NO new tables, NO schema change, NO new enum. ONE new SECURITY DEFINER function (`admin_dashboard_counts()`) + ONE RLS-policy predicate swap on the existing `audit_logs` table (no column/table change).
**Testing**: Manual on-device verification (Infinix Note 8 + Pixel 8 Pro AVD) per the project's no-new-tests MVP convention (memory `feedback_no_new_tests`); SQL/RPC wire-level permission checks; `flutter analyze`
**Target Platform**: Android (minSdk per project); Arabic-first RTL + English LTR
**Project Type**: Mobile app (Flutter) + Supabase backend — the established two-tree layout
**Performance Goals**: Counts come from a single bounded aggregate (no per-tile scans); the audit-log viewer paginates over the existing `idx_audit_logs_created_at`; counters refresh on entry + pull-to-refresh only (no auto-poll timer, no Realtime — FR-011/FR-020)
**Constraints**: ZERO new deps (FR-018); ZERO new permission keys / no §9.1 catalog change (FR-019); no new table, no schema change; no Realtime (FR-020); checks-at-both-ends for every counter AND for the audit viewer (FR-013/FR-014/FR-021); no hardcoded role branch (FR-015) — the audit-policy swap actively REMOVES a role-based gate in favor of the permission key
**Scale/Scope**: 2 migrations (counts fn + audit-policy swap); 2 small Flutter feature trees (`dashboard`, `audit_logs`); 1 rewritten page (`admin_home_page.dart`); 1 new page (audit-log viewer); 1 new route + guard; ~25 l10n keys

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ Pass | spec.md + 4 clarifications complete before this plan; data-model/contracts/quickstart accompany it |
| II. Source-Controlled Backend | ✅ Pass | Counts fn + audit-policy swap land as migration files under `supabase/migrations/`; no Studio-only changes |
| III. Security-First Supabase | ✅ Pass | Counts aggregate enforces permissions server-side; the audit-policy swap keeps RLS admin-only AND aligns it to the data-driven `audit_logs.view`; no service-role on client; checks-at-both-ends (FR-013/014/021) |
| IV. Clean Architecture | ✅ Pass | `lib/features/admin/dashboard/` + `admin/audit_logs/` in data/domain/presentation; Supabase types confined to data/ |
| V. Arabic-First Localization | ✅ Pass | ~25 new keys in both `app_ar.arb` + `app_en.arb`; RTL-safe grid + viewer |
| VI. Theme System | ✅ Pass | Phase 2 tokens only; no inline hex/font/padding (FR-017) |
| VII. Dynamic Roles & Permissions | ✅ Pass | Every tile + counter gated by data-driven keys; no hardcoded role branch (FR-015); the audit-policy swap REMOVES the last role-based gate on the audit surface in favor of `audit_logs.view` |
| VIII. Approval Workflow & Identity | ✅ Pass (N/A-leaning) | No identity/approval mutation; counters only surface aggregate state of existing approval queues |
| IX. Future Backend Portability | ✅ Pass | Repository interfaces in domain/; `supabase_flutter` only in data/ |
| X. Testable AI Workflow | ✅ Pass | Per-FR/SC verification map in data-model + quickstart |
| XI. Android-First MVP | ✅ Pass | No iOS/Web/desktop code |
| XII. No Hidden Decisions | ✅ Pass | 4 clarifications resolved + the audit-policy-swap decision recorded here + in research R-161 |

**Gate result**: PASS — no violations, no Complexity Tracking rows needed.

## Project Structure

### Documentation (this feature)

```text
specs/020-admin-dashboard/
├── plan.md              # This file
├── research.md          # Phase 0 — locked decisions R-154..R-163
├── data-model.md        # Phase 1 — counts fn + audit-policy-swap SQL + Dart entities
├── quickstart.md        # Phase 1 — end-to-end manual verification recipe
├── contracts/           # Phase 1 — interface contracts
├── checklists/
│   └── requirements.md  # spec quality checklist (from /speckit-specify)
└── tasks.md             # Phase 2 — (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/features/admin/dashboard/             # NEW — dashboard counts slice
├── data/{datasources,dtos,repositories}/     # admin_dashboard_counts RPC datasource, DashboardCountsDto, impl
├── domain/{entities,repositories,usecases}/  # DashboardCounts, DashboardSection; DashboardRepository; LoadDashboardCounts
└── presentation/{bloc,widgets}/              # DashboardCubit; dashboard_sections.dart, dashboard_tile.dart, coming_soon_tile.dart

lib/features/admin/audit_logs/            # NEW — read-only audit-log viewer slice
├── data/{datasources,dtos,repositories}/     # paginated audit_logs select; AuditLogEntryDto; impl
├── domain/{entities,repositories,usecases}/  # AuditLogEntry; AuditLogRepository; LoadAuditLogPage
└── presentation/{bloc,pages}/                # AuditLogCubit; AuditLogsViewerPage

lib/features/admin/presentation/pages/
└── admin_home_page.dart                  # REWRITTEN — ListView → dashboard grid + counters

lib/core/routing/
├── app_router.dart                       # AMENDED — adminAuditLogs route + name + GoRoute
└── auth_redirect.dart                    # AMENDED — requireAuditLogsViewRedirect guard

lib/l10n/{app_ar.arb, app_en.arb}         # AMENDED — ~25 dashboard + audit-log keys

supabase/migrations/
├── 20260601120003_create_admin_dashboard_counts.sql       # NEW — counts aggregate fn (P1)
└── 20260601120004_align_audit_logs_read_to_permission.sql # NEW — swap audit RLS predicate to audit_logs.view (P2)
```

**Structure Decision**: Established two-tree layout (Flutter `lib/features/` + Supabase `supabase/`). Two small new feature trees under `lib/features/admin/` mirror the existing `account_approvals` / `listing_review` / `reports` / `agencies` admin-feature shape. The dashboard grid replaces the body of the existing `admin_home_page.dart` in place. Migration timestamps are `20260601120003`/`…004` because `…001`/`…002` already exist (Phase 19 follow-ups).

## Implementation Phases

> Phase 20 is one PR, decomposed into three implementation phases (P1–P3) so `/wave` can fan out. P1 is backend-only (one new migration file). P2 is the audit-log viewer — its own new migration (audit-policy swap) + the self-contained Flutter slice + the new route. P3 is the dashboard grid + counters and holds the only cross-phase code dependency.

### P1 — Backend: dashboard counts aggregate
Create `public.admin_dashboard_counts()` (SECURITY DEFINER, STABLE) returning the five counts as a single row, each guarded by `current_user_has_permission(<key>)` so a caller receives only the counts they may see (NULL otherwise). `REVOKE EXECUTE FROM PUBLIC, anon; GRANT EXECUTE TO authenticated`. Counts: pending users (`account_approval_requests.status='pending'` — column is `status`, NOT `decision`, gate `users.view`/`users.approve`), pending listings (`listings.status='pending_review'`, gate `listings.view_all`/`listings.approve`), open reports (`reports.status IN ('new','reviewing')`, gate `reports.manage`), new inquiries 24h (`inquiries.created_at >= now()-interval '24 hours'`, gate `inquiries.view_all`), active listings (`listings.status='approved'` within publish window, gate `listings.view_all`/`listings.approve`). Apply via Supabase MCP (memory `project_supabase_apply_via_mcp`).
**Touch fan**: `supabase/migrations/20260601120003_create_admin_dashboard_counts.sql` (new file only — no shared-file conflict).

### P2 — Audit-log viewer: RLS-predicate swap + Flutter slice + route
Backend: migration `20260601120004_align_audit_logs_read_to_permission.sql` — `DROP POLICY audit_logs_select_admin; CREATE POLICY audit_logs_select_admin ON audit_logs FOR SELECT TO authenticated USING (current_user_has_permission('audit_logs.view'))`. This swaps the predicate from the role-based `current_user_is_admin()` (Phase 4 `20260506120005`, redefined to a role check by Phase 6 `20260515120006`) to the data-driven permission, matching the tile gate (FR-003/FR-021) + Principle VII. Net access is unchanged today (only admin/super_admin hold `audit_logs.view`); it only diverges for future custom roles. Table stays append-only (no write policy added). Flutter: build `lib/features/admin/audit_logs/` (entity `AuditLogEntry`; `AuditLogRepository` + impl; paginated datasource selecting `id, actor_user_id, action, target_type, target_id, before_state, after_state, created_at` ordered `created_at DESC`; `AuditLogCubit`; `AuditLogsViewerPage` — read-only, paginated, localized, themed). Register the route end-to-end: `AppRoutes.adminAuditLogs='/admin/audit-logs'` + `AppRouteNames.adminAuditLogs` + a `GoRoute` under `/admin` in `app_router.dart`, plus `requireAuditLogsViewRedirect` in `auth_redirect.dart` (mirrors `requireReportsManageRedirect`). Add l10n keys + DI registration.
**Touch fan**: `supabase/migrations/20260601120004_align_audit_logs_read_to_permission.sql` (new), `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/di/injection.config.dart` (codegen), `lib/features/admin/audit_logs/**` (new).

### P3 — Flutter: dashboard grid + counters (rewrites admin_home_page.dart)
Build `lib/features/admin/dashboard/` (entity `DashboardCounts`; `DashboardRepository` + impl; datasource calling the `admin_dashboard_counts` RPC; `LoadDashboardCounts` usecase; `DashboardCubit`). Rewrite `admin_home_page.dart`: keep every existing permission-gated tile, re-lay them as a responsive grid, attach the matching counter to each counter-bearing tile, add the quick-action deep links, add the **Audit-logs** tile (→ `AppRoutes.adminAuditLogs`), and add **disabled coming-soon tiles** for Ads (`ads.manage`) and Settings (`settings.manage`). Wire pull-to-refresh + on-entry load; localized loading/empty-zero/error states. Add l10n keys + DI registration.
**Touch fan**: `lib/features/admin/presentation/pages/admin_home_page.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/di/injection.config.dart` (codegen), `lib/features/admin/dashboard/**` (new).

## Phase Dependencies

> Rule honored: every declared dependency names the specific exported symbol or file path the dependent phase consumes. Runtime-only contracts (a Dart datasource calling a Postgres function by string name, or a `.select()` gated by an RLS policy) are **not** code dependencies — they compile and `flutter analyze` independently — so they are listed separately as "Runtime contracts," not as build-order edges.

**Declared code dependencies (build/merge order edges):**

- **P3 depends on P2** — `lib/features/admin/presentation/pages/admin_home_page.dart` (P3) references the route constant `AppRoutes.adminAuditLogs` exported by `lib/core/routing/app_router.dart` as added in P2, for the Audit-logs tile's `onTap: () => context.push(AppRoutes.adminAuditLogs)`. This is the only cross-phase code edge.

**Runtime contracts (NOT build-order edges — no named Dart symbol crosses the boundary):**

- P3's dashboard counts datasource calls the Postgres function `admin_dashboard_counts` (created by P1) via `supabase.rpc('admin_dashboard_counts')` — a string-keyed runtime call, not a Dart import. P3 compiles and `flutter analyze`s without P1. End-to-end counter verification (quickstart) requires P1 applied.
- P2's audit datasource performs `supabase.from('audit_logs').select(...)` gated by the policy P2's own migration swaps — a runtime RLS contract, not a Dart import. The Dart slice compiles independently of whether the migration has been applied; live reads behave per the applied predicate.

**Self-audit**: Declared code deps = **1** (P3→P2). Deps lacking a named consumer = **0**. P1 has no inbound or outbound code edges. P2's two halves (its migration + its Flutter slice) are internally cohesive and have no code edge to P1. The SQL↔Dart relationship (P3↔P1 RPC) is a runtime contract, not a build edge — keeping the build graph lean.

**Resulting execution waves:**

- **Wave 1 (parallel):** P1, P2 — no code edges between them.
- **Wave 2:** P3 — after P2 (consumes `AppRoutes.adminAuditLogs`).

**Merge-order guidance for `/wave`** (from Touch fan overlap, not code edges): P2 and P3 both append to `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, and regenerate `lib/core/di/injection.config.dart`. Merge P2 before P3 (the code edge already forces this); the P3 sub-agent MUST rebase on the merged P2 and re-run `dart run build_runner build --delete-conflicting-outputs` to regenerate `injection.config.dart`, and resolve ARB key-set unions (additive — no key collisions expected since dashboard and audit-log keys are namespaced). P1 touches only its own new migration file and merges in any order with no contention. P1's and P2's migrations have distinct timestamps (`…003`/`…004`) and no ordering dependency between them.

## Complexity Tracking

No constitution violations. No complexity exceptions required.

*Plan version: 1.2 (corrected via code verification: audit-read policy exists but was role-gated; Phase 20 swaps it to the `audit_logs.view` permission — backend = 2 migrations) | Generated by /speckit-plan | Aligned with constitution v1.0.0*
