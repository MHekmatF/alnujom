# Tasks — Reports & Moderation

**Feature**: `specs/018-reports-moderation/` | **Branch**: `018-reports-moderation`
**Inputs**: `plan.md` (Sub-Phases A–J + wave plan), `spec.md` (US1–US5, FR-001..FR-036, SC-001..SC-015), `data-model.md` (full SQL + entities), `contracts/` (8), `research.md` (R-119..R-134), `quickstart.md`.

> **Organization**: Phases 1–10 map 1:1 to the plan's Sub-Phases A–J (the dependency nodes the `/wave` orchestrator dispatches). Each task carries a `[US#]` label when it directly implements a user-story behavior; pure infra / backend-foundation / localization tasks carry none (per the speckit Setup/Foundational/Polish convention). `[P]` marks tasks that can run in parallel with their siblings (different files, no unmet intra-phase dep).
>
> **User-story coverage**: US1 (report submission) → Phases 2–6, 8. US2 (admin queue + resolve) → Phases 2–5, 7, 9. US3 (reporter visibility) → Phases 3, 6, 8. US4 (RLS isolation) → Phases 2, 3, 5. US5 (anonymous nudge) → Phase 8.
>
> **No new automated tests** (memory `feedback_no_new_tests.md`): verification is the `quickstart.md` manual recipe (Phase 10/Polish). Existing tests stay.
>
> **Checkbox mandate (read before executing)**: each sub-agent dispatched against this file MUST flip its `- [ ] T<id>` → `- [X] T<id>` **in the same commit** as the implementation for that task. Do NOT defer checkbox-flipping to a cleanup pass.

---

## Phase 1 (Sub-Phase A) — Bootstrap: routes + redirect helper + shared domain enums + stubs

**Goal**: `/reports` + `/admin/reports` resolve end-to-end (to stubs); the shared report value objects exist for both feature folders to type against. No story behavior yet.

- [X] T001 Add route constants to `lib/core/routing/app_router.dart`: `AppRoutes.reports = '/reports'`, `AppRoutes.adminReports = '/admin/reports'`, `AppRouteNames.reports = 'reports'`, `AppRouteNames.adminReports = 'admin-reports'`.
- [X] T002 Add `String? requireReportsManageRedirect(BuildContext, GoRouterState)` to `lib/core/routing/auth_redirect.dart` returning `'/admin?denied=reports'` when `!getIt<PermissionChecker>().has(PermissionKeys.reportsManage)` (mirror `requireListingReviewRedirect`, lines 112–124).
- [X] T003 Register the two routes in `lib/core/routing/app_router.dart`: a top-level `GoRoute(path: AppRoutes.reports, name: AppRouteNames.reports, redirect: (c,s) => authBloc.state is Unauthenticated ? AppRoutes.login : null, builder: … MyReportsPage())` (mirror `/favorites`, lines 463–469) and a child `GoRoute(path: 'reports', name: AppRouteNames.adminReports, redirect: requireReportsManageRedirect, builder: … ReportsQueuePage())` under the `/admin` route. (Depends on T001 + T002; same file as T001.)
- [X] T004 [P] Create `lib/features/reports/domain/entities/report_reason.dart` — `enum ReportReason` with `wireValue` over the 8 canonical reasons + `fromWire` (data-model §2.1).
- [X] T005 [P] Create `lib/features/reports/domain/entities/report_status.dart` — `enum ReportStatus { newReport, reviewing, resolved, dismissed }` with `wireValue`, `isOpen`, `fromWire` (data-model §2.2).
- [X] T006 Create `lib/features/reports/domain/entities/report.dart` — the `Report` `Equatable` entity per data-model §2.3 (imports `ReportReason`/`ReportStatus` from T004/T005).
- [X] T007 [P] Create stub `lib/features/reports/presentation/pages/my_reports_page.dart` (empty `Scaffold` + `AppBar`).
- [X] T008 [P] Create stub `lib/features/admin/reports/presentation/pages/reports_queue_page.dart` (empty `Scaffold` + `AppBar`).

**Checkpoint**: `flutter analyze` clean; `/reports` and `/admin/reports` navigate to stubs (the admin one redirects without `reports.manage`).

---

## Phase 2 (Sub-Phase B) — Backend schema: `reports` + `moderation_actions` tables  [US1, US2, US4]

**Goal**: both tables exist with indices (incl. the open-report dedup index) and RLS enabled.

