---
description: "Task list — Admin Dashboard (Phase 20)"
---

# Tasks: Admin Dashboard (Phase 20)

**Input**: Design documents from `specs/020-admin-dashboard/`
**Prerequisites**: plan.md, spec.md (+ research.md, data-model.md, contracts/, quickstart.md)

**Tests**: No new automated tests (project MVP convention, memory `feedback_no_new_tests`). Verification is manual on-device + wire-level SQL/RPC checks per `quickstart.md`. No test tasks are generated.

**Convention note**: The existing admin features (`lib/features/admin/reports/`) use `data/dtos/` (not `data/models/`) and a `Cubit + _state.dart` pair. Tasks below follow that established convention. `Result<T>`/`Failure` live in `lib/core/errors/`.

**Organization**: Tasks are grouped by user story (Setup → Foundational → US1 → US5 → Polish). The plan's execution-phase mapping (P1 = counts migration; P2 = audit-policy swap + viewer; P3 = dashboard grid + counters) is preserved in the Wave Plan at the end.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1–US5 (maps to the spec's user stories); Setup/Foundational/Polish carry no story label
- Exact file paths are included in every task

## Path Conventions

Mobile app (Flutter) + Supabase backend, established two-tree layout. New code lives under `lib/features/admin/dashboard/`, `lib/features/admin/audit_logs/`, and `supabase/migrations/`. Existing entry points (`admin_home_page.dart`, `app_router.dart`, `auth_redirect.dart`, the two ARBs) are amended.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the two feature-tree skeletons and confirm the build baseline before any wiring.

- [ ] T001 [P] Create the `lib/features/admin/dashboard/{data/{datasources,dtos,repositories},domain/{entities,repositories,usecases},presentation/{bloc,widgets}}` folder skeleton (`.gitkeep` per dir), mirroring `lib/features/admin/reports/`.
- [X] T002 [P] Create the `lib/features/admin/audit_logs/{data/{datasources,dtos,repositories},domain/{entities,repositories,usecases},presentation/{bloc,pages}}` folder skeleton, mirroring `lib/features/admin/reports/`.
- [ ] T003 Confirm the build baseline is green before changes: run `flutter analyze` and `dart run build_runner build --delete-conflicting-outputs` and record that they pass (no new deps — verifies the FR-018 starting point).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The two backend migrations every counter/viewer behavior depends on. Pure new/changed SQL files, no shared-file contention; they unblock all UI work.

⚠️ **CRITICAL**: The counts function (T004) must exist before US2/US3 counters return real data; the audit-policy swap (T005) must be applied before US5's viewer returns rows for an `audit_logs.view` holder.

- [ ] T004 [P] Create migration `supabase/migrations/20260601120003_create_admin_dashboard_counts.sql` — the `public.admin_dashboard_counts()` SECURITY DEFINER + STABLE function returning one row of five nullable BIGINT counts, each wrapped in `CASE WHEN current_user_has_permission(<key>) THEN (count…) ELSE NULL END`; `REVOKE EXECUTE FROM PUBLIC, anon; GRANT EXECUTE TO authenticated`. Body per `data-model.md` §1.1; gates per `contracts/phase20-admin-dashboard-counts-rpc.md`. **At implement time, re-base the `active_listings` window predicate on the live `v_listings_public` / listings public-read predicate (research R-158 note). NOTE the pending-users count keys on `account_approval_requests.status = 'pending'` — the column is `status` (an `account_approval_status` enum), NOT `decision`; the IMPLEMENTATION_PLAN §6.2 wrote `decision` but the shipped migration uses `status`. Verify `listings.status`, `reports.status`, `inquiries.created_at` against the live schema before applying (a wrong column makes `CREATE FUNCTION` fail under `check_function_bodies`).**
- [X] T005 [P] Create migration `supabase/migrations/20260601120004_align_audit_logs_read_to_permission.sql` — `DROP POLICY IF EXISTS audit_logs_select_admin ON public.audit_logs; CREATE POLICY audit_logs_select_admin ON public.audit_logs FOR SELECT TO authenticated USING (current_user_has_permission('audit_logs.view'))` (swaps the predicate from the role-based `current_user_is_admin()` to the data-driven permission; no write policy; table stays append-only). Body per `data-model.md` §1.2 + `contracts/phase20-audit-logs-read.md`.
- [ ] T006 Apply T004 + T005 to the live project via Supabase MCP `apply_migration` in timestamp order (per memory `project_supabase_apply_via_mcp`), then run `get_advisors` and confirm: `admin_dashboard_counts` exists in `pg_proc`, and the `audit_logs_select_admin` policy `USING` clause references `current_user_has_permission('audit_logs.view')` (via `pg_policy`). (quickstart step 1)

