# Research: Admin Dashboard (Phase 20)

Phase 0 output. Locked plan-time decisions R-154..R-163. Each resolves an unknown surfaced by the spec or the Technical Context. No `NEEDS CLARIFICATION` remains (the four spec-level ambiguities were resolved in `/speckit-clarify`).

---

## R-154 — Counts via a single SECURITY DEFINER aggregate function (not a materialized view, not per-tile queries)

**Decision**: Implement the five counters as ONE `public.admin_dashboard_counts()` PL/pgSQL function, `SECURITY DEFINER`, `STABLE`, returning a single row (one nullable BIGINT column per counter). Each counter's SELECT is wrapped in `CASE WHEN current_user_has_permission(<key>) THEN (count…) ELSE NULL END`, so an unpermitted caller gets `NULL` for that counter and the UI omits it.
**Rationale**: The plan text says "Materialized view or RPC." A materialized view cannot vary its result by caller (it has no `auth.uid()` context and would leak counts across permission boundaries) and would go stale, contradicting the on-entry-refresh model. A single function is one round-trip (FR-008 "single bounded aggregate"), enforces permissions server-side (FR-013), and is the established project pattern (mirrors the SECURITY DEFINER read paths in `v_agencies`/`resolve_report_internal`). Per-tile separate queries were rejected as N round-trips and harder to keep permission-consistent.
**Alternatives considered**: Materialized view (rejected — caller-invariant, stale); one RPC per counter (rejected — N round-trips); client-side row counting (rejected — unbounded, violates FR-008 + leaks rows).

## R-155 — SECURITY DEFINER + explicit per-counter permission gate (checks at both ends)