- [X] T009 [US1] Create migration `supabase/migrations/20260530120001_create_reports_table.sql` — `public.reports` table (incl. the `metadata jsonb` column for FR-010(e) IP/UA capture) + the 4 indices (incl. `ux_reports_open_per_reporter_listing` partial unique) + `ENABLE ROW LEVEL SECURITY`, per data-model §1.1.
- [X] T010 [P] [US2] Create migration `supabase/migrations/20260530120002_create_moderation_actions_table.sql` — `public.moderation_actions` append-only table + `idx_moderation_actions_target` + `ENABLE ROW LEVEL SECURITY`, per data-model §1.2.
- [X] T011 [P] Create `supabase/docs/reports.md` (columns, dedup index, FK delete behaviors R-131, forward-stated RLS).
- [X] T012 [P] Create `supabase/docs/moderation_actions.md` (append-only, FK behaviors, admin-only read).

**Checkpoint**: `apply_migration` 120001+120002 succeed; `list_tables` shows both with RLS on; `get_advisors` clean.

---

## Phase 3 (Sub-Phase C) — Policies + `v_reports` view + reports-audit trigger  [US2, US3, US4]

**Goal**: the reporter-self/admin read matrix, the SECURITY INVOKER view, and the resolution audit trigger are in place.

- [X] T013 [US4] Create migration `supabase/migrations/20260530120003_create_reports_policies.sql` — `reports_select_self_or_admin` SELECT policy + `REVOKE INSERT,UPDATE,DELETE ON public.reports`; `moderation_actions_select_admin` SELECT policy + `REVOKE INSERT,UPDATE,DELETE ON public.moderation_actions`, per data-model §1.3.
- [X] T014 [P] [US3] Create migration `supabase/migrations/20260530120004_create_v_reports_view.sql` — `public.v_reports WITH (security_invoker = true)` joining `reports → listings` (+ main image + governorate/city), NOT filtered on `l.status`; `GRANT SELECT TO authenticated`, per data-model §1.4.
- [X] T015 [P] [US2] Create migration `supabase/migrations/20260530120005_create_reports_audit_trigger.sql` — `trg_reports_audit_resolution AFTER UPDATE OF status` reusing `log_audit('report.resolved','status,resolution,resolved_by','id')`, per data-model §1.5.
- [X] T016 Update `supabase/docs/reports.md` + `supabase/docs/moderation_actions.md` with the full RLS reader/writer matrix (data-model §1.9) + the `v_reports` scoping + audit-trigger notes.

**Checkpoint**: wire-level read-matrix smoke (reporter own-only / admin all / anon zero) per `contracts/phase18-reports-policies.md`.

---

## Phase 4 (Sub-Phase D) — `submit_report` RPC  [US1]

**Goal**: the bypass-proof, authenticated, approved-only, dedup'd report-creation path.

- [X] T017 [US1] Create migration `supabase/migrations/20260530120006_create_submit_report_rpc.sql` — `public.submit_report(p_listing_id uuid, p_reason text, p_note text)` SECURITY DEFINER with the `auth_required` → `invalid_reason` → `listing_not_found`/`listing_not_approved` (Q6=A) → `already_reported` (FR-004) → insert chain (capturing reporter IP/UA into `reports.metadata`, FR-010(e)), per data-model §1.6; `GRANT EXECUTE TO authenticated` only.

**Checkpoint**: `contracts/phase18-submit-report-rpc.md` smoke tests (authenticated insert / anon `auth_required` / non-approved reject / dedup `already_reported`).

---

## Phase 5 (Sub-Phase E) — resolve + claim RPCs + Edge Function + advisor hardening  [US2, US4]

**Goal**: the atomic, dual-layer-gated resolution path; the soft-claim; advisor hardening.

