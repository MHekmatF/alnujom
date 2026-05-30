# Implementation Plan: Reports & Moderation

**Branch**: `018-reports-moderation` | **Date**: 2026-05-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/018-reports-moderation/spec.md`

## Summary

Phase 18 ships the community-moderation loop: the working Report control that Phase 13 left as a Coming-soon stub (the rightmost CTA in `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart`, currently `_showComingSoon(context, l10n.action_report_coming_soon)`), the first consumer of the `reports.manage` permission key Phase 6 seeded onto the `moderator` + `admin` roles, and an admin queue that resolves each report with a moderation action that may transition the reported listing. The plan delivers: (a) two new Supabase tables — `public.reports` (a signed-in user's complaint about one listing: reporter, reason, optional note, lifecycle status `new`/`reviewing`/`resolved`/`dismissed`, the `reviewing_by` soft-claim columns per Q4=B, and the `resolved_by`/`resolved_at`/`resolution` columns) and `public.moderation_actions` (the append-only record of the admin action taken — `dismiss`/`hide`/`mark_duplicate`/`delete` — with target listing, performing admin, optional note, and before/after listing state); (b) RLS matching IMPLEMENTATION_PLAN §6.4 — `reports` readable by its own reporter (`reporter_user_id = auth.uid()`) OR by any `reports.manage` holder, NO client INSERT (creation is RPC-only so `reporter_user_id` cannot be forged), NO client UPDATE/DELETE (resolution + claim go through privileged paths); `moderation_actions` readable by `reports.manage` holders only, written only by the resolution path; no `anon` policy on either table; (c) a `public.submit_report(p_listing_id, p_reason, p_note)` SECURITY DEFINER RPC (mirroring Phase 16's `record_lead_event` posture) that requires an authenticated session, validates the listing exists and is `status='approved'` per Q6=A, enforces the open-report dedup (one open report per reporter+listing), inserts the `reports` row with `reporter_user_id = auth.uid()`, and captures IP/UA — granted to `authenticated` only; (d) the resolution path mirroring Phase 12's `approve_listing` exactly — a `resolve_report` Edge Function (`supabase/functions/resolve_report/index.ts`) that JWT-gates on `current_user_has_permission('reports.manage')` then invokes a service-role-only SECURITY DEFINER `resolve_report_internal(p_report_id, p_actor_user_id, p_action, p_note)` RPC that, in one transaction, sets `app.current_user_id` (so the existing Phase 10/12 listing triggers attribute the actor), updates the report to its terminal status, inserts the paired `moderation_actions` row, applies the action's listing transition via the existing status machinery (Q1=A: `dismiss`→no change, `hide`→`paused`, `mark_duplicate`→`rejected` with `app.current_rejection_reason='duplicate'`, `delete`→`deleted`), auto-resolves sibling open reports on the same listing for a listing-affecting action (Q5=A), and lets the reports resolution-audit trigger fire; (e) a lightweight `public.start_report_review(p_report_id)` SECURITY DEFINER RPC implementing the Q4=B advisory soft-claim (self-gates on `reports.manage`, sets `status='reviewing'` + `reviewing_by = auth.uid()`, overridable); (f) a `public.v_reports` SECURITY INVOKER view joining `reports` → `listings` (+ main image + governorate/city names) projecting the queue/My-Reports card fields, NOT filtered on listing status, so the base-table RLS scopes it (reporter sees own rows, `reports.manage` sees all); (g) a reporter-facing feature folder `lib/features/reports/` (the report sheet wired into the Phase 13 Report CTA, the `/reports` "My Reports" page reached from a Profile tile, and the reporter-only status banner on the listing details page, per Q3=Both) plus an admin moderation folder `lib/features/admin/reports/` (the `reports.manage`-gated queue with status/reason filters + pagination, and the resolve flow with the four actions and destructive-action confirmation), following the Phase 12 `listing_review` Clean-Architecture shape; (h) the admin-home "Reports" tile gated on `reports.manage`, a `/admin/reports` route guarded by a new `requireReportsManageRedirect`, and a `/reports` route guarded like `/favorites`; (i) ARB-driven localization for the report sheet, the eight reason labels, the queue + resolve copy, the My-Reports + banner strings, the "Sign in to report" prompt, and the two Profile/admin tile labels. Phase 18 adds ZERO new pubspec dependencies, ZERO new value to the `lead_events.event_type` CHECK (reports are NOT lead events), and ZERO new value to the Phase 10 listings status enum (Q1=A reuses existing statuses). Principles I (Spec-First), III (Security-First Supabase), and VII (Dynamic Roles & Permissions) are the load-bearing gates.

**Technical approach**: Reports & moderation follow the same Clean Architecture layering as Phases 12–17 (`presentation/bloc` → `domain/usecases` → `domain/repositories` → `data/repositories` → `data/datasources` → `core/network`). Three security boundaries are load-bearing. First, the **reporter-self + admin read boundary** (Principle III + FR-025/FR-026): the `reports` SELECT policy is `USING (reporter_user_id = auth.uid() OR public.current_user_has_permission('reports.manage'))`, so a normal user sees only their own reports while a moderator sees the full queue; `moderation_actions` is `reports.manage`-only; the `v_reports` view is `SECURITY INVOKER` (the Phase 16 `20260527120013_phase16_view_invoker_lockdown.sql` precedent) so the base-table RLS applies to view reads and a reporter's "My Reports" + the admin queue read the SAME view with naturally different row visibility. Second, the **bypass-proof write boundary** (FR-010 + FR-025): row creation is performed ONLY by `submit_report` (SECURITY DEFINER, `reporter_user_id := auth.uid()`), and report resolution/claim is performed ONLY by the privileged paths — there is NO client INSERT/UPDATE/DELETE grant on `reports` and NO client write on `moderation_actions`, so a client cannot forge a report, resolve someone else's report, or fabricate a moderation record. Third, the **checks-at-both-ends resolution boundary** (Principle III + VII + FR-012/FR-033): the `resolve_report` Edge Function rejects callers lacking `reports.manage` (the same `parseJwtSub` → `jwtClient.rpc('current_user_has_permission', {perm_key})` gate `approve_listing/index.ts` uses), AND `resolve_report_internal` is `GRANT EXECUTE … TO service_role` only (never client-callable), so even a bypassed front-end cannot resolve a report. The resolution reuses the Phase 12 atomic-wrapper trick (`20260523120005_approve_reject_atomic_wrappers.sql`): `resolve_report_internal` does `PERFORM set_config('app.current_user_id', p_actor_user_id::text, true)` (and, for `mark_duplicate`, `set_config('app.current_rejection_reason', 'duplicate', true)`) before the listing UPDATE so the existing `listing_status_transition_trigger_fn` + `listings_audit_trigger_fn` fire inside the same transaction and write the status-history + listing audit rows with correct attribution; the report's own resolution is audit-logged by a `reports` AFTER-UPDATE trigger reusing the Phase 4 `log_audit()` trigger function. The four actions map to the existing Phase 10 status enum (Q1=A) — no new status value. Sibling auto-resolve (Q5=A) is a single `UPDATE public.reports … WHERE listing_id = p_listing_id AND status IN ('new','reviewing') AND id <> p_report_id` plus a per-sibling `moderation_actions` insert, all inside the one transaction. The reporter UI mirrors the Phase 17 anonymous-aware pattern: the Report CTA (and a shared report-sheet launcher) checks the auth state and, when signed out, shows the localized "Sign in to report" prompt and `context.push(AppRoutes.login)` with no pre-auth side effect (FR-006/FR-007). The admin queue + My-Reports pages paginate via the Phase 13 cursor convention.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase) / PL/pgSQL; one Deno/TypeScript Edge Function (`resolve_report`), mirroring the Phase 12 `approve_listing` runtime.

**Primary Dependencies**: NONE added in Phase 18 (FR-031). Reports & moderation are built entirely from the inherited stack already in `pubspec.yaml`: `flutter`, `flutter_localizations`, `supabase_flutter`, `flutter_bloc`, `go_router`, `get_it`, `injectable`, `intl`, `cached_network_image`, `equatable`. The Edge Function reuses the existing `@supabase/supabase-js` import already used by `supabase/functions/approve_listing/index.ts`.

**Storage**: Supabase Postgres adds TWO new tables — `public.reports` and `public.moderation_actions` — under `supabase/migrations/`. `reports.listing_id` references `public.listings(id)` (Phase 10, `20260519120002_create_listings.sql`) with `ON DELETE RESTRICT` (Phase 16/17 precedent); `reports.reporter_user_id` references `auth.users(id)` with `ON DELETE CASCADE`; `reports.resolved_by` / `reports.reviewing_by` reference `auth.users(id)` with `ON DELETE SET NULL`; `moderation_actions.report_id` references `public.reports(id)` with `ON DELETE SET NULL` and `moderation_actions.performed_by` references `auth.users(id)` with `ON DELETE SET NULL` (R-131 — the moderation log survives the reporter's and the admin's account deletion). Phase 18 adds three SECURITY DEFINER PL/pgSQL functions (`submit_report`, `resolve_report_internal`, `start_report_review`), one SECURITY INVOKER view (`v_reports`), one `reports` resolution-audit trigger reusing Phase 4 `log_audit()`, and the RLS policies. It makes ZERO schema change to `public.lead_events` (reports are not lead events) and ZERO change to the `public.listings` status CHECK (Q1=A). No new extension is enabled.

**Testing**: Per project convention (memory `feedback_no_new_tests.md`), no new automated tests are added in Phase 18. Existing tests remain. Manual UI verification on the reference Infinix Note 8 + Pixel 8 Pro AVD (memory `user_test_device.md` + `feedback_avd_acceptable_qa.md`) is the gate; `quickstart.md` captures the recipe — including the load-bearing two-user + admin + anonymous wire-level capture confirming the reporter-self / admin-only / no-anon read matrix (SC-009), the unauthorized-resolve rejection at both the Edge-Function and RPC layers (SC-010), and the atomic resolution + sibling auto-resolve checks (SC-006, SC-015).

**Target Platform**: Android only (Constitution Principle XI). Reference device: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11); Pixel 8 Pro emulator (Android 14, 412 dp width) for secondary checks.

**Project Type**: Mobile app (Flutter) + Supabase backend — existing layout per `lib/features/<feature>/{presentation,domain,data}/` and `supabase/{migrations,functions,docs}/`.

**Performance Goals**:

- Report submission → localized confirmation within ~1 s after the RPC returns; report row written within 2 s (SC-001).
- Admin queue initial load → first paint within 2 s on a standard Syrian 4G connection (cursor query on indexed `(status, created_at DESC)`).
- Report resolution → terminal state + moderation action + listing transition committed atomically; the resolved listing leaves the public feed within one refresh (SC-005).
- "My Reports" page + admin queue both paginate (no unbounded query) (SC-014).

**Constraints**:

- A report MUST be readable only by its own reporter and by `reports.manage` holders; `moderation_actions` only by `reports.manage` holders; never by anonymous (FR-025/FR-026/FR-027 + SC-009). Enforced by RLS on both tables + the SECURITY INVOKER `v_reports` view.
- A report MUST NOT be creatable with a forged `reporter_user_id`, nor resolvable by an unauthorized caller (FR-010/FR-012 + SC-006/SC-010). Enforced by NO client INSERT/UPDATE/DELETE on `reports`, NO client write on `moderation_actions`, the `submit_report` SECURITY DEFINER RPC setting `reporter_user_id := auth.uid()`, and the `resolve_report` Edge-Function permission gate + service-role-only `resolve_report_internal`.
- Resolution MUST be atomic — report status + moderation action + listing transition + audit in one transaction (FR-013 + SC-006). Guaranteed by the single `resolve_report_internal` PL/pgSQL body.
- A listing-affecting action MUST auto-resolve sibling open reports; `dismiss` MUST NOT (FR-016 + SC-004). Enforced inside `resolve_report_internal`.
- The four actions MUST reuse the existing listings status enum — NO new status value (Q1=A + FR-014/FR-034). The transitions reuse the Phase 12 `set_config('app.current_user_id')` + `set_config('app.current_rejection_reason')` machinery so the existing triggers fire.
- Reporting MUST be authenticated-only; the Report CTA renders for everyone and prompts sign-in on tap (Q2=A + FR-006/FR-007). `submit_report` validates `status='approved'` (Q6=A + FR-010).
- Reporters MUST see resolution status on a "My Reports" page AND an inline details-page banner (Q3=Both + FR-022/FR-023), both self-scoped via RLS.
- The admin surface MUST be gated by the data-driven `reports.manage` permission (frontend `PermissionChecker` + backend RLS / Edge-Function check), NEVER a hardcoded role branch (Principle VII + FR-032 + SC-013).
- Constitution IX-clean: no `package:supabase_flutter` import outside `lib/features/reports/data/` and `lib/features/admin/reports/data/`. The `Report`, `ReportReason`, `ReportStatus`, `ModerationAction`, `ModerationActionType` types live in `domain/` and import zero Supabase types.
- Constitution V (Arabic-first) + VI (design tokens): all new strings flow through ARB (`ar` + `en`); every new widget reads Phase 2 tokens — no inline hex/font/padding.
- The Phase 13 `PerListingActionBlock` Report CTA IS modified (its Coming-soon handler is replaced) per FR-001; the Share CTA and the Phase 17 Favorite toggle MUST remain untouched and the surrounding widget tree MUST NOT be reflowed (FR-034).

**Scale/Scope**:

- 10 sub-phases (A–J) organized into 4 waves with parallel execution where the dependency graph permits.
- 8 new Supabase migrations under `supabase/migrations/` (timestamp prefix `20260530`, continuing after Phase 17's `20260529120007`): 2 tables (`...120001` reports, `...120002` moderation_actions), 1 policies (`...120003`), 1 view (`...120004`), 1 reports-audit trigger (`...120005`), 1 submit RPC (`...120006`), 1 resolve + claim RPCs (`...120007`), 1 advisor-hardening (`...120008`). 0 schema changes to existing tables. Plus 1 new Edge Function `supabase/functions/resolve_report/index.ts`.
- 2 Flutter feature areas: a new `lib/features/reports/` (reporter-facing) and a new `lib/features/admin/reports/` (moderation). ~30 new Dart files total. 4 existing files patched (`app_router.dart`, `auth_redirect.dart`, `admin_home_page.dart`, `profile_page.dart`) + 2 listing-details files (`per_listing_action_block.dart`, `listing_details_page.dart`). ZERO new pubspec dependencies.
- ~22 new bilingual ARB keys (8 reason labels + sheet/queue/resolve/banner/my-reports/prompt/tile copy) — final breakdown in Sub-Phase J.
- 16 plan-time research decisions (R-119 through R-134) resolved in `research.md`.
- 8 contract files in `contracts/`.

---

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `specs/018-reports-moderation/spec.md` exists with 5 user stories, 36 FRs (FR-001..FR-036), 15 SCs, 6 clarifications resolved (3 in `/speckit-specify`: Q1 reuse-statuses, Q2 auth-required+prompt, Q3 both visibility surfaces; 3 in `/speckit-clarify`: Q4 reviewing soft-claim, Q5 sibling auto-resolve, Q6 approved-only submit gate). This plan + data-model + contracts + quickstart land before any implementation. |
| II. Source-Controlled Backend | **Pass** | All backend artifacts (2 tables, 1 policies file, 1 view, 1 audit trigger, 3 RPCs across 3 migrations, 1 advisor-hardening, 1 Edge Function) are checked in under `supabase/migrations/` + `supabase/functions/`; per-table docs land at `supabase/docs/reports.md` + `supabase/docs/moderation_actions.md`. The Supabase MCP `apply_migration` applies them; the files are the source of truth. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS enabled on `public.reports` (reporter-self OR `reports.manage` read; no client INSERT/UPDATE/DELETE) and `public.moderation_actions` (`reports.manage` read; no client write). Creation via the SECURITY DEFINER `submit_report` RPC; resolution gated at BOTH the `resolve_report` Edge Function (`current_user_has_permission('reports.manage')`) AND the service-role-only `resolve_report_internal` RPC (Principle "checks at both ends"). `v_reports` is `SECURITY INVOKER`. No service-role key on the client. All three RPCs use `SET search_path` per the advisor-hardening convention. |
| IV. Clean Architecture Flutter | **Pass** | `lib/features/reports/` and `lib/features/admin/reports/` each use the standard 3 layers. Business rules (open-dedup display logic, anonymous-prompt routing, the four-action resolve flow, sibling-aware queue refresh) live in `domain/` use cases + cubits/blocs. The admin queue mirrors the Phase 12 `lib/features/admin/listing_review/` structure (`pending_queue_bloc.dart` → `pending_queue_page.dart`). |
| V. Arabic-First Localization | **Pass** | ~22 new strings (8 reason labels + sheet/queue/resolve/banner/my-reports/prompt/tile copy) land in BOTH `app_ar.arb` AND `app_en.arb` in Sub-Phase J. No inline `Text('...')` literals (grep gate in quickstart). Arabic copy is Syrian-friendly (e.g., "الإبلاغ عن العقار" for Report listing, "سجّل الدخول للإبلاغ" for the sign-in prompt). |
| VI. Theme System & Design Tokens | **Pass** | The report sheet, queue cards, resolve dialog, My-Reports cards, status chips, and the reporter banner all read `Theme.of(context).colorScheme` + `AppSpacing` + `AppRadii` + `AppTextStyles`. No inline hex/raw-font/ad-hoc padding. The admin tile + Profile tile match the existing tile token usage. |
| VII. Dynamic Roles & Permissions | **Pass** | The admin surface is gated by the data-driven `reports.manage` permission (`PermissionKeys.reportsManage`) via `PermissionChecker.has(...)` (frontend tile + route redirect) AND `current_user_has_permission('reports.manage')` (Edge Function + RLS). NO hardcoded role branch — verified by SC-013's grep gate. Resolution writes an `audit_logs` row via the reports resolution-audit trigger + the listing audit triggers (Principle VII audit mandate). |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Reports can be filed only against `status='approved'` listings (Q6=A). Moderation takedowns (`hide`/`mark_duplicate`/`delete`) flow through the existing Phase 12 status machinery and `listing_status_history`, surfacing the outcome to the publisher exactly as Phase 12 rejections do. No publisher private field is read or projected; the reporter's identity is visible only to `reports.manage` holders. |
| IX. Future Backend Portability | **Pass** | `Report`, `ReportReason`, `ReportStatus`, `ModerationAction`, `ModerationActionType`, and the repository interfaces live in `domain/` and import zero Supabase types. Concrete Supabase access (RPC calls, view reads, the Edge-Function invocation) lives in the `data/datasources/`. A grep gate in quickstart verifies no Supabase import under `domain/` or `presentation/`. |
| X. Testable AI Workflow | **Pass** | Every Phase 2 task (tasks.md, forthcoming) carries acceptance criteria derived from the FRs + SCs. `quickstart.md` captures one verification step per SC, including the wire-level read-matrix capture (SC-009), the dual-layer unauthorized-resolve rejection (SC-010), and the atomic-resolution + sibling auto-resolve SQL checks (SC-006, SC-015). The `/wave` orchestrator uses the Touch-fan notes below for conflict-free merge order. |
| XI. Android-First MVP | **Pass** | Zero new dependencies; zero new platform code. No iOS/Web/desktop. The report sheet + queue are pure Flutter Material; the backend is standard Postgres + one Deno Edge Function matching the existing Phase 12 runtime. No Android manifest change. |
| XII. No Hidden Product Decisions | **Pass** | All 6 clarifications are recorded in `spec.md`'s Clarifications section with rationale. The 16 plan-time decisions (R-119..R-134) are recorded in `research.md`, including the one item the spec left plan-time (the `reporter_user_id` ON DELETE behavior → R-131). Forward-stated deferrals (publisher notification of reports → Phase 22; reporter reputation, report rate-limiting, reporting of non-listing targets → future specs) are explicit in `spec.md` Assumptions + this plan. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

---

## Project Structure

### Documentation (this feature)

```text
specs/018-reports-moderation/
├── plan.md                     # This file (/speckit-plan output)
├── spec.md                     # /speckit-specify + /speckit-clarify output (committed)
├── research.md                 # Phase 0 output (R-119..R-134)
├── data-model.md               # Phase 1 output (full SQL migration bodies + Dart entities + FR/SC verification map)
├── quickstart.md               # Phase 1 output (end-to-end manual recipe)
├── contracts/
│   ├── phase18-reports-table.md
│   ├── phase18-moderation-actions-table.md
│   ├── phase18-reports-policies.md
│   ├── phase18-v-reports-view.md
│   ├── phase18-submit-report-rpc.md
│   ├── phase18-resolve-report-edge-function.md
│   ├── phase18-start-report-review-rpc.md
│   └── phase18-report-ui-and-entry-points.md
└── checklists/
    └── requirements.md         # /speckit-specify quality checklist (committed)