---

## Phase 3: User Story 1 — Permission-gated tile hub (Priority: P1) 🎯 MVP

**Goal**: The existing `admin_home_page.dart` becomes a permission-gated tile **grid** at `/admin`; each tile renders only for its gating permission and routes to the existing surface; Ads/Settings show as disabled coming-soon tiles; non-admins stay redirected by the existing guard.

**Independent test**: Sign in as a moderator vs. a super-admin → tile sets differ and match permissions exactly; tapping a tile opens its existing admin surface; a non-admin is redirected from `/admin`. (SC-001; SC-002 route half)

- [ ] T007 [P] [US1] Create `lib/features/admin/dashboard/domain/entities/dashboard_section.dart` — `enum DashboardSectionState { enabled, comingSoon }` + `DashboardSection` value object (`labelKey`, `permissionKeys` any-of, `route?`, `state`, optional counter selector), per `data-model.md` §2.2.
- [ ] T008 [US1] Define the canonical section list (Users, Listings, Reports, Agencies, Inquiries, Locations, Currencies, Roles&Permissions-combined, Audit-logs, Ads-comingsoon, Settings-comingsoon) with each section's gating `PermissionKeys.*` and destination `AppRoutes.*`, per `contracts/phase20-dashboard-ui-and-entry-points.md`, as a const in `lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart`. (The Audit-logs route constant `AppRoutes.adminAuditLogs` is added in US5/T020 — reference it here; it resolves once T020 lands per the wave order.)
- [ ] T009 [P] [US1] Create `lib/features/admin/dashboard/presentation/widgets/coming_soon_tile.dart` (disabled, non-navigating, permission-gated — Ads/Settings, Phase 2 tokens) and `dashboard_tile.dart` (enabled tile that `context.push(route)`).
- [ ] T010 [US1] Rewrite the body of `lib/features/admin/presentation/pages/admin_home_page.dart` from the current `ListView` of `ListTile`s into a responsive grid built from the T008 section list: each section wrapped in its `PermissionChecker.has/any` guard (keep existing per-tile gate semantics), enabled tiles → `dashboard_tile.dart`, Ads/Settings → `coming_soon_tile.dart`, preserve the existing `_EmptyState`. Keep the `/admin` route + `authRedirect` guard unchanged (FR-001). Counter slots are wired in US2 (T015) — leave them absent here.
- [ ] T011 [P] [US1] Add the US1 l10n keys (reuse the existing admin-home title; new tile labels for audit-logs/ads/settings; a "coming soon" suffix), namespaced `dashboard*`, to BOTH `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`; run `flutter gen-l10n`.

**Checkpoint**: US1 is independently shippable — the grid renders, tiles gate correctly, coming-soon tiles show, navigation works.

---

## Phase 4: User Story 2 — Operational counters (Priority: P1)

**Goal**: The dashboard shows the five counters, each gated to its section's permission and sourced from the `admin_dashboard_counts` RPC; `0` renders, unpermitted counters are omitted; loading/error states are localized and tiles stay navigable.

**Independent test**: As super-admin, each counter equals the seeded fixture within ~2 s; as a narrower admin, ungated counters are absent (not zero); simulate a counts failure → tiles still navigate, counters show retry. (SC-003, SC-008, SC-010)