- [X] T018 [US2] **Integration check (R-124)**: read `supabase/migrations/20260519120006_create_listing_status_history.sql` and confirm `listing_status_transition_trigger_fn` permits `approved→{paused,rejected,deleted}` admin transitions. If it rejects them, amend the guard inside migration `20260530120007` (T019) to allow the moderation transitions. Record the finding in a comment header in T019's migration.
- [X] T019 [US2] Create migration `supabase/migrations/20260530120007_create_resolve_report_rpcs.sql` — `public.resolve_report_internal(p_report_id, p_actor_user_id, p_action, p_note)` SECURITY DEFINER (service_role only) per data-model §1.7: `set_config('app.current_user_id')` → open-status guard (`already_resolved`) → report UPDATE → action→listing transition (Q1=A, `mark_duplicate` sets `app.current_rejection_reason='duplicate'`) → `moderation_actions` insert → sibling auto-resolve (Q5=A) → return row. AND `public.start_report_review(p_report_id)` SECURITY DEFINER (authenticated, self-gates on `reports.manage`) per data-model §1.7.
- [X] T020 [US2] Create Edge Function `supabase/functions/resolve_report/index.ts` — a near-copy of `supabase/functions/approve_listing/index.ts`: validate `{report_id, action, note?}` → `parseJwtSub` → `jwtClient.rpc('current_user_has_permission', {perm_key:'reports.manage'})` (403 on false) → `adminClient.rpc('resolve_report_internal', {p_report_id, p_actor_user_id: jwtSub, p_action, p_note})` → map null→`report_not_found`/`already_resolved`, success→200, per `contracts/phase18-resolve-report-edge-function.md`.
- [X] T021 [US4] Create migration `supabase/migrations/20260530120008_phase18_advisor_hardening.sql` — safety-net `ALTER FUNCTION … SET search_path` for the 3 functions + re-assert grants (`submit_report`/`start_report_review`→authenticated; `resolve_report_internal`→service_role) + re-assert `REVOKE …` on both tables + `GRANT SELECT ON v_reports TO authenticated`.

**Checkpoint**: `contracts/phase18-resolve-report-edge-function.md` + `phase18-start-report-review-rpc.md` smoke tests; dual-layer unauthorized-resolve rejection (SC-010); double-resolve guard (SC-015).

---

## Phase 6 (Sub-Phase F) — Reporter domain + data layer  [US1, US3]

**Goal**: the `ReportsRepository` + datasource the reporter UI consumes.

- [X] T022 [US1] Create `lib/features/reports/domain/repositories/reports_repository.dart` — `submitReport`, `loadMyReports`, `loadMyReportForListing` returning `Result<T, Failure>`.
- [X] T023 [P] [US1] Create `lib/features/reports/domain/usecases/submit_report.dart`.
- [X] T024 [P] [US3] Create `lib/features/reports/domain/usecases/load_my_reports.dart`.
- [X] T025 [P] [US3] Create `lib/features/reports/domain/usecases/load_my_report_for_listing.dart`.
- [X] T026 [US1] Create `lib/features/reports/data/models/report_dto.dart` mirroring the `v_reports` row shape; `fromJson` + `toEntity()`.
- [X] T027 [US1] Create `lib/features/reports/data/datasources/supabase_reports_datasource.dart`: `submitReport` → `rpc('submit_report', …)`; `loadMyReports` → `from('v_reports').select().order('created_at',ascending:false)` cursor; `loadMyReportForListing` → `from('v_reports').select().eq('listing_id',…).limit(1)`.
- [X] T028 [US1] Create `lib/features/reports/data/repositories/reports_repository_impl.dart` mapping RPC error codes (`auth_required`, `already_reported`, `listing_not_approved`, …) to `Failure`s.
- [X] T029 Register the 3 use cases + repository + datasource with `@injectable`; run `build_runner` to regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: `flutter analyze` clean; no `package:supabase_flutter` import under `lib/features/reports/domain/`.

---

## Phase 7 (Sub-Phase G) — Admin domain + data layer  [US2]

**Goal**: the `ReportsAdminRepository` + datasource the admin queue/resolve UI consumes.