```

### Source Code (repository root)

```text
H:\alnujom-project\
├── lib/
│   ├── core/
│   │   └── routing/
│   │       ├── app_router.dart                                       # UPDATE — add AppRoutes.reports + AppRoutes.adminReports (+ Names) + 2 GoRoutes
│   │       └── auth_redirect.dart                                    # UPDATE — add requireReportsManageRedirect (mirrors requireListingReviewRedirect)
│   ├── features/
│   │   ├── reports/                                                  # CREATE — reporter-facing feature
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   └── supabase_reports_datasource.dart              # CREATE (submit_report RPC, loadMyReports, myReportForListing)
│   │   │   │   ├── models/
│   │   │   │   │   └── report_dto.dart                               # CREATE (v_reports row shape)
│   │   │   │   └── repositories/
│   │   │   │       └── reports_repository_impl.dart                  # CREATE
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── report.dart                                   # CREATE (Report entity)
│   │   │   │   │   ├── report_reason.dart                            # CREATE (ReportReason enum — 8 values)
│   │   │   │   │   └── report_status.dart                            # CREATE (ReportStatus enum — new/reviewing/resolved/dismissed)
│   │   │   │   ├── repositories/
│   │   │   │   │   └── reports_repository.dart                       # CREATE
│   │   │   │   └── usecases/
│   │   │   │       ├── submit_report.dart                            # CREATE
│   │   │   │       ├── load_my_reports.dart                          # CREATE
│   │   │   │       └── load_my_report_for_listing.dart              # CREATE (banner)
│   │   │   └── presentation/
│   │   │       ├── cubit/
│   │   │       │   ├── report_submission_cubit.dart                  # CREATE (sheet submit + anon branch)
│   │   │       │   ├── my_reports_bloc.dart                          # CREATE (paginated list)
│   │   │       │   ├── my_reports_state.dart                         # CREATE
│   │   │       │   └── listing_report_status_cubit.dart             # CREATE (banner per-listing status)
│   │   │       ├── pages/
│   │   │       │   └── my_reports_page.dart                          # CREATE (stub in A; fills in H)
│   │   │       └── widgets/
│   │   │           ├── report_sheet.dart                             # CREATE (reason dropdown + note)
│   │   │           ├── report_status_chip.dart                      # CREATE (localized status pill)
│   │   │           ├── reporter_status_banner.dart                  # CREATE (details-page banner)
│   │   │           └── my_reports_empty_state.dart                  # CREATE
│   │   ├── admin/
│   │   │   ├── reports/                                              # CREATE — admin moderation feature
│   │   │   │   ├── data/
│   │   │   │   │   ├── datasources/
│   │   │   │   │   │   └── supabase_reports_admin_datasource.dart    # CREATE (queue read + resolve Edge Fn call)
│   │   │   │   │   ├── dtos/
│   │   │   │   │   │   └── report_queue_item_dto.dart                # CREATE
│   │   │   │   │   └── repositories/
│   │   │   │   │       └── reports_admin_repository_impl.dart        # CREATE
│   │   │   │   ├── domain/
│   │   │   │   │   ├── entities/
│   │   │   │   │   │   ├── report_queue_item.dart                    # CREATE
│   │   │   │   │   │   ├── moderation_action.dart                    # CREATE
│   │   │   │   │   │   └── moderation_action_type.dart               # CREATE (dismiss/hide/mark_duplicate/delete)
│   │   │   │   │   ├── repositories/
│   │   │   │   │   │   └── reports_admin_repository.dart             # CREATE
│   │   │   │   │   └── usecases/
│   │   │   │   │       ├── load_reports_queue.dart                   # CREATE
│   │   │   │   │       ├── start_report_review.dart                  # CREATE
│   │   │   │   │       └── resolve_report.dart                       # CREATE
│   │   │   │   └── presentation/
│   │   │   │       ├── bloc/
│   │   │   │       │   ├── reports_queue_bloc.dart                   # CREATE (filters + pagination)
│   │   │   │       │   ├── reports_queue_state.dart                  # CREATE
│   │   │   │       │   └── report_resolve_cubit.dart                 # CREATE
│   │   │   │       ├── pages/
│   │   │   │       │   ├── reports_queue_page.dart                   # CREATE (stub in A; fills in I)
│   │   │   │       │   └── report_detail_page.dart                   # CREATE (resolve flow)
│   │   │   │       └── widgets/
│   │   │   │           ├── report_queue_card.dart                    # CREATE
│   │   │   │           ├── report_filter_bar.dart                    # CREATE (status + reason)
│   │   │   │           └── resolve_action_dialog.dart                # CREATE (4 actions + confirm)
│   │   │   └── presentation/pages/
│   │   │       └── admin_home_page.dart                              # UPDATE — add Reports tile (reports.manage)
│   │   ├── listing_details/
│   │   │   └── presentation/
│   │   │       ├── widgets/
│   │   │       │   └── per_listing_action_block.dart                 # UPDATE — Report CTA rewire (Favorite/Share unchanged)
│   │   │       └── pages/
│   │   │           └── listing_details_page.dart                     # UPDATE — host ReporterStatusBanner
│   │   └── profile/
│   │       └── presentation/pages/
│   │           └── profile_page.dart                                 # UPDATE — add "My Reports" ListTile → /reports
│   └── l10n/
│       ├── app_ar.arb                                                # UPDATE — add ~22 Arabic keys
│       └── app_en.arb                                                # UPDATE — add same ~22 English keys
└── supabase/
    ├── migrations/
    │   ├── 20260530120001_create_reports_table.sql                  # CREATE
    │   ├── 20260530120002_create_moderation_actions_table.sql       # CREATE
    │   ├── 20260530120003_create_reports_policies.sql               # CREATE
    │   ├── 20260530120004_create_v_reports_view.sql                 # CREATE
    │   ├── 20260530120005_create_reports_audit_trigger.sql          # CREATE
    │   ├── 20260530120006_create_submit_report_rpc.sql              # CREATE
    │   ├── 20260530120007_create_resolve_report_rpcs.sql            # CREATE (resolve_report_internal + start_report_review)
    │   └── 20260530120008_phase18_advisor_hardening.sql             # CREATE
    ├── functions/
    │   └── resolve_report/
    │       └── index.ts                                             # CREATE (mirrors approve_listing/index.ts)
    └── docs/
        ├── reports.md                                              # CREATE
        └── moderation_actions.md                                   # CREATE