- [ ] T012 [P] [US2] Create `lib/features/admin/dashboard/domain/entities/dashboard_counts.dart` — `DashboardCounts` with five `int?` fields (`null` = not permitted → omit; `0` = render), per `data-model.md` §2.1.
- [ ] T013 [US2] Create `lib/features/admin/dashboard/data/dtos/dashboard_counts_dto.dart` (maps the `admin_dashboard_counts` row → `DashboardCounts`, preserving `null`), `data/datasources/dashboard_counts_datasource.dart` (`supabase.rpc('admin_dashboard_counts')`, Supabase types confined here), `domain/repositories/dashboard_repository.dart` (abstract, returns `Result<DashboardCounts>`), and `data/repositories/dashboard_repository_impl.dart` — all `@injectable`, mirroring `lib/features/admin/reports/` wiring.
- [ ] T014 [P] [US2] Create `lib/features/admin/dashboard/domain/usecases/load_dashboard_counts.dart` (`@injectable`) and `lib/features/admin/dashboard/presentation/bloc/dashboard_cubit.dart` + `dashboard_state.dart` (loading / loaded(counts) / error; `load()` and `refresh()` share one path; NO `Timer`, NO Realtime — FR-011/FR-020).
- [ ] T015 [US2] Wire counters into the T010 grid in `admin_home_page.dart`: provide `DashboardCubit` (load on entry), attach each counter to its section tile, render `0` distinctly from an absent/`null` counter (FR-010), show localized loading then error/retry while keeping tiles navigable (FR-012). Run `dart run build_runner build --delete-conflicting-outputs` to regenerate DI.
- [ ] T016 [P] [US2] Add the US2 counter l10n keys (one label per counter + loading/error/retry strings), namespaced `dashboard*`, to BOTH `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`; run `flutter gen-l10n`.

**Checkpoint**: Counters render, are permission-gated end-to-end, and degrade gracefully.

---

## Phase 5: User Story 3 — Backend permission enforcement (checks at both ends) (Priority: P1)