- [X] T030 [P] [US2] Create `lib/features/admin/reports/domain/entities/moderation_action_type.dart` — `enum ModerationActionType { dismiss, hide, markDuplicate, delete }` + `wireValue` + `isListingAffecting` (data-model §2.4).
- [X] T031 [P] [US2] Create `lib/features/admin/reports/domain/entities/report_queue_item.dart`.
- [X] T032 [P] [US2] Create `lib/features/admin/reports/domain/entities/moderation_action.dart`.
- [X] T033 [US2] Create `lib/features/admin/reports/domain/repositories/reports_admin_repository.dart` — `loadQueue({status?, reason?, cursor?, limit})`, `startReview(reportId)`, `resolve(reportId, action, note?)`.
- [X] T034 [P] [US2] Create `lib/features/admin/reports/domain/usecases/load_reports_queue.dart`.
- [X] T035 [P] [US2] Create `lib/features/admin/reports/domain/usecases/start_report_review.dart`.
- [X] T036 [P] [US2] Create `lib/features/admin/reports/domain/usecases/resolve_report.dart`.
- [X] T037 [US2] Create `lib/features/admin/reports/data/dtos/report_queue_item_dto.dart`.
- [X] T038 [US2] Create `lib/features/admin/reports/data/datasources/supabase_reports_admin_datasource.dart`: `loadQueue` → `from('v_reports').select()` + `.eq('status',…)`/`.eq('reason',…)` + cursor; `startReview` → `rpc('start_report_review', …)`; `resolve` → `functions.invoke('resolve_report', body: {...})`.
- [X] T039 [US2] Create `lib/features/admin/reports/data/repositories/reports_admin_repository_impl.dart`.
- [X] T040 Register the 3 use cases + repository + datasource with `@injectable`; regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: `flutter analyze` clean; admin domain imports the shared `ReportReason`/`ReportStatus` from `lib/features/reports/domain/entities/`; no Supabase import under `domain/`.

---

## Phase 8 (Sub-Phase H) — Reporter presentation + entry wiring  [US1, US3, US5]

**Goal**: the report sheet wired to the Report CTA (with the anonymous nudge), the My-Reports page, and the reporter banner.

- [ ] T041 [US1] Create `lib/features/reports/presentation/cubit/report_submission_cubit.dart` (`@injectable`) — sheet state + `submit()` calling `SubmitReport`, surfacing success / `already_reported` / failure.
- [ ] T042 [US1] Create `lib/features/reports/presentation/widgets/report_sheet.dart` — `DropdownButtonFormField<ReportReason>` (8 reasons) + optional note (≤1000) + submit/cancel; Phase 2 tokens.
- [ ] T043 [P] [US3] Create `lib/features/reports/presentation/widgets/report_status_chip.dart` — localized `ReportStatus` pill.
- [ ] T044 [P] [US3] Create `lib/features/reports/presentation/widgets/my_reports_empty_state.dart`.
- [ ] T045 [US3] Create `lib/features/reports/presentation/cubit/my_reports_bloc.dart` (+ `my_reports_state.dart`) — `Opened`/`Refresh`/`LoadMore` calling `LoadMyReports` (cursor pagination, FR-022).
- [ ] T046 [US3] Replace the Phase-1 stub `lib/features/reports/presentation/pages/my_reports_page.dart` — `AppBar(l10n.reports_my_title)` + `RefreshIndicator` + paginated `ListView` of report cards + empty-state; tap → `AppRoutes.listingDetailsFor(item.listingId)`.
- [ ] T047 [US3] Create `lib/features/reports/presentation/cubit/listing_report_status_cubit.dart` (`@injectable`) — calls `LoadMyReportForListing`.
- [ ] T048 [US3] Create `lib/features/reports/presentation/widgets/reporter_status_banner.dart` — renders `l10n.report_banner_status` + `ReportStatusChip` when a report exists; nothing for non-reporters/anon (FR-023).
- [ ] T049 [US1] [US5] Rewire the Report CTA in `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` — replace the Report `_ActionButton`'s `_showComingSoon(…)` with `_onReportTap`: anon → `l10n.report_sign_in_prompt` snackbar + `context.push(AppRoutes.login)`; signed-in → `showModalBottomSheet(builder: (_) => ReportSheet(listingId: listingId))`. **Favorite + Share CTAs and row layout UNCHANGED** (FR-034).
- [ ] T050 [US3] Host `ReporterStatusBanner(listingId: id)` in `lib/features/listing_details/presentation/pages/listing_details_page.dart` (wrapped with `ListingReportStatusCubit`).
- [ ] T051 [US3] Add the "My Reports" `ListTile(Icons.flag_outlined, l10n.profile_reports_tile, → AppRoutes.reports)` to `lib/features/profile/presentation/pages/profile_page.dart` immediately after the "My Favorites" tile (lines 139–145).
- [ ] T052 Register the cubits/bloc with `@injectable`; regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: SC-001 (submit), SC-007 (My Reports), SC-008 (banner), SC-011 (anon prompt) from `quickstart.md`.

---

## Phase 9 (Sub-Phase I) — Admin presentation + admin-home tile  [US2]