```

**Structure Decision**: Phase 18 adds two new feature folders — `lib/features/reports/` (reporter-facing: sheet, My-Reports, banner) and `lib/features/admin/reports/` (moderation queue + resolve), the latter sitting beside the Phase 12 `lib/features/admin/listing_review/` and mirroring its `data/{datasources,dtos,repositories}` + `domain/{entities,repositories,usecases}` + `presentation/{bloc,pages,widgets}` shape. The shared report value objects (`ReportReason`, `ReportStatus`) live in `lib/features/reports/domain/entities/` and are imported by the admin feature (domain→domain value-object reuse; no Supabase coupling). Four existing files receive minimal entry-point patches (`app_router.dart` two route slots, `auth_redirect.dart` one redirect helper, `admin_home_page.dart` one tile, `profile_page.dart` one tile) plus the two Phase 13 listing-details files (the Report CTA rewire + the banner host). Eight new Supabase migrations land under `supabase/migrations/` (timestamp prefix `20260530`, continuing after Phase 17's `20260529120007`; the IMPLEMENTATION_PLAN's logical names `0027_create_reports.sql` + `0028_create_moderation_actions.sql` map to `20260530120001`/`20260530120002` under the repo's timestamp convention). One Edge Function (`resolve_report`) joins the existing `approve_listing`/`reject_listing` set. ZERO new pubspec dependencies.

---

## Phase Dependencies

> **User-mandated discipline (per /speckit-plan invocation)**: Every "Sub-Phase B depends on Sub-Phase A" line below names the specific file path OR exported symbol that B consumes from A. Lines like "easier in sequence" or "uses concepts from" are FORBIDDEN. The self-audit table at the end counts undeclared-consumer deps (target: zero).

### Sub-Phase A — Bootstrap: routes + redirect helper + shared domain enums + stub pages

**Scope**:

1. `lib/core/routing/app_router.dart`: add `AppRoutes.reports = '/reports'`, `AppRoutes.adminReports = '/admin/reports'`, `AppRouteNames.reports = 'reports'`, `AppRouteNames.adminReports = 'admin-reports'`. Register a top-level `GoRoute(path: AppRoutes.reports, …, redirect: (c, s) => authBloc.state is Unauthenticated ? AppRoutes.login : null, builder: … MyReportsPage())` (mirrors the Phase 17 `/favorites` route at lines 463–469) and a child `GoRoute(path: 'reports', name: AppRouteNames.adminReports, redirect: requireReportsManageRedirect, builder: … ReportsQueuePage())` under the existing `/admin` route (alongside `listing-review/pending` at lines 236–241).
2. `lib/core/routing/auth_redirect.dart`: add `String? requireReportsManageRedirect(BuildContext, GoRouterState)` returning `'/admin?denied=reports'` when `!getIt<PermissionChecker>().has(PermissionKeys.reportsManage)` (mirrors `requireListingReviewRedirect` at lines 112–124).
3. Create `lib/features/reports/domain/entities/report_reason.dart` — `enum ReportReason { fakeListing, wrongPrice, alreadySoldOrRented, duplicate, spam, wrongLocation, inappropriateContent, other }` with a `wireValue` mapping to the eight canonical snake_case strings (`fake_listing` … `other`).
4. Create `lib/features/reports/domain/entities/report_status.dart` — `enum ReportStatus { newReport, reviewing, resolved, dismissed }` with `wireValue` (`new`/`reviewing`/`resolved`/`dismissed`) and `isOpen` getter (`new`||`reviewing`).
5. Create `lib/features/reports/domain/entities/report.dart` — the `Report` entity (`Equatable`): `id`, `listingId`, `reason` (ReportReason), `note` (String?), `status` (ReportStatus), `resolution` (String?), `createdAt`, plus the joined listing card fields the My-Reports page renders.
6. Create stub `lib/features/reports/presentation/pages/my_reports_page.dart` and stub `lib/features/admin/reports/presentation/pages/reports_queue_page.dart` (empty `Scaffold` + `AppBar`) so both routes resolve end-to-end before H/I fill them.

**In-spec deps**: none.

**Cross-phase deps**:

- A's `/reports` redirect reads `authBloc.state is Unauthenticated` where `Unauthenticated` is defined in `lib/features/auth/presentation/bloc/auth_state.dart` (Phase 5) — the exact pattern the Phase 17 `/favorites` route uses in `app_router.dart`.
- A's `requireReportsManageRedirect` consumes `PermissionKeys.reportsManage` (the `'reports.manage'` constant in `lib/core/security/permission_keys.dart`, Phase 6) and `getIt<PermissionChecker>()` from `lib/core/security/permission_checker.dart` (Phase 6).

**Touch fan**: `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart`, `lib/features/reports/domain/entities/report_reason.dart` (CREATE), `lib/features/reports/domain/entities/report_status.dart` (CREATE), `lib/features/reports/domain/entities/report.dart` (CREATE), `lib/features/reports/presentation/pages/my_reports_page.dart` (CREATE stub), `lib/features/admin/reports/presentation/pages/reports_queue_page.dart` (CREATE stub).

---

### Sub-Phase B — Backend schema: `reports` + `moderation_actions` tables

**Scope**:

1. Migration `supabase/migrations/20260530120001_create_reports_table.sql`:
   - Table `public.reports` per FR-008: `id uuid PK DEFAULT gen_random_uuid()`, `listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT`, `reporter_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`, `reason text NOT NULL CHECK (reason IN ('fake_listing','wrong_price','already_sold_or_rented','duplicate','spam','wrong_location','inappropriate_content','other'))`, `note text CHECK (char_length(note) <= 1000)`, `status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewing','resolved','dismissed'))`, `reviewing_by uuid REFERENCES auth.users(id) ON DELETE SET NULL`, `reviewing_started_at timestamptz`, `resolved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL`, `resolved_at timestamptz`, `resolution text`, `metadata jsonb` (optional reporter IP/UA per FR-010(e)), `created_at timestamptz NOT NULL DEFAULT now()`.
   - Indices per FR-011: `CREATE INDEX idx_reports_status_created ON public.reports (status, created_at DESC)` (admin queue); `CREATE INDEX idx_reports_reporter_created ON public.reports (reporter_user_id, created_at DESC)` (My-Reports + banner lookup); partial unique index `CREATE UNIQUE INDEX ux_reports_open_per_reporter_listing ON public.reports (reporter_user_id, listing_id) WHERE status IN ('new','reviewing')` (the open-report dedup of FR-004); `CREATE INDEX idx_reports_listing ON public.reports (listing_id)` (FK + sibling-resolve scan).
   - `ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY` (policies land in Sub-Phase C).