**Goal**: Verify (no new code beyond T004's gating) that a counter cannot be obtained without its permission at the wire level, and that data-driven permission changes reshape the dashboard.

**Independent test**: Wire-level `rpc('admin_dashboard_counts')` from a session lacking `reports.manage` returns `NULL` for `open_reports`; `anon` is denied; grant a permission + refresh → the tile/counter appears with no code change. (SC-004, SC-011; SC-002 data half)

- [ ] T017 [US3] Wire-verify the server-side gate: from a non-`reports.manage` authenticated session call `select * from admin_dashboard_counts();` and confirm `open_reports` is `NULL` while permitted counters are non-NULL; from `anon` confirm `EXECUTE` is denied; from a no-admin-permission session confirm `/admin` redirects AND the RPC returns all-NULL/denied. Record results in the quickstart run-log (step 8). If any counter leaks, fix the `CASE` gate in T004's migration.
- [ ] T018 [US3] Verify the data-driven reshape: grant `reports.manage` (or `audit_logs.view`) to a test user's role, refresh the `PermissionChecker` (re-login), reopen `/admin`, confirm the corresponding tile + counter now appear with no code change (SC-011, quickstart step 4b); confirm zero hardcoded role branches in `lib/features/admin/dashboard/` via grep (FR-015).

**Checkpoint**: "Checks at both ends" demonstrated; gating is data-driven.

---

## Phase 6: User Story 4 — Counter quick-actions & refresh (Priority: P2)

**Goal**: Counters/tiles deep-link into the relevant filtered queue; pull-to-refresh and screen-re-entry update counters; no auto-update without a refresh.

**Independent test**: Tap pending-listings → listing-review pending queue; open-reports → reports queue; pending-users → approvals; new-inquiries → `/admin/inquiries`. Submit a listing from another session → counter unchanged until pull-to-refresh, then increments. (SC-005, SC-006)

- [ ] T019 [US4] Add quick-action deep links + refresh in `lib/features/admin/presentation/pages/admin_home_page.dart`: each counter-bearing tile's primary action routes to its filtered queue (`AppRoutes.adminListingReviewPending`, `AppRoutes.adminReports`, `AppRoutes.adminApprovals`, `AppRoutes.adminInquiries`) per `contracts/phase20-dashboard-ui-and-entry-points.md` (FR-009); add a `RefreshIndicator` (precedent: `lib/features/admin/reports/presentation/pages/reports_queue_page.dart`) calling `DashboardCubit.refresh()` plus an on-re-entry reload (FR-011); verify no `Timer`/`.channel(` in the dashboard code (FR-020).

**Checkpoint**: Dashboard is a launchpad; freshness model matches the spec.

---

## Phase 7: User Story 5 — Read-only audit-log viewer (Priority: P3)

**Goal**: The Audit-logs tile opens a read-only, paginated, localized, themed viewer of `audit_logs`, gated by `audit_logs.view` at both the tile and the swapped RLS policy; non-holders are redirected and read zero rows.

**Independent test**: As an `audit_logs.view` holder, the viewer lists entries newest-first, paginates, offers no write affordance; a non-holder sees no tile, `/admin/audit-logs` redirects, and a wire-level select returns zero rows; a custom role with ONLY `audit_logs.view` CAN read (proving permission-, not role-, gating). (SC-012)

- [X] T020 [US5] Add the route end-to-end: `AppRoutes.adminAuditLogs = '/admin/audit-logs'` + `AppRouteNames.adminAuditLogs` + a child `GoRoute` under `/admin` (builder `const AuditLogsViewerPage()`, `redirect: requireAuditLogsViewRedirect`) in `lib/core/routing/app_router.dart`; add `requireAuditLogsViewRedirect` (needs `audit_logs.view`, else returns `'/admin?denied=audit_logs'`) in `lib/core/routing/auth_redirect.dart`, mirroring `requireReportsManageRedirect`. Confirm the US1 Audit-logs section constant (T008) resolves to `AppRoutes.adminAuditLogs`.
- [X] T021 [P] [US5] Create `lib/features/admin/audit_logs/domain/entities/audit_log_entry.dart` — `AuditLogEntry` (`id` String/UUID, `actorUserId?`, `action`, `targetType`, `targetId?`, `beforeState?`, `afterState?`, `createdAt`), per `data-model.md` §2.3 (note: `audit_logs.id` is UUID, not int).
- [X] T022 [US5] Create the audit data+domain layer: `lib/features/admin/audit_logs/data/dtos/audit_log_entry_dto.dart`, `data/datasources/audit_logs_datasource.dart` (`supabase.from('audit_logs').select('id,actor_user_id,action,target_type,target_id,before_state,after_state,created_at').order('created_at', ascending: false)` with a bounded page/cursor — no unbounded scan), `domain/repositories/audit_log_repository.dart` (abstract, paged `Result<List<AuditLogEntry>>`), `data/repositories/audit_log_repository_impl.dart`, and `domain/usecases/load_audit_log_page.dart` — all `@injectable`.
- [X] T023 [US5] Create `lib/features/admin/audit_logs/presentation/bloc/audit_log_cubit.dart` + `audit_log_state.dart` (paged loading/loaded/error) and `presentation/pages/audit_logs_viewer_page.dart` — read-only paginated list (actor, action, target, timestamp; expandable before/after), NO create/edit/delete affordance, localized + Phase 2 tokens, RTL/LTR correct. Run `dart run build_runner build --delete-conflicting-outputs`.
- [X] T024 [P] [US5] Add the US5 l10n keys (viewer title, column/field labels, empty-state; reuse the `denied=...` message pattern), namespaced `auditLogs*`, to BOTH `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`; run `flutter gen-l10n`.

**Checkpoint**: The audit-log viewer is the one net-new admin surface — gated and read-only.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Four-combination rendering, constitution grep gates, and the full quickstart pass.

- [ ] T025 [P] Four-combination render pass on the reference Infinix Note 8 (≈480 dp) + a 412 dp emulator: cycle (light/dark) × (ar-RTL/en-LTR) across the grid, counters, coming-soon tiles, loading/empty-zero/error states, and the audit viewer; confirm all strings localized, direction-correct, Phase 2 tokens only (no inline hex/font/padding). (SC-007, FR-017)
- [ ] T026 [P] Constitution grep gates: zero new pubspec deps (`git diff pubspec.yaml` deps section empty); zero new permission keys (`lib/core/security/permission_keys.dart` + `supabase/migrations/20260515120002_create_permissions.sql` unchanged); zero hardcoded role branches in `lib/features/admin/dashboard/` + `lib/features/admin/audit_logs/`; no `Timer`/Supabase `.channel(`/Realtime in the new code. (SC-009)
- [ ] T027 Execute the full `quickstart.md` (steps 1–11) end-to-end and record pass/fail per Success Criterion in the run-log; file any gap in `specs/020-admin-dashboard/DEFERRED.md` (memory `feedback_strict_task_completion`).

---

## Dependencies & Story Completion Order

- **Setup (Phase 1)** → no deps.
- **Foundational (Phase 2)** → no code deps; unblocks live verification of US2/US5.
- **US1 (Phase 3)** → after Setup. **MVP** — independently shippable (grid + gated tiles + navigation; counters absent).
- **US2 (Phase 4)** → after US1 (wires counters into the T010 grid) + T004 applied (RPC) for real data.
- **US3 (Phase 5)** → after US2 + T004 (verifies the gate authored in T004; no new code).
- **US4 (Phase 6)** → after US2 (deep-links + refresh on counter tiles).
- **US5 (Phase 7)** → after US1 (the Audit-logs tile/section) + T005 applied (policy) for live reads; T020 supplies the route constant the US1 tile references.
- **Polish (Phase 8)** → after all stories.

## Parallel Execution Examples

- **Setup**: T001 ∥ T002 (different trees); then T003.
- **Foundational**: T004 ∥ T005 (distinct new migration files); then T006 (apply, ordered).
- **US1**: T007 ∥ T009 ∥ T011, then T008 → T010.
- **US2**: T012 ∥ T016, then T013 → T014 → T015.
- **US5**: T021 ∥ T024, then T020 → T022 → T023.

## Implementation Strategy (MVP first)

1. Setup + Foundational (T001–T006) — skeletons + both migrations applied.
2. **US1 (T007–T011) = MVP**: ship the gated grid alone if needed.
3. Layer US2 (counters) → US3 (verify gate) → US4 (quick-actions/refresh) → US5 (audit viewer).
4. Polish (T025–T027): four-combo render, grep gates, full quickstart.

**Total: 27 tasks** — Setup 3, Foundational 3, US1 5, US2 5, US3 2, US4 1, US5 5, Polish 3.

---

<!-- ============================================================ -->
<!-- MULTI-AGENT EXECUTION SECTIONS (for /wave orchestration)     -->
<!-- ============================================================ -->

## Touch-Fan Table

Shared files each **plan-phase** modifies (orchestrator warns sub-agents up front, merges least-touch-first). Plan-phase → tasks: **P1** = T004; **P2** = T005 + T020–T024 (audit-policy swap + viewer); **P3** = T007–T016, T019 (dashboard grid + counters). T006 (apply) / T017–T018 / T025–T027 are verification, no source touch.

- **P1 (counts migration)**: `supabase/migrations/20260601120003_create_admin_dashboard_counts.sql` *(new file only — no shared-file touch)*
- **P2 (audit viewer + policy swap)**: `supabase/migrations/20260601120004_align_audit_logs_read_to_permission.sql` (new), `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/di/injection.config.dart` (codegen), `lib/features/admin/audit_logs/**` (new)
- **P3 (dashboard grid + counters)**: `lib/features/admin/presentation/pages/admin_home_page.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/di/injection.config.dart` (codegen), `lib/features/admin/dashboard/**` (new)

**Conflict hotspots**: `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, and `lib/core/di/injection.config.dart` are touched by BOTH P2 and P3 → merge P2 first (the code edge forces it), then P3 rebases and re-runs `dart run build_runner build --delete-conflicting-outputs`. ARB edits are additive with namespaced keys (`dashboard*` vs `auditLogs*`) → union-merge, no key collisions expected. P1 touches only its own new file → conflict-free.

## Dependency Audit

Re-reading the plan's Phase Dependencies. One declared code edge:

- **P3 depends on P2** — `lib/features/admin/presentation/pages/admin_home_page.dart` (P3; via the section const in T008) consumes the route constant **`AppRoutes.adminAuditLogs`**, which is added to `lib/core/routing/app_router.dart` by P2 (T020), for the Audit-logs tile's `context.push(AppRoutes.adminAuditLogs)`. **Named consumer present → dependency is real, kept.**

Runtime contracts (NOT build edges — no Dart symbol crosses; both compile/`flutter analyze` independently; listed for completeness, excluded from the wave graph):
- P3's `supabase.rpc('admin_dashboard_counts')` (T013) ↔ P1's function (T004) — string-keyed runtime call.
- P2's `supabase.from('audit_logs').select(...)` (T022) ↔ the policy swapped by T005 — runtime RLS contract.

**Audit result**: 1 declared dep, 1 with a named consumer, **0 false deps to remove**. Graph is already minimal (one edge → two waves).

## Wave Plan

Topological sort over plan-phases (P1, P2, P3), cap 4/wave:

- **Wave 1**: **P1, P2** — no code edge between them (P1 = counts migration; P2 = audit-policy swap + audit-log viewer slice, which owns the new route constant).
- **Wave 2**: **P3** — depends on P2 (consumes `AppRoutes.adminAuditLogs`).

Two waves, max width 2 — well under the cap. (The verification-only work — US3's T017–T018 and Polish T025–T027 — adds no code and can fold into the owning sub-agent or run as a docs/verification Wave 3; not split out here.)

`/wave all --auto` executes this directly without re-deriving.

## Model Routing per Phase

- **P1 (counts migration, T004 + apply/verify T006/T017)**: **Opus** — SECURITY DEFINER + per-counter RLS permission gating; a leak is cross-permission data exposure ("RLS / invariants" heuristic).
- **P2 (audit-policy swap + viewer, T005 + T020–T024)**: **Opus** — the RLS-policy predicate swap (T005) is a security change ("RLS" heuristic); the viewer slice (T020–T024) is Sonnet-grade scaffolding, but route the single P2 sub-agent **Opus** since the RLS change dominates risk.
- **P3 (dashboard grid + counters, T007–T016, T019)**: **Sonnet** — widgets, l10n, DI scaffolding, a cubit, and a read-only RPC datasource; no atomic/ledger/state-machine logic (the server-side gate is in P1, already Opus).
- **Polish (T025–T027)**: **Sonnet** — manual verification, grep gates, quickstart run-log.

Compact: `P1: Opus (SECURITY DEFINER counts + RLS gating). P2: Opus (audit_logs RLS predicate swap + read-only viewer). P3: Sonnet (grid + counters + l10n + DI).`

## Checkbox Discipline (MANDATORY for every sub-agent)

Each sub-agent dispatched against this `tasks.md` MUST flip its `- [ ] T<id>` checkboxes to `- [X] T<id>` **in the same commit as the implementation of that task** — never deferred to a "cleanup pass." A task whose verification is partial/caveated stays `- [ ]` with a `**⚠️ PARTIAL —**` note plus a `DEFERRED.md` entry (memory `feedback_strict_task_completion`).