**Goal**: the `reports.manage`-gated queue with filters + pagination, the resolve flow with confirmation, the admin-home tile.

- [X] T053 [US2] Create `lib/features/admin/reports/presentation/bloc/reports_queue_bloc.dart` (+ `reports_queue_state.dart`) — `Opened`/`FilterChanged(status?,reason?)`/`LoadMore`/`Refresh` calling `LoadReportsQueue` (cursor pagination, FR-020).
- [X] T054 [US2] Create `lib/features/admin/reports/presentation/widgets/report_filter_bar.dart` — status + reason dropdowns (`reviewing` selectable, FR-036).
- [X] T055 [P] [US2] Create `lib/features/admin/reports/presentation/widgets/report_queue_card.dart` — listing/reason/reporter/note + `ReportStatusChip`.
- [X] T056 [US2] Replace the Phase-1 stub `lib/features/admin/reports/presentation/pages/reports_queue_page.dart` — `AppBar(l10n.reports_queue_title)` + `ReportFilterBar` + paginated `ListView`; tap → `report_detail_page.dart`.
- [X] T057 [US2] Create `lib/features/admin/reports/presentation/widgets/resolve_action_dialog.dart` — the 4 actions; destructive ones (hide/mark_duplicate/delete) require explicit confirmation (FR-017).
- [X] T058 [US2] Create `lib/features/admin/reports/presentation/bloc/report_resolve_cubit.dart` — `startReview()` (`StartReportReview`) + `resolve(action, note)` (`ResolveReport`).
- [X] T059 [US2] Create `lib/features/admin/reports/presentation/pages/report_detail_page.dart` — report + listing context + "Start review" (soft lock, shows current reviewer) + the 4 actions via `ResolveActionDialog`.
- [X] T060 [US2] Add the Reports tile to `lib/features/admin/presentation/pages/admin_home_page.dart`: `if (checker.has(PermissionKeys.reportsManage)) ListTile(Icons.flag_outlined, l10n.admin_tile_reports, → AppRoutes.adminReports)` (mirror the listing-review tile, lines 30–39).
- [X] T061 Register the bloc/cubit with `@injectable`; regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: SC-003 (gating + queue), SC-004 (4 actions + status map), SC-005 (off public surface), SC-015 (double-resolve) from `quickstart.md`.

---

## Phase 10 (Sub-Phase J) — Localization

**Goal**: all ~22 new strings localized in `ar` + `en`.

- [X] T062 Add the ~22 keys to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` (8 reason labels + sheet/queue/resolve/My-Reports/banner/prompt/status/tile copy), per plan Sub-Phase J. Arabic copy Syrian-friendly.
- [X] T063 Run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations*.dart`.

**Checkpoint**: no inline `Text('...')` literals in the two feature folders; all strings resolve via `AppLocalizations`.

---

## Polish & Cross-Cutting

- [ ] T064 Execute the `quickstart.md` 13-step manual recipe on the Pixel 8 Pro AVD (412 dp) + Infinix Note 8 (480 dp); confirm SC-001..SC-015. Record evidence per memory `feedback_strict_task_completion.md` (partials stay `- [ ]` with `**⚠️ PARTIAL —**`).
- [ ] T065 Run the constitution grep gates (SC-013): zero new pubspec deps; zero hardcoded role branch in `lib/features/reports/` + `lib/features/admin/reports/`; no `package:supabase_flutter` under any `domain/` or `presentation/`; no inline string literals; `lead_events.event_type` + `listings.status` CHECKs unchanged.

---

## Dependencies & user-story completion order

- **US1 (report submission)** is testable after Phases 2 (table), 3 (policies), 4 (submit RPC), 6 (repo/data), 8 (sheet + CTA). MVP slice.
- **US4 (RLS isolation)** is verifiable after Phases 2 + 3 (+ 5 for the resolve gate) — purely backend; no UI needed.
- **US2 (admin queue + resolve)** is testable after Phases 2, 3, 5 (resolve), 7 (admin data), 9 (admin UI).
- **US3 (reporter visibility)** is testable after Phases 3 (view), 6 (data), 8 (My-Reports + banner).
- **US5 (anonymous nudge)** is testable after Phase 8 (the Report-CTA anon branch).

Suggested **MVP** = US1 (submit) + US4 (isolation): Phases 1→2→3→4→6→8 backend-and-reporter slice; the admin resolve loop (US2) and reporter visibility (US3) layer on next.