2. Migration `supabase/migrations/20260530120002_create_moderation_actions_table.sql`:
   - Table `public.moderation_actions` per FR-009: `id uuid PK DEFAULT gen_random_uuid()`, `target_type text NOT NULL DEFAULT 'listing' CHECK (target_type IN ('listing'))`, `target_id uuid NOT NULL` (plain column, no FK — append-only audit decoupled from listing lifecycle, R-131), `report_id uuid REFERENCES public.reports(id) ON DELETE SET NULL`, `action text NOT NULL CHECK (action IN ('dismiss','hide','mark_duplicate','delete'))`, `performed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL`, `performed_at timestamptz NOT NULL DEFAULT now()`, `reason text`, `before_state jsonb`, `after_state jsonb`.
   - `CREATE INDEX idx_moderation_actions_target ON public.moderation_actions (target_type, target_id, performed_at DESC)`.
   - `ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY`.
3. Create `supabase/docs/reports.md` + `supabase/docs/moderation_actions.md` documenting columns, the dedup unique index, FK delete behaviors (R-131), and the forward-stated RLS posture (populated by C).

**In-spec deps**: none.

**Cross-phase deps**:

- B's `reports.listing_id` references `public.listings(id)` defined in `supabase/migrations/20260519120002_create_listings.sql` (Phase 10).
- B's `reports.reporter_user_id` / `resolved_by` / `reviewing_by` and `moderation_actions.performed_by` reference `auth.users(id)` (Phase 1 Supabase baseline); the `ON DELETE SET NULL` on `lead_events.user_id` in `supabase/migrations/20260527120002_create_lead_events_table.sql` (Phase 16) is the precedent for the nullable-FK-survives-deletion columns.

**Touch fan**: `supabase/migrations/20260530120001_create_reports_table.sql` (CREATE), `supabase/migrations/20260530120002_create_moderation_actions_table.sql` (CREATE), `supabase/docs/reports.md` (CREATE), `supabase/docs/moderation_actions.md` (CREATE).

---

### Sub-Phase C — Backend policies + `v_reports` view + reports-audit trigger

**Scope**:

1. Migration `supabase/migrations/20260530120003_create_reports_policies.sql`:
   - `reports` SELECT policy `reports_select_self_or_admin`: `USING (reporter_user_id = auth.uid() OR public.current_user_has_permission('reports.manage'))` (FR-025 + FR-026 read matrix).
   - `reports`: NO INSERT/UPDATE/DELETE policy for `authenticated`/`anon`; `REVOKE INSERT, UPDATE, DELETE ON public.reports FROM authenticated, anon` — creation via `submit_report` (D), resolution/claim via the privileged RPCs (E) (FR-025).
   - `moderation_actions` SELECT policy `moderation_actions_select_admin`: `USING (public.current_user_has_permission('reports.manage'))` (FR-026). NO client write; `REVOKE INSERT, UPDATE, DELETE ON public.moderation_actions FROM authenticated, anon`.
2. Migration `supabase/migrations/20260530120004_create_v_reports_view.sql`:
   - View `public.v_reports` declared `WITH (security_invoker = true)` (the Phase 16 `20260527120013` precedent) so the base-table `reports` RLS applies to view reads — a reporter sees only their own rows, a `reports.manage` holder sees all (FR-024 + FR-025).
   - Projection joining `reports r` → `listings l` (+ LATERAL main-image subquery + governorate/city display-name joins, mirroring `v_listings_public` from `20260525120002_create_v_listings_public.sql`): `r.id`, `r.listing_id`, `r.reason`, `r.note`, `r.status`, `r.resolution`, `r.reporter_user_id`, `r.reviewing_by`, `r.resolved_by`, `r.created_at`, `r.resolved_at`, `l.title`, `l.status AS listing_status`, `lm.storage_path AS main_image_path`, `g.display_name->>'ar'/'en'`, `c.display_name->>'ar'/'en'`. The view does NOT filter on `l.status` — reports about non-approved listings still appear in the queue + My-Reports.
   - `GRANT SELECT ON public.v_reports TO authenticated`. NOT granted to `anon`.