**Decision**: The function is `SECURITY DEFINER` (so it can read RLS-protected source tables) but gates EACH counter on `current_user_has_permission(<section key>)` evaluated for the *invoking* user (captured before the definer context via `auth.uid()` semantics already used by `current_user_has_permission`). `REVOKE EXECUTE … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated`.
**Rationale**: Definer rights are required because the source tables (`account_approval_requests`, `reports`, `inquiries`) are admin-only under RLS; without definer the function would see nothing. But definer rights mean the function MUST re-impose the permission gate itself (FR-013/FR-014, Principle III "checks at both ends"), exactly as Phase 18's `resolve_report_internal` and Phase 12's `*_internal` wrappers do. The frontend `PermissionChecker` hide (FR-002/FR-007) is the second end.
**Alternatives considered**: `SECURITY INVOKER` (rejected — caller can't read the admin source tables, every count returns 0); trusting the frontend hide alone (rejected — UI-only gate is a leak, violates Principle III).

## R-156 — `current_user_has_permission` is the gate, never a role string

**Decision**: All gating (function-side and Flutter-side) routes through the Phase 6 data-driven permission helpers: backend `public.current_user_has_permission(perm_key)` (`supabase/migrations/20260515120005_create_permission_predicate.sql`), frontend `PermissionChecker.has/any` (`lib/core/security/permission_checker.dart`) with keys from `PermissionKeys` (`lib/core/security/permission_keys.dart`).
**Rationale**: FR-015 + Principle VII forbid hardcoded role branches; granting/removing a permission must reshape the dashboard on the next `PermissionChecker` refresh with no code change. These helpers already exist and are used by every admin surface.
**Alternatives considered**: `if (role == 'admin')` (rejected — Principle VII violation); a new dashboard-specific permission (rejected — FR-019 forbids new keys).

## R-157 — Counter→section permission mapping

**Decision**: pending users → `users.view`/`users.approve`; pending listings + active listings → `listings.view_all`/`listings.approve`; open reports → `reports.manage`; new inquiries (24h) → `inquiries.view_all`. "Any-of" where listed. Tiles use the same keys as their counter and the same keys the destination surface already gates on.
**Rationale**: Aligns the counter posture with the existing tile/route guards so a counter never appears without its tile (and vice-versa). Mirrors the §6.4 RLS matrix + §9.1 catalog. Keys verified against `PermissionKeys` and `20260515120002_create_permissions.sql`.
**Alternatives considered**: A single coarse "admin" gate for all counters (rejected — over-discloses to narrow-permission admins).

## R-158 — Counter semantics (exact predicates, reuse existing statuses)

**Decision**: pending users = `account_approval_requests.status = 'pending'` (the column is `status`, an `account_approval_status` enum — NOT `decision`, which the IMPLEMENTATION_PLAN §6.2 wrote but the shipped `20260510120001` migration does not use); pending listings = `listings.status = 'pending_review'`; open reports = `reports.status IN ('new','reviewing')`; new inquiries 24h = `inquiries.created_at >= now() - interval '24 hours'`; active listings = `listings.status = 'approved'` AND within publish window (the same predicate the public listing read already uses). No new status value, no new column.
**Rationale**: FR-006 + Assumptions fix these five exactly; reusing the Phase 5/10/12/16/18 status vocabulary keeps the counts consistent with each destination queue and introduces no schema change (FR-019).
**Alternatives considered**: counting all-time inquiries (rejected — FR-006 says rolling 24h); adding an "agencies pending" counter (rejected — out of the plan's named five).

## R-159 — Refresh model: on-entry + pull-to-refresh, no timer, no Realtime

**Decision**: `DashboardCubit` loads counts on screen entry and on explicit pull-to-refresh; NO periodic `Timer`, NO Supabase Realtime subscription. Structure the cubit so a Phase 22 Realtime trigger can call the same `refresh()` without redesign.
**Rationale**: Clarification Q4 = on-entry + pull-to-refresh only; FR-011/FR-020 + the project performance note ("no eager realtime subscriptions on home", cheap-device battery/data). A timer adds cost for marginal benefit when Phase 22 brings real liveness.
**Alternatives considered**: 60 s auto-poll (rejected — Q4); foreground-resume refetch (rejected — Q4, kept minimal); Realtime now (rejected — FR-020, deferred to Phase 22, see `project_phase22_perm_cache_revisit`).

## R-160 — Coming-soon tiles for Ads + Settings; build the audit-log viewer

**Decision**: Ads (`ads.manage`) and Settings (`settings.manage`) render as **disabled, permission-gated, non-navigating** "coming soon" tiles (Clarification Q1). Audit-logs is the exception: build a minimal read-only viewer now (Clarification Q2 / FR-021), because the `audit_logs` table + `audit_logs.view` permission exist but no phase owns a viewer.
**Rationale**: The plan enumerates Ads/Settings/Audit-logs as dashboard sections; coming-soon honors the plan + signals the roadmap while letting Phases 21/23 only wire the route. Audit-logs differs — its data + permission already exist, so a viewer is cheap and removes an orphaned permission.
**Alternatives considered**: omit unbuilt tiles (rejected Q1 — silently drops plan-named sections); coming-soon the audit viewer too (rejected Q2 — leaves `audit_logs.view` with no consumer).

## R-161 — The `audit_logs` read policy EXISTS but is role-gated; Phase 20 swaps it to the `audit_logs.view` permission

**Decision**: Phase 20 adds a one-statement migration (`20260601120004_align_audit_logs_read_to_permission.sql`) that swaps the existing `audit_logs_select_admin` policy predicate from `current_user_is_admin()` to `current_user_has_permission('audit_logs.view')`. The table stays append-only (no write policy; `log_audit()` remains the only writer). The viewer then reads `public.audit_logs` through this aligned policy.
**Rationale (verified against the repo)**: The policy already exists (Phase 4, `20260506120005_enable_rls_default.sql`) but its `USING` clause is `current_user_is_admin()`, which Phase 6 (`20260515120006_swap_admin_predicate_to_role_check.sql`) redefined to a role-based check (user holds a role with key in `admin`/`super_admin`), NOT the data-driven `audit_logs.view` permission. The spec gates the Audit-logs tile and viewer on `audit_logs.view` (FR-003/FR-021), and Principle VII forbids role-based gates. Without the swap, the frontend tile (gated on `audit_logs.view`) and the backend RLS (gated on the role) would use different gates, coinciding today (only admin/super_admin hold `audit_logs.view`) but diverging for any future custom role. The swap is net-zero access change today and aligns the backend to the permission. (Corrects two earlier drafts: the first wrongly said the policy was missing; the second wrongly said it already used `audit_logs.view`. Ground truth: it exists and is role-gated via `current_user_is_admin()`.)
**Alternatives considered**: keep the role-based gate and gate the frontend tile on the admin role instead (rejected, contradicts the spec + Principle VII); a SECURITY DEFINER `v_audit_logs` view (rejected, the swapped plain policy already does the job).

## R-162 — Reuse the existing `/admin` route + guards; add only the audit-logs route

**Decision**: The dashboard stays at the existing `/admin` `GoRoute` (builder already = `AdminHomePage`); the only routing addition is `AppRoutes.adminAuditLogs = '/admin/audit-logs'` + `AppRouteNames.adminAuditLogs` + a `GoRoute` with `requireAuditLogsViewRedirect` (mirroring `requireReportsManageRedirect`/`requireAgenciesManageRedirect` in `auth_redirect.dart`). The `/admin*` admin-access guard (`authRedirect` over `PermissionKeys.adminCategoryKeys`) is reused unchanged.
**Rationale**: FR-001 reuses the existing guard; the dashboard is an in-place upgrade of `admin_home_page.dart`, not a new route. Only the new viewer needs a route + its own permission redirect. Denials follow the existing `/admin?denied=<section>` convention.
**Alternatives considered**: a brand-new `/admin/dashboard` route (rejected — FR-001 upgrades `/admin` in place, avoids a dead second surface); gating the viewer only at the tile (rejected — Principle III needs the route guard + the RLS policy from R-161).

## R-163 — Two small feature trees mirroring the existing admin features; ZERO new deps

**Decision**: `lib/features/admin/dashboard/` and `lib/features/admin/audit_logs/`, each data/domain/presentation, registered via `injectable` (regenerate `injection.config.dart`). No new pubspec package, no new Postgres extension, no Android manifest change (FR-018).
**Rationale**: Mirrors `lib/features/admin/{account_approvals,listing_review,reports,agencies}`; keeps Supabase types in `data/` (Principle IV/IX). The whole feature is buildable on the inherited stack.
**Alternatives considered**: folding both into the existing `admin/presentation/` (rejected — the counts + audit-log read paths deserve their own domain/data layers per Clean Architecture); a charting/dashboard package (rejected — FR-018, counters are plain text tiles).

---

**Unknowns resolved**: all. **Open for `/speckit-tasks`/plan-time (non-blocking)**: exact grid breakpoint columns (phone vs. tablet), whether the audit viewer adds optional filters (FR-021 marks them optional), and the precise return shape of `admin_dashboard_counts` (single composite row vs. JSON) — all implementation details captured in contracts/ as the agreed contract.