---

# Multi-Agent Execution (for `/wave all --auto`)

> Phases 1–10 below = Sub-Phases A–J in `plan.md`. The orchestrator executes the Wave Plan directly without re-deriving it.

## Touch-Fan Table

Shared / contended files each phase modifies (the orchestrator warns sub-agents up front and merges least-touch-first):

- **Phase 1 (A)**: `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart` (+ new files under `lib/features/reports/domain/entities/` and the two stub pages — uncontended).
- **Phase 2 (B)**: `supabase/migrations/20260530120001_create_reports_table.sql`, `supabase/migrations/20260530120002_create_moderation_actions_table.sql`, `supabase/docs/reports.md` (CREATE), `supabase/docs/moderation_actions.md` (CREATE).
- **Phase 3 (C)**: `supabase/migrations/20260530120003_create_reports_policies.sql`, `…120004_create_v_reports_view.sql`, `…120005_create_reports_audit_trigger.sql`, `supabase/docs/reports.md` (APPEND), `supabase/docs/moderation_actions.md` (APPEND).
- **Phase 4 (D)**: `supabase/migrations/20260530120006_create_submit_report_rpc.sql`.
- **Phase 5 (E)**: `supabase/migrations/20260530120007_create_resolve_report_rpcs.sql`, `…120008_phase18_advisor_hardening.sql`, `supabase/functions/resolve_report/index.ts`. (The R-124 listing-transition-guard amendment, if T018 finds it necessary, ships **inside** `…120007` — `20260519120006_create_listing_status_history.sql` is never edited in place, so it is NOT a contended file.)
- **Phase 6 (F)**: `lib/core/di/injection.config.dart` (codegen) — all other files are new under `lib/features/reports/{domain,data}/`.
- **Phase 7 (G)**: `lib/core/di/injection.config.dart` (codegen) — all other files are new under `lib/features/admin/reports/{domain,data}/`.
- **Phase 8 (H)**: `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart`, `lib/features/listing_details/presentation/pages/listing_details_page.dart`, `lib/features/profile/presentation/pages/profile_page.dart`, `lib/core/di/injection.config.dart` (codegen).
- **Phase 9 (I)**: `lib/features/admin/presentation/pages/admin_home_page.dart`, `lib/core/di/injection.config.dart` (codegen).
- **Phase 10 (J)**: `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_localizations*.dart` (codegen).

> **Codegen note**: `injection.config.dart` is touched by Phases 6, 7, 8, 9 but is a generated file — the orchestrator regenerates it once after each wave rather than merging it. The only hand-edited shared-file overlaps are within `supabase/docs/*.md` (Phase 2 creates, Phase 3 appends — Wave 1 vs Wave 2, no concurrency) and `app_router.dart` (Phase 1 only).

## Dependency Audit

Every declared dependency, with the specific file/symbol the dependent phase consumes (a dep that cannot name a consumer is false and is omitted):