3. Migration `supabase/migrations/20260530120005_create_reports_audit_trigger.sql`:
   - `CREATE TRIGGER trg_reports_audit_resolution AFTER UPDATE OF status ON public.reports FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('resolved','dismissed')) EXECUTE FUNCTION log_audit('report.resolved', 'status,resolution,resolved_by', 'id')` — reuses the Phase 4 `log_audit()` trigger function (`20260506120004_create_audit_logs.sql`), which reads `app.current_user_id` set by `resolve_report_internal` (E) for actor attribution and auto-captures before/after (FR-013(e) + Principle VII audit mandate + §6.4 "reports … Audit-logged: Resolution").
4. Update `supabase/docs/reports.md` + `supabase/docs/moderation_actions.md` with the full RLS matrix + the `v_reports` scoping contract + the audit-trigger note.

**In-spec deps**:

- C depends on Sub-Phase B — the `public.reports` and `public.moderation_actions` tables defined in `20260530120001` / `20260530120002` MUST exist before C's policies attach, before `v_reports` selects from `reports`, and before `trg_reports_audit_resolution` attaches to `reports`.

**Cross-phase deps**:

- C's policies call `public.current_user_has_permission(perm_key text)` defined in Phase 6 (`supabase/migrations/20260515120002_create_current_user_has_permission_fn.sql` / the roles-permissions migration set) — the same function the Phase 12 Edge Functions and the `inquiries`/admin policies use.
- C's `v_reports` selects `l.title / l.status` from `public.listings` (Phase 10), `lm.storage_path` from `public.listing_media`, and `g.display_name / c.display_name` from `public.governorates` / `public.cities` (Phase 8) — the same join set `v_listings_public` (`20260525120002`) projects.
- C's audit trigger consumes the `log_audit()` trigger function from `supabase/migrations/20260506120004_create_audit_logs.sql` (Phase 4).

**Touch fan**: `supabase/migrations/20260530120003_create_reports_policies.sql` (CREATE), `supabase/migrations/20260530120004_create_v_reports_view.sql` (CREATE), `supabase/migrations/20260530120005_create_reports_audit_trigger.sql` (CREATE), `supabase/docs/reports.md` (UPDATE), `supabase/docs/moderation_actions.md` (UPDATE).

---

### Sub-Phase D — Backend submit path: `submit_report` RPC

**Scope**:

1. Migration `supabase/migrations/20260530120006_create_submit_report_rpc.sql`:
   - Function `public.submit_report(p_listing_id uuid, p_reason text, p_note text DEFAULT NULL) RETURNS uuid` as `SECURITY DEFINER SET search_path = pg_catalog, public`.
   - Body: (a) `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000'; END IF;` (FR-010(a)); (b) validate `p_reason` ∈ the eight canonical reasons else `RAISE EXCEPTION 'invalid_reason' USING ERRCODE='22023'`; (c) validate `p_listing_id` references an existing listing with `status='approved'` else `'listing_not_found'` (ERRCODE `23503`) / `'listing_not_approved'` (ERRCODE `23514`), mirroring `record_lead_event` (`20260527120010`) per Q6=A (FR-010(b)); (d) open-report dedup per FR-004: `IF EXISTS (SELECT 1 FROM public.reports WHERE reporter_user_id = auth.uid() AND listing_id = p_listing_id AND status IN ('new','reviewing')) THEN RAISE EXCEPTION 'already_reported' USING ERRCODE='23505'; END IF;` (the `ux_reports_open_per_reporter_listing` partial unique index from B is the race-safe backstop); (e) `INSERT INTO public.reports (listing_id, reporter_user_id, reason, note, status, metadata) VALUES (p_listing_id, auth.uid(), p_reason, NULLIF(p_note,''), 'new', jsonb_build_object('ip', inet_client_addr()::text, 'user_agent', current_setting('request.headers', true)::jsonb->>'user-agent')) RETURNING id`; the IP/UA capture (FR-010(e)) is stored in the `reports.metadata` JSONB column, mirroring `record_lead_event`'s `inet_client_addr()` + `request.headers` capture.
   - `REVOKE ALL ON FUNCTION public.submit_report(uuid, text, text) FROM PUBLIC; GRANT EXECUTE … TO authenticated.` NOT granted to `anon` (FR-007).

**In-spec deps**:

- D depends on Sub-Phase B — `submit_report` INSERTs into `public.reports` and its dedup `EXISTS`/unique-index rely on the table + `ux_reports_open_per_reporter_listing` index defined in `20260530120001`.

**Cross-phase deps**:

- D's listing-validity check reads `public.listings.status` (Phase 10, `20260519120002`), reusing the `record_lead_event` (`20260527120010`, Phase 16) approved-listing validation pattern.
- D consumes `auth.uid()` (Supabase Auth standard).

**Touch fan**: `supabase/migrations/20260530120006_create_submit_report_rpc.sql` (CREATE).

---

### Sub-Phase E — Backend resolve path: `resolve_report_internal` + `start_report_review` RPCs + Edge Function + advisor hardening

**Scope**:

1. Migration `supabase/migrations/20260530120007_create_resolve_report_rpcs.sql`:
   - `public.resolve_report_internal(p_report_id uuid, p_actor_user_id uuid, p_action text, p_note text DEFAULT NULL) RETURNS TABLE(report_id uuid, report_status text, listing_id uuid, listing_status text)` as `SECURITY DEFINER SET search_path = public, pg_temp` (the Phase 12 `20260523120005` wrapper convention). Body, all in one transaction: (a) `PERFORM set_config('app.current_user_id', p_actor_user_id::text, true)` (so the listing triggers + the `reports` audit trigger attribute the actor); (b) look up the report, RAISE `report_not_found` if absent, and guard `IF v_report.status NOT IN ('new','reviewing') THEN RAISE EXCEPTION 'already_resolved' USING ERRCODE='23514'; END IF;` (FR-013(a) + SC-015 double-resolve guard); (c) capture `before_state` = the listing's current `(status, title)` jsonb; (d) `UPDATE public.reports SET status = CASE WHEN p_action='dismiss' THEN 'dismissed' ELSE 'resolved' END, resolved_by = p_actor_user_id, resolved_at = now(), resolution = p_action WHERE id = p_report_id`; (e) apply the listing transition per Q1=A — for `hide` `UPDATE public.listings SET status='paused' WHERE id = v_listing_id AND status='approved'`; for `mark_duplicate` `PERFORM set_config('app.current_rejection_reason', 'duplicate', true)` then `UPDATE … SET status='rejected' WHERE … status='approved'`; for `delete` `UPDATE … SET status='deleted' WHERE … status IN ('approved','paused','rejected')`; for `dismiss` no listing UPDATE — these UPDATEs fire the existing `listing_status_transition_trigger_fn` + `listings_audit_trigger_fn`; (f) `INSERT INTO public.moderation_actions (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state) VALUES ('listing', v_listing_id, p_report_id, p_action, p_actor_user_id, p_note, v_before, <after jsonb>)`; (g) sibling auto-resolve per Q5=A — when `p_action <> 'dismiss'`: `UPDATE public.reports SET status='resolved', resolved_by=p_actor_user_id, resolved_at=now(), resolution=p_action WHERE listing_id = v_listing_id AND id <> p_report_id AND status IN ('new','reviewing')` then `INSERT INTO public.moderation_actions (…) SELECT … FROM the just-resolved sibling ids` (each sibling gets its own row referencing this resolution via `reason`).
   - `public.start_report_review(p_report_id uuid) RETURNS void` as `SECURITY DEFINER SET search_path = public, pg_temp` (the Q4=B soft-claim): self-gate `IF NOT public.current_user_has_permission('reports.manage') THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;` then `UPDATE public.reports SET status='reviewing', reviewing_by = auth.uid(), reviewing_started_at = now() WHERE id = p_report_id AND status = 'new'` (advisory: if already `reviewing`, the UPDATE no-ops on the `status='new'` guard — the caller may still resolve; the lock is overridable per FR-036). `GRANT EXECUTE … TO authenticated` (self-gates internally).
   - Grants: `resolve_report_internal` → `service_role` ONLY (`REVOKE ALL FROM PUBLIC, anon, authenticated; GRANT EXECUTE … TO service_role`), exactly like `approve_listing_internal` (`20260523120005`).
2. Edge Function `supabase/functions/resolve_report/index.ts` — a near-copy of `supabase/functions/approve_listing/index.ts`: validate `{ report_id, action, note? }` (UUID + action ∈ {dismiss,hide,mark_duplicate,delete}); `parseJwtSub`; `jwtClient.rpc('current_user_has_permission', { perm_key: 'reports.manage' })` → 403 on false (FR-012); `adminClient.rpc('resolve_report_internal', { p_report_id, p_actor_user_id: jwtSub, p_action, p_note })`; map a null/empty return to `already_resolved`/`report_not_found` 409/404 and success to 200.
3. Migration `supabase/migrations/20260530120008_phase18_advisor_hardening.sql`: safety-net `ALTER FUNCTION … SET search_path` for the three new functions + re-assert the grants (`submit_report`/`start_report_review` → `authenticated`; `resolve_report_internal` → `service_role`) + re-assert `REVOKE INSERT,UPDATE,DELETE ON public.reports, public.moderation_actions FROM authenticated, anon` and `GRANT SELECT ON public.v_reports TO authenticated`, matching the Phase 16/17 advisor-hardening pattern (`20260527120012` / `20260529120005`).

**In-spec deps**:

- E depends on Sub-Phase B — `resolve_report_internal` UPDATEs `public.reports` + INSERTs `public.moderation_actions` (both tables defined in `20260530120001`/`20260530120002`); `start_report_review` UPDATEs `public.reports`.

**Cross-phase deps**:

- E's `resolve_report_internal` reuses the `set_config('app.current_user_id', …)` + `set_config('app.current_rejection_reason', …)` GUC pattern from `supabase/migrations/20260523120005_approve_reject_atomic_wrappers.sql` (Phase 12) so the existing `listing_status_transition_trigger_fn` + `listings_audit_trigger_fn` (`supabase/migrations/20260519120006_create_listing_status_history.sql`, Phase 10/12) fire and write `listing_status_history` + listing `audit_logs` rows.
- E's `resolve_report_internal` UPDATEs `public.listings.status` (Phase 10, `20260519120002`).
- E's `start_report_review` + the Edge Function call `public.current_user_has_permission(...)` (Phase 6).
- E's Edge Function copies the `parseJwtSub` + `current_user_has_permission` gate + `adminClient.rpc(...internal)` structure from `supabase/functions/approve_listing/index.ts` (Phase 12).

**Touch fan**: `supabase/migrations/20260530120007_create_resolve_report_rpcs.sql` (CREATE), `supabase/migrations/20260530120008_phase18_advisor_hardening.sql` (CREATE), `supabase/functions/resolve_report/index.ts` (CREATE).

> **Integration risk (recorded in research R-124)**: the existing `listing_status_transition_trigger_fn` may guard transitions (e.g., only `pending_review→approved`). The moderation transitions (`approved→paused`, `approved→rejected`, `approved→deleted`) MUST be permitted by that guard. Sub-Phase E's first task is to read `20260519120006_create_listing_status_history.sql` and confirm the guard allows admin-driven transitions from `approved`; if it rejects them, `resolve_report_internal` either (a) the guard is amended in `20260530120007` to allow the moderation transitions, or (b) the UPDATE sets status with the GUC and the guard is verified to pass. This is the one place Phase 18 could require touching a Phase 10 trigger — flagged here so the executor verifies before writing the RPC body.

---

### Sub-Phase F — Reporter domain + data layer

**Scope**:

1. `lib/features/reports/domain/repositories/reports_repository.dart` — abstract interface: `Future<Result<Unit, Failure>> submitReport(String listingId, ReportReason reason, String? note)`; `Future<Result<List<Report>, Failure>> loadMyReports({String? cursor, int limit = 30})`; `Future<Result<Report?, Failure>> loadMyReportForListing(String listingId)`.
2. Three use cases at `lib/features/reports/domain/usecases/`: `submit_report.dart`, `load_my_reports.dart`, `load_my_report_for_listing.dart`.
3. `lib/features/reports/data/models/report_dto.dart` mirroring the `v_reports` row shape; `fromJson` + `toEntity()` (maps `reason`/`status` strings to `ReportReason`/`ReportStatus`).
4. `lib/features/reports/data/datasources/supabase_reports_datasource.dart`: `submitReport` → `supabase.rpc('submit_report', params: {'p_listing_id': …, 'p_reason': reason.wireValue, 'p_note': note})`; `loadMyReports` → `supabase.from('v_reports').select().order('created_at', ascending:false)` cursor-paginated (self-RLS returns only the caller's rows); `loadMyReportForListing` → `supabase.from('v_reports').select().eq('listing_id', …).order('created_at',ascending:false).limit(1)`.
5. `lib/features/reports/data/repositories/reports_repository_impl.dart` mapping RPC errors (`auth_required`, `already_reported`, `listing_not_approved`, …) to `Failure`s.
6. Register the 3 use cases + 1 repository + 1 datasource with `@injectable`; regenerate `lib/core/di/injection.config.dart`.

**In-spec deps**:

- F depends on Sub-Phase A — `submitReport`/`loadMyReports` type against `ReportReason` (`lib/features/reports/domain/entities/report_reason.dart`), `ReportStatus` (`…/report_status.dart`), and `Report` (`…/report.dart`) defined by A.
- F depends on Sub-Phase C — `supabase_reports_datasource.dart` issues `select()` against `public.v_reports` (projection defined in `20260530120004` by C) gated by the `reports_select_self_or_admin` policy in `20260530120003` (C).
- F depends on Sub-Phase D — `submitReport()` invokes `public.submit_report(uuid, text, text)` defined in `20260530120006` by D.

**Cross-phase deps**:

- F imports `package:alnujom/core/errors/result.dart` + `failure.dart` (Phase 1) for `Result<T, Failure>`.

**Touch fan**: `lib/features/reports/domain/repositories/reports_repository.dart` (CREATE), `lib/features/reports/domain/usecases/submit_report.dart` (CREATE), `lib/features/reports/domain/usecases/load_my_reports.dart` (CREATE), `lib/features/reports/domain/usecases/load_my_report_for_listing.dart` (CREATE), `lib/features/reports/data/models/report_dto.dart` (CREATE), `lib/features/reports/data/datasources/supabase_reports_datasource.dart` (CREATE), `lib/features/reports/data/repositories/reports_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase G — Admin domain + data layer

**Scope**:

1. `lib/features/admin/reports/domain/entities/moderation_action_type.dart` — `enum ModerationActionType { dismiss, hide, markDuplicate, delete }` with `wireValue`.
2. `lib/features/admin/reports/domain/entities/report_queue_item.dart` — the queue row (`Report` joined fields + reporter id + reviewing_by); `lib/features/admin/reports/domain/entities/moderation_action.dart`.
3. `lib/features/admin/reports/domain/repositories/reports_admin_repository.dart`: `Future<Result<List<ReportQueueItem>, Failure>> loadQueue({ReportStatus? status, ReportReason? reason, String? cursor, int limit = 30})`; `Future<Result<Unit, Failure>> startReview(String reportId)`; `Future<Result<Unit, Failure>> resolve(String reportId, ModerationActionType action, String? note)`.
4. Three use cases at `lib/features/admin/reports/domain/usecases/`: `load_reports_queue.dart`, `start_report_review.dart`, `resolve_report.dart`.
5. `lib/features/admin/reports/data/dtos/report_queue_item_dto.dart` + `lib/features/admin/reports/data/datasources/supabase_reports_admin_datasource.dart`: `loadQueue` → `supabase.from('v_reports').select()` with `.eq('status', …)` / `.eq('reason', …)` filters + cursor (admin RLS returns all rows); `startReview` → `supabase.rpc('start_report_review', params: {'p_report_id': …})`; `resolve` → `supabase.functions.invoke('resolve_report', body: {'report_id': …, 'action': action.wireValue, 'note': note})`.
6. `lib/features/admin/reports/data/repositories/reports_admin_repository_impl.dart`.
7. Register with `@injectable`; regenerate DI config.

**In-spec deps**:

- G depends on Sub-Phase A — `ReportReason` + `ReportStatus` enums (`lib/features/reports/domain/entities/report_reason.dart`, `report_status.dart`) are the filter + status types on `loadQueue` and `ReportQueueItem`.
- G depends on Sub-Phase C — `supabase_reports_admin_datasource.dart` reads `public.v_reports` (defined in `20260530120004` by C; admin sees all rows via the `reports_select_self_or_admin` policy in `20260530120003`) and the `moderation_actions_select_admin` policy (C) governs any moderation-log read.
- G depends on Sub-Phase E — `startReview()` invokes `public.start_report_review(uuid)` and `resolve()` invokes the `resolve_report` Edge Function, both defined in `20260530120007` / `supabase/functions/resolve_report/index.ts` by E.

**Cross-phase deps**:

- G imports `package:alnujom/core/errors/result.dart` + `failure.dart` (Phase 1).
- G's `supabase.functions.invoke('resolve_report', …)` uses the `supabase_flutter` functions client the same way Phase 12's admin datasource invokes `approve_listing`/`reject_listing`.

**Touch fan**: `lib/features/admin/reports/domain/entities/moderation_action_type.dart` (CREATE), `lib/features/admin/reports/domain/entities/report_queue_item.dart` (CREATE), `lib/features/admin/reports/domain/entities/moderation_action.dart` (CREATE), `lib/features/admin/reports/domain/repositories/reports_admin_repository.dart` (CREATE), `lib/features/admin/reports/domain/usecases/load_reports_queue.dart` (CREATE), `lib/features/admin/reports/domain/usecases/start_report_review.dart` (CREATE), `lib/features/admin/reports/domain/usecases/resolve_report.dart` (CREATE), `lib/features/admin/reports/data/dtos/report_queue_item_dto.dart` (CREATE), `lib/features/admin/reports/data/datasources/supabase_reports_admin_datasource.dart` (CREATE), `lib/features/admin/reports/data/repositories/reports_admin_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase H — Reporter presentation + entry wiring (Report CTA, sheet, My Reports, banner, Profile tile)

**Scope**:

1. `report_submission_cubit.dart` (`@injectable`): holds the sheet's reason/note state; `submit()` calls `SubmitReport`, surfaces success / `already_reported` / failure as localized messages; the anonymous branch is handled at the launch site.
2. `report_sheet.dart` — a modal bottom sheet: a `DropdownButtonFormField<ReportReason>` over the eight reasons (labels from J), an optional multiline note `TextField` (≤1000 chars), submit/cancel; reads Phase 2 tokens.
3. `report_status_chip.dart` — a localized status pill mapping `ReportStatus` → label + token color; `my_reports_empty_state.dart` — localized empty-state.
4. `my_reports_bloc.dart` (+ `_state.dart`): `MyReportsOpened`/`Refresh`/`LoadMore`; calls `LoadMyReports` with cursor pagination (FR-022). `my_reports_page.dart` replaces A's stub: `AppBar` (title `l10n.reports_my_title`) + `RefreshIndicator` over a `ListView` of cards (listing image/title + reason + `ReportStatusChip`); empty-state via `MyReportsEmptyState`; tapping a card → `context.push(AppRoutes.listingDetailsFor(item.listingId))`.
5. `listing_report_status_cubit.dart` (`@injectable`) + `reporter_status_banner.dart`: on the details page, the cubit calls `LoadMyReportForListing(listingId)`; if a report exists, the banner renders `l10n.report_banner_status(...)` with the `ReportStatusChip`; renders nothing for non-reporters / signed-out users (FR-023/FR-024).
6. **H1 — Report CTA rewire**: `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` — replace the Report `_ActionButton`'s `_showComingSoon(context, l10n.action_report_coming_soon)` `onPressed` (lines 57–62) with `_onReportTap(context)`: if `getIt<AuthBloc>().state is! Authenticated` (mirroring the Favorite CTA's `_onFavoriteTap` anonymous branch at lines 69–80), show the localized `l10n.report_sign_in_prompt` snackbar + `context.push(AppRoutes.login)`; else `showModalBottomSheet(…, builder: (_) => ReportSheet(listingId: listingId))`. The Favorite + Share CTAs and the row layout are UNCHANGED (FR-034). No new constructor param (`listingId` is already required, line 24).
7. **H2 — Details banner host**: `lib/features/listing_details/presentation/pages/listing_details_page.dart` — mount `ReporterStatusBanner(listingId: id)` near the top of the details body (above or beside the existing action block), wrapped in a `BlocProvider`/`getIt` for `ListingReportStatusCubit`.
8. **H3 — Profile "My Reports" tile**: `lib/features/profile/presentation/pages/profile_page.dart` — insert a `ListTile(leading: Icon(Icons.flag_outlined), title: Text(l10n.profile_reports_tile), trailing: Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.reports))` immediately after the existing "My Favorites" `ListTile` (lines 139–145) and before the sign-out `Divider` (line 146).
9. Register the cubits/blocs; regenerate DI config.