- **Phase 3 → Phase 2**: T013/T014/T015 attach to / select from the `public.reports` + `public.moderation_actions` tables created in `20260530120001`/`20260530120002` (T009/T010).
- **Phase 4 → Phase 2**: T017's `submit_report` INSERTs into `public.reports` and its dedup relies on `ux_reports_open_per_reporter_listing` (T009).
- **Phase 5 → Phase 2**: T019's `resolve_report_internal` UPDATEs `public.reports` + INSERTs `public.moderation_actions`; `start_report_review` UPDATEs `public.reports` (T009/T010).
- **Phase 6 → Phase 1**: T022/T026/T027 type against `ReportReason`/`ReportStatus`/`Report` at `lib/features/reports/domain/entities/{report_reason,report_status,report}.dart` (T004/T005/T006).
- **Phase 6 → Phase 3**: T027 selects from `public.v_reports` (T014) under the `reports_select_self_or_admin` policy (T013).
- **Phase 6 → Phase 4**: T027's `submitReport` invokes `public.submit_report(uuid,text,text)` (T017).
- **Phase 7 → Phase 1**: T030/T031/T033 use the shared `ReportReason`/`ReportStatus` enums at `lib/features/reports/domain/entities/` (T004/T005).
- **Phase 7 → Phase 3**: T038 reads `public.v_reports` (T014; admin sees all via T013's policy).
- **Phase 7 → Phase 5**: T038's `startReview`/`resolve` invoke `public.start_report_review(uuid)` (T019) + the `resolve_report` Edge Function (T020).
- **Phase 8 → Phase 1**: T046 is registered at `AppRoutes.reports`; T049's sheet uses `ReportReason` (T004); T051's tile pushes `AppRoutes.reports` (T001/T003).
- **Phase 8 → Phase 6**: T041/T045/T047 inject `SubmitReport`/`LoadMyReports`/`LoadMyReportForListing` at `lib/features/reports/domain/usecases/*.dart` (T023/T024/T025); pages render the `Report` entity.
- **Phase 8 → Phase 10**: T042/T046/T048/T049/T051 consume generated getters (`report_sheet_title`, `report_sign_in_prompt`, `reports_my_title`, `report_banner_status`, `profile_reports_tile`) from `lib/l10n/app_localizations.dart` (T062/T063).
- **Phase 9 → Phase 1**: T056 is registered at `AppRoutes.adminReports` (T003) guarded by `requireReportsManageRedirect` (T002); T060's tile pushes `AppRoutes.adminReports` (T001).
- **Phase 9 → Phase 7**: T053/T058 inject `LoadReportsQueue`/`StartReportReview`/`ResolveReport` at `lib/features/admin/reports/domain/usecases/*.dart` (T034/T035/T036); pages render `ReportQueueItem` + `ModerationActionType` (T031/T030).
- **Phase 9 → Phase 10**: T054/T056/T057/T060 consume generated getters (`admin_tile_reports`, `reports_queue_title`, `resolve_action_*`, `resolve_confirm_*`) from `lib/l10n/app_localizations.dart` (T062/T063).

Phases 1, 2, and 10 declare **no** in-spec predecessor (pure roots). **Zero** declared deps lack a named consumer.

## Wave Plan

Topological sort, ≤4 phases per wave (no wave exceeds 3):

- **Wave 1**: Phase 1, Phase 2, Phase 10 — no unmet deps (A bootstrap, B tables, J localization are all roots).
- **Wave 2**: Phase 3, Phase 4, Phase 5 — all deps (Phase 2) satisfied by Wave 1. (Phase 5 also runs the R-124 listing-transition-guard check.)
- **Wave 3**: Phase 6, Phase 7 — deps (Phases 1, 3, 4 / Phases 1, 3, 5) satisfied by Waves 1–2.
- **Wave 4**: Phase 8, Phase 9 — deps (Phases 1, 6, 10 / Phases 1, 7, 10) satisfied by Waves 1–3.
- **Polish**: T064–T065 run after Wave 4 merges (manual QA + grep gates).

Execute via `/wave all --auto`. Per memory `project_wave_worktree_base.md`, brief each worktree sub-agent to `git reset --hard origin/018-reports-moderation` first and verify ancestry before merge.

## Model Routing per Phase

- **Phase 1 (A)**: Sonnet (routing constants + enum scaffolding + stub pages).
- **Phase 2 (B)**: Opus (RLS-enabled tables + the open-report dedup unique-index invariant + FK delete semantics).
- **Phase 3 (C)**: Opus (RLS policies + SECURITY INVOKER view + the reader/writer matrix + audit trigger).
- **Phase 4 (D)**: Opus (SECURITY DEFINER RPC: auth + approved gate + dedup invariant).
- **Phase 5 (E)**: Opus (atomic resolve transaction + state machine + sibling auto-resolve + dual-layer authZ + listing-transition guard).
- **Phase 6 (F)**: Sonnet (repository/DAO CRUD + DTO mapping + RPC wrapper).
- **Phase 7 (G)**: Sonnet (repository/DAO CRUD + Edge-Function-invoke wrapper).
- **Phase 8 (H)**: Sonnet (widgets + cubits + entry-point wiring).
- **Phase 9 (I)**: Sonnet (admin queue widgets + resolve dialog + tile).
- **Phase 10 (J)**: Sonnet (l10n + codegen).

> Rationale: the four backend phases (2–5) carry the RLS / SECURITY DEFINER / atomic-transaction / state-machine invariants the heuristic routes to Opus; everything else (scaffolding, repos, widgets, l10n) is Sonnet.

---

## Reminder — checkbox discipline

Each sub-agent flips its `- [ ] T<id>` → `- [X] T<id>` in the SAME commit as the task's implementation. No deferred cleanup pass.