**In-spec deps**:

- H depends on Sub-Phase A — `MyReportsPage` is registered at `AppRoutes.reports` (constant in `app_router.dart` by A); the Profile tile (`AppRoutes.reports`) and report-sheet reason list (`ReportReason` at `lib/features/reports/domain/entities/report_reason.dart`) come from A.
- H depends on Sub-Phase F — `ReportSubmissionCubit` injects `SubmitReport`; `MyReportsBloc` injects `LoadMyReports`; `ListingReportStatusCubit` injects `LoadMyReportForListing` — all at `lib/features/reports/domain/usecases/*.dart` defined by F; pages render `Report` entities.
- H depends on Sub-Phase J — the sheet (reason labels, note hint, submit/cancel), the success/`already_reported` messages, the `report_sign_in_prompt`, the My-Reports title/empty-state/status labels, the `report_banner_status` string, and `profile_reports_tile` are generated from the ARB keys by J.

**Cross-phase deps**:

- H1 imports `lib/features/auth/presentation/bloc/auth_bloc.dart` + `auth_state.dart` (Phase 5) for the `Authenticated` anonymous-branch check (the same import the Favorite CTA path already relies on via `FavoritesCubit.state.isSignedIn`).
- H1/H2 read the listing id already in scope in `per_listing_action_block.dart` (`listingId`, line 24) and `listing_details_page.dart` (`id`, the route param at `app_router.dart` line 408) — no new import.
- H3 imports `package:alnujom/core/routing/app_router.dart` for `AppRoutes.reports` — already imported in `profile_page.dart` (line 7).

**Touch fan**: `lib/features/reports/presentation/cubit/report_submission_cubit.dart` (CREATE), `lib/features/reports/presentation/cubit/my_reports_bloc.dart` (CREATE), `lib/features/reports/presentation/cubit/my_reports_state.dart` (CREATE), `lib/features/reports/presentation/cubit/listing_report_status_cubit.dart` (CREATE), `lib/features/reports/presentation/pages/my_reports_page.dart` (UPDATE — replaces A stub), `lib/features/reports/presentation/widgets/report_sheet.dart` (CREATE), `lib/features/reports/presentation/widgets/report_status_chip.dart` (CREATE), `lib/features/reports/presentation/widgets/reporter_status_banner.dart` (CREATE), `lib/features/reports/presentation/widgets/my_reports_empty_state.dart` (CREATE), `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` (UPDATE — Report CTA rewire only), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — banner host), `lib/features/profile/presentation/pages/profile_page.dart` (UPDATE — My Reports tile), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase I — Admin presentation (queue + resolve flow + admin-home tile)

**Scope**:

1. `reports_queue_bloc.dart` (+ `_state.dart`): `ReportsQueueOpened`/`FilterChanged(status?, reason?)`/`LoadMore`/`Refresh`; calls `LoadReportsQueue` with cursor pagination (FR-020).
2. `reports_queue_page.dart` replaces A's stub: `AppBar` (title `l10n.reports_queue_title`) + `ReportFilterBar` (status + reason dropdowns) + paginated `ListView` of `ReportQueueCard`s (reported listing, reason, reporter, note, `ReportStatusChip`); tapping a card → `report_detail_page.dart`.
3. `report_filter_bar.dart` — status + reason filter dropdowns (reason labels from J, the `reviewing` status selectable per FR-036).
4. `report_queue_card.dart` — one queue row.
5. `report_resolve_cubit.dart` + `report_detail_page.dart` — shows the report + listing context, a "Start review" button (`StartReportReview`, sets `reviewing` + shows current reviewer if claimed — soft lock per FR-036), and the four actions opening `resolve_action_dialog.dart` (the destructive ones require explicit confirmation per FR-017); on confirm calls `ResolveReport`.
6. **I1 — admin-home Reports tile**: `lib/features/admin/presentation/pages/admin_home_page.dart` — add `if (checker.has(PermissionKeys.reportsManage)) ListTile(leading: Icon(Icons.flag_outlined), title: Text(l10n.admin_tile_reports), trailing: Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.adminReports))` to the `tiles` list (mirroring the listing-review tile at lines 30–39).
7. Register the bloc/cubit; regenerate DI config.

**In-spec deps**:

- I depends on Sub-Phase A — `ReportsQueuePage` is registered at `AppRoutes.adminReports` (constant in `app_router.dart`, guarded by `requireReportsManageRedirect` in `auth_redirect.dart`) by A; the admin-home tile's `onTap` pushes `AppRoutes.adminReports` (A).
- I depends on Sub-Phase G — `ReportsQueueBloc` injects `LoadReportsQueue`; `ReportResolveCubit` injects `StartReportReview` + `ResolveReport` — all at `lib/features/admin/reports/domain/usecases/*.dart` defined by G; pages render `ReportQueueItem` + `ModerationActionType` entities (G).
- I depends on Sub-Phase J — the queue title, filter labels, action labels, resolve-confirmation copy, and `admin_tile_reports` are generated from the ARB keys by J.

**Cross-phase deps**:

- I1 consumes `PermissionKeys.reportsManage` (`lib/core/security/permission_keys.dart`, Phase 6) + `getIt<PermissionChecker>()` (the same `checker.has(...)` pattern `admin_home_page.dart` already uses at lines 23/30/47).

**Touch fan**: `lib/features/admin/reports/presentation/bloc/reports_queue_bloc.dart` (CREATE), `lib/features/admin/reports/presentation/bloc/reports_queue_state.dart` (CREATE), `lib/features/admin/reports/presentation/bloc/report_resolve_cubit.dart` (CREATE), `lib/features/admin/reports/presentation/pages/reports_queue_page.dart` (UPDATE — replaces A stub), `lib/features/admin/reports/presentation/pages/report_detail_page.dart` (CREATE), `lib/features/admin/reports/presentation/widgets/report_queue_card.dart` (CREATE), `lib/features/admin/reports/presentation/widgets/report_filter_bar.dart` (CREATE), `lib/features/admin/reports/presentation/widgets/resolve_action_dialog.dart` (CREATE), `lib/features/admin/presentation/pages/admin_home_page.dart` (UPDATE — Reports tile), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase J — Localization: add ~22 bilingual ARB keys

**Scope**: Add the following keys to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb`, then run `flutter gen-l10n`:

- 8 reason labels: `report_reason_fake_listing`, `report_reason_wrong_price`, `report_reason_already_sold_or_rented`, `report_reason_duplicate`, `report_reason_spam`, `report_reason_wrong_location`, `report_reason_inappropriate_content`, `report_reason_other`.
- Report sheet: `report_sheet_title`, `report_reason_field_label`, `report_note_field_hint`, `report_submit_button`, `report_cancel_button`, `report_submitted_success`, `report_already_reported`, `report_sign_in_prompt`, `report_submit_failed`.
- My Reports: `reports_my_title`, `reports_my_empty_state`, `profile_reports_tile`, `report_banner_status` (parameterized by status).
- Status labels: `report_status_new`, `report_status_reviewing`, `report_status_resolved`, `report_status_dismissed`.
- Admin queue + resolve: `admin_tile_reports`, `reports_queue_title`, `report_filter_status_label`, `report_filter_reason_label`, `report_start_review_button`, `report_being_reviewed_by` (parameterized), `resolve_action_dismiss`, `resolve_action_hide`, `resolve_action_mark_duplicate`, `resolve_action_delete`, `resolve_confirm_title`, `resolve_confirm_body`, `report_resolved_success`.

Final count locked at sub-phase implementation time (~22+ keys).

**In-spec deps**: none.

**Cross-phase deps**:

- J runs `flutter gen-l10n` which regenerates `lib/l10n/app_localizations.dart` + `app_localizations_ar.dart` + `app_localizations_en.dart` — consumed by Sub-Phase H (sheet, My-Reports, banner, Report-CTA prompt, Profile tile) and Sub-Phase I (queue, filters, resolve dialog, admin tile).

**Touch fan**: `lib/l10n/app_ar.arb` (UPDATE), `lib/l10n/app_en.arb` (UPDATE), `lib/l10n/app_localizations.dart` (REGENERATED), `lib/l10n/app_localizations_ar.dart` (REGENERATED), `lib/l10n/app_localizations_en.dart` (REGENERATED).

---

### Self-audit — undeclared consumer check

Total declared inter-sub-phase dependency edges: **15**. Every edge names the specific symbol or file path consumed (zero "easier in sequence" / "uses concepts from").

| From | To | Named consumer |
|------|-----|---------------|
| C | B | `public.reports` + `public.moderation_actions` tables in `20260530120001`/`20260530120002` (policies attach; `v_reports` selects `reports`; audit trigger attaches to `reports`) |
| D | B | `public.reports` + `ux_reports_open_per_reporter_listing` index in `20260530120001` (INSERT + dedup) |
| E | B | `public.reports` + `public.moderation_actions` in `20260530120001`/`20260530120002` (resolve UPDATE/INSERT; claim UPDATE) |
| F | A | `ReportReason` / `ReportStatus` / `Report` at `lib/features/reports/domain/entities/{report_reason,report_status,report}.dart` |
| F | C | `public.v_reports` in `20260530120004`; `reports_select_self_or_admin` policy in `20260530120003` |
| F | D | `public.submit_report(uuid,text,text)` in `20260530120006` |
| G | A | `ReportReason` / `ReportStatus` at `lib/features/reports/domain/entities/{report_reason,report_status}.dart` |
| G | C | `public.v_reports` in `20260530120004`; `moderation_actions_select_admin` policy in `20260530120003` |
| G | E | `public.start_report_review(uuid)` in `20260530120007`; `resolve_report` Edge Function at `supabase/functions/resolve_report/index.ts` |
| H | A | `AppRoutes.reports` in `lib/core/routing/app_router.dart`; `ReportReason` at `lib/features/reports/domain/entities/report_reason.dart` |
| H | F | `SubmitReport`, `LoadMyReports`, `LoadMyReportForListing` at `lib/features/reports/domain/usecases/*.dart`; `Report` entity |
| H | J | generated getters in `lib/l10n/app_localizations.dart` (`report_sheet_title`, `report_sign_in_prompt`, `reports_my_title`, `report_banner_status`, `profile_reports_tile`, …) |
| I | A | `AppRoutes.adminReports` in `lib/core/routing/app_router.dart`; `requireReportsManageRedirect` in `lib/core/routing/auth_redirect.dart` |
| I | G | `LoadReportsQueue`, `StartReportReview`, `ResolveReport` at `lib/features/admin/reports/domain/usecases/*.dart`; `ReportQueueItem` + `ModerationActionType` entities |
| I | J | generated getters in `lib/l10n/app_localizations.dart` (`admin_tile_reports`, `reports_queue_title`, `resolve_action_*`, `resolve_confirm_*`, …) |

**Zero deps lack a named consumer.** Cross-phase deps (to Phase 1–17 artifacts) are listed separately under each sub-phase and similarly name the consumed file or symbol. Sub-Phases A, B, and J declare no in-spec predecessor (they are pure roots).

### Wave summary

| Wave | Sub-Phases | Parallelism | Conflict map |
|------|------------|-------------|--------------|
| 1 | A, B, J | 3 in parallel (no inter-deps). A touches `app_router.dart` + `auth_redirect.dart` + new `lib/features/reports/domain/entities/` + the two stub pages. B touches `20260530120001`/`120002` + `supabase/docs/{reports,moderation_actions}.md` (CREATE). J touches `app_{ar,en}.arb` + regenerates `app_localizations*.dart`. No two Wave-1 sub-phases share a file → zero intra-wave conflict. |
| 2 | C, D, E | 3 in parallel (all depend only on B from Wave 1). C touches `120003`/`120004`/`120005` + appends to the two docs. D touches `120006`. E touches `120007`/`120008` + `supabase/functions/resolve_report/index.ts`. The only shared files are the two `supabase/docs/*.md` (C appends — the `/wave` orchestrator sequences C's docs append after B's create). No migration-file overlap. E carries the listing-transition-guard integration check (R-124) — it reads `20260519120006` before writing the RPC body. |
| 3 | F, G | 2 in parallel (F dep A+C+D; G dep A+C+E). F touches new files under `lib/features/reports/{data,domain}/`. G touches new files under `lib/features/admin/reports/{data,domain}/`. Both regenerate `lib/core/di/injection.config.dart` (generated file — no manual merge; the `/wave` orchestrator regenerates once after both land). No source-file overlap. |
| 4 | H, I | 2 in parallel (H dep A+F+J; I dep A+G+J). H touches `lib/features/reports/presentation/` + `per_listing_action_block.dart` + `listing_details_page.dart` + `profile_page.dart`. I touches `lib/features/admin/reports/presentation/` + `admin_home_page.dart`. The six existing-file edits are spread across distinct feature folders with NO overlap between H and I. Both regenerate `injection.config.dart` (generated). |

Total wall-clock parallelism: 3× in Wave 1, 3× in Wave 2, 2× in Wave 3, 2× in Wave 4 — versus a naive sequential 10-step chain. The graph is wide because the two front-end feature areas (reporter vs. admin) are conflict-isolated (different folders + different existing-file edits), and the backend splits cleanly into independent migration files after the tables land.

---

## Research Decisions (R-119..R-134)

See [research.md](research.md) for full per-decision rationale + rejected alternatives.

| ID | Decision area | Locked answer |
|----|--------------|--------------|
| R-119 | New dependencies | NONE — reports/moderation use the inherited Flutter/BLoC/`go_router`/`supabase_flutter` stack + in-house Postgres tables + one Deno Edge Function reusing the Phase 12 runtime (FR-031). |
| R-120 | Two tables | `public.reports` (+ reviewing-claim + resolution columns) and `public.moderation_actions` (append-only), per §6.2 + the Q4=B claim columns. |
| R-121 | Submit posture | `submit_report` SECURITY DEFINER RPC, `authenticated`-only, mirroring `record_lead_event` (auth + approved + IP/UA-capable). |
| R-122 | Open-report dedup | Partial unique index `ux_reports_open_per_reporter_listing (reporter_user_id, listing_id) WHERE status IN ('new','reviewing')` + an `EXISTS` guard in `submit_report` (Q-spec FR-004). |
| R-123 | Resolve posture | `resolve_report` Edge Function (gate `reports.manage`) + service-role-only `resolve_report_internal` RPC reusing the Phase 12 `set_config('app.current_user_id')` GUC wrapper (Principle "checks at both ends"). |
| R-124 | Action → listing status (Q1=A) | `dismiss`=no change, `hide`→`paused`, `mark_duplicate`→`rejected` (`app.current_rejection_reason='duplicate'`), `delete`→`deleted`. Reuse existing enum + Phase 12 transition machinery. **Integration check**: confirm `listing_status_transition_trigger_fn` permits the `approved→{paused,rejected,deleted}` admin transitions before writing the RPC body. |
| R-125 | Sibling auto-resolve (Q5=A) | A listing-affecting action auto-resolves other open reports on the same listing in the same transaction, each with its own `moderation_actions` row; `dismiss` does not. |
| R-126 | Reviewing claim (Q4=B) | `start_report_review` SECURITY DEFINER RPC (self-gates on `reports.manage`) sets `reviewing` + `reviewing_by`; advisory soft lock (overridable). |
| R-127 | Reporter visibility (Q3=Both) | `/reports` "My Reports" page (Profile tile) + reporter-only details banner; both read `v_reports`, self-scoped by RLS. |
| R-128 | `v_reports` shape | `SECURITY INVOKER` view joining `reports`→`listings` projecting queue/My-Reports fields, NOT filtered on listing status; base-table RLS scopes it (reporter own / admin all). |
| R-129 | RLS | `reports` SELECT = reporter-self OR `reports.manage`; no client INSERT/UPDATE/DELETE. `moderation_actions` SELECT = `reports.manage` only; no client write. No `anon`. |
| R-130 | Submit listing gate (Q6=A) | `submit_report` requires the listing exist AND be `approved`. |
| R-131 | FK delete behaviors | `reporter_user_id` NOT NULL `ON DELETE CASCADE`; `resolved_by`/`reviewing_by` `ON DELETE SET NULL`; `moderation_actions.report_id` + `performed_by` `ON DELETE SET NULL`; `moderation_actions.target_id` plain uuid (no FK); `reports.listing_id` `ON DELETE RESTRICT`. The moderation log survives reporter + admin deletion. |
| R-132 | Report sheet UI | Modal bottom sheet: reason dropdown (8) + optional note (≤1000) + submit/cancel; anonymous tap → localized prompt + `/login` (mirrors the Phase 17 Favorite-CTA anonymous branch). |
| R-133 | Migration timestamps | `20260530120001`–`20260530120008` (continuing after Phase 17's `20260529120007`). |
| R-134 | Reports audit | `trg_reports_audit_resolution AFTER UPDATE OF status` reusing the Phase 4 `log_audit()` trigger fn (actor from the `app.current_user_id` GUC set by `resolve_report_internal`); listing transitions additionally fire the existing Phase 10/12 listing audit. |

## Complexity Tracking

*Empty. All 12 Constitution principles pass. No violations require justification.*
