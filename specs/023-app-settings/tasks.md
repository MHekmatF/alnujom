# Tasks: App Settings (Phase 23)

**Input**: Design documents from `specs/023-app-settings/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: NO new automated tests (project MVP convention — memory `feedback_no_new_tests`). Verification is manual on-device (two-device for maintenance) + SQL/RPC wire-level checks, recorded against the Success Criteria. Acceptance tasks below are verification steps, not test code.

**Organization**: Tasks are grouped by the plan's **four implementation phases** (PB, FD, FA, FC) — the units `/wave` dispatches — with `[US#]` labels mapping each task to the spec's user stories for traceability. Waves: **PB ∥ FD** (Wave 1) → **FA ∥ FC** (Wave 2) → **Polish** (Wave 3).

## Format: `[ID] [P?] [US?] Description with file path`

- **[P]**: Can run in parallel (different file, no dependency on an incomplete task)
- **[US#]**: The user story this task serves (PB/FD are foundational — no story label, like the template's Foundational phase)
- All paths are repository-relative.

> **⚠️ Checkbox discipline (memory `feedback_strict_task_completion` + `docs/AI_AGENT_WORKFLOW.md`)**: each sub-agent MUST flip its `- [ ] T<id>` → `- [X] T<id>` **in the same commit as the implementation** — never as a later "cleanup pass." A verification/acceptance task stays `- [ ]` (or `- [ ] **⚠️ PARTIAL —**`) until the check is actually run on the target device and the outcome recorded; do not flip it by inference.

> **No separate Setup/Foundational phase**: the project is established (deps, DI, theme, l10n, router all exist). PB (backend) and FD (Flutter domain+data) ARE the foundation and run in parallel as Wave 1. Phase 23 adds **no new dependency**.

---

## Phase PB — Backend: `app_settings` table, RPC, audit, seed (foundational; serves US1/US2/US5) — Wave 1

**Goal**: The `app_settings` store + the `set_app_setting` definer write path + audit + seed, all checked in and applied.
**Independent Test**: `SELECT key, is_public FROM app_settings ORDER BY key` → 8 public keys; a non-`settings.manage` `rpc('set_app_setting',…)` → `42501`; a successful change leaves an `audit_logs` row.

- [X] T001 Create migration `supabase/migrations/20260602120014_create_app_settings.sql` — `app_settings` table (key PK, value JSONB, description, `is_public` BOOL default true, updated_by FK, updated_at), `ENABLE ROW LEVEL SECURITY`, `GRANT SELECT TO anon, authenticated`, SELECT policy `USING (is_public OR public.current_user_has_permission('settings.manage'))`, `REVOKE INSERT,UPDATE,DELETE … FROM anon, authenticated`, and the `set_updated_at()` BEFORE-UPDATE trigger (per data-model §1.1)
- [X] T002 Create migration `supabase/migrations/20260602120015_create_set_app_setting_rpc.sql` — `set_app_setting(p_key TEXT, p_value JSONB)` SECURITY DEFINER (`search_path = public, auth`) that re-checks `settings.manage` (raise `42501`), UPDATEs the row stamping `updated_by`/`updated_at`, raises `P0002` on unknown key, RETURNS the row; `REVOKE EXECUTE FROM anon, PUBLIC; GRANT EXECUTE TO authenticated`; plus `CREATE TRIGGER trg_app_settings_audit AFTER UPDATE … EXECUTE FUNCTION log_audit('settings.updated','value','key')` (per data-model §1.2)
- [X] T003 [P] Create migration `supabase/migrations/20260602120016_seed_app_settings.sql` — idempotent `INSERT … ON CONFLICT (key) DO NOTHING` for the 8 catalog keys with their default values + `is_public=true` (per data-model §1.3); **no `supported_currencies` key**
- [X] T004 [P] Create migration `supabase/migrations/20260602120017_app_settings_advisor_hardening.sql` — `REVOKE ALL … FROM PUBLIC; GRANT SELECT TO anon, authenticated; REVOKE EXECUTE ON set_app_setting FROM PUBLIC; COMMENT ON TABLE …` (per data-model §1.4)
- [X] T005 [P] Create `supabase/policies/app_settings_policies.sql` (checked-in policy mirror) and `supabase/docs/app_settings.md` (per-table notes: RLS posture, 8-key catalog, value shapes, gotchas)
- [X] T006 Apply migrations `…014`→`…015`→`…016`→`…017` in order via Supabase MCP (`project_supabase_apply_via_mcp`); run `get_advisors` (expect no new SECURITY DEFINER search_path / RLS findings); verify `SELECT key, is_public FROM app_settings` returns the 8 public keys — **acceptance: applied …014–…017 + added …018 FK index; 8 public keys confirmed (no `supported_currencies`); RLS on, 1 SELECT policy, client INSERT/UPDATE/DELETE absent for anon+authenticated, `set_app_setting` definer w/ `search_path=public, auth`, anon EXECUTE revoked; advisors → only the intentional definer-executable WARN (matches all 52 project RPCs, anon excluded) + FK-index INFO now cleared by …018; no new search_path/RLS findings.**

**Checkpoint**: backend live; the FD datasource's runtime contract (`set_app_setting`, `app_settings`) is satisfiable.

---

## Phase FD — Flutter settings domain + data + DI (foundational; serves all US) — Wave 1

**Goal**: The Supabase-free `AppSettingsRepository` + entities + use cases + datasource — the symbol set FA & FC import. Compiles + analyzes **without** the DB applied.
**Independent Test**: `flutter analyze` clean; `getIt<AppSettingsRepository>()` resolves; a unit-free smoke (manual) of `LoadPublicSettings` against the live DB returns the snapshot.

- [X] T007 [P] Create domain entities in `lib/features/settings/domain/entities/`: `app_setting.dart` (`AppSetting`), `app_setting_key.dart` (`AppSettingKey` enum + wire `key`), `app_settings.dart` (`AppSettings` aggregate + typed getters + `const AppSettings.safeDefaults()`), `maintenance_state.dart` (`MaintenanceState`), `support_contact.dart` (`SupportContact` + `hasAny`), `localized_text.dart` (`LocalizedText` + `forLocale`)
- [X] T008 [P] Create abstract `AppSettingsRepository` in `lib/features/settings/domain/repositories/app_settings_repository.dart` (`loadPublicSettings`, `loadAllSettings`, `updateSetting` → all `Future<Result<…>>`)
- [X] T009 Create use cases in `lib/features/settings/domain/usecases/`: `load_public_settings.dart`, `load_all_settings.dart`, `update_setting.dart` (depends on T008)
- [X] T010 [P] Create `AppSettingDto` (+ per-key value decoders) in `lib/features/settings/data/dtos/app_setting_dto.dart`
- [X] T011 Create `SupabaseAppSettingsDatasource` in `lib/features/settings/data/datasources/supabase_app_settings_datasource.dart` — `_client.from('app_settings').select()` for reads, `_client.rpc('set_app_setting', params: {'p_key':…, 'p_value':…})` for writes (depends on T010; matches the Phase 9 currencies-datasource idiom)
- [X] T012 Create `AppSettingsRepositoryImpl` `@LazySingleton(as: AppSettingsRepository)` in `lib/features/settings/data/repositories/app_settings_repository_impl.dart` — DTO↔entity, exception→`Failure`, `Result<T>` (depends on T008, T011)
- [X] T013 Run `dart run build_runner build --delete-conflicting-outputs`; `flutter analyze` clean; confirm no `package:supabase_flutter` import under `lib/features/settings/domain/` — **acceptance (record outcome)**: build_runner SUCCESS (57s, 245 outputs); `flutter analyze --fatal-infos` → No issues found; domain-purity grep → zero matches.

**Checkpoint**: FD symbols exist; FA & FC can compile against them.

---

## Phase FA — Admin typed editor + dashboard tile + `/admin/settings` route + l10n (serves US1, US6) — Wave 2

**Goal**: A `settings.manage`-gated typed editor reachable from the dashboard Settings tile; every save audited.
**Independent Test**: A super-admin opens Dashboard → Settings → editor; changing a setting persists + audits; a non-`settings.manage` user can't reach it.

- [X] T014 [P] [US1] Create `AppSettingsEditorCubit` in `lib/features/settings/admin/presentation/bloc/app_settings_editor_cubit.dart` — load via `LoadAllSettings`, edit-in-place, per-type validation, save via `UpdateSetting`
- [X] T015 [P] [US6] Add editor l10n keys (labels, descriptions, validation messages, save/confirm) to `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` + matching `_DebugAppLocalizations` overrides in `lib/core/localization/app_strings.dart`; run `flutter gen-l10n`
- [X] T016 [US1] Create `AppSettingsEditorPage` + typed control widgets in `lib/features/settings/admin/presentation/{pages,widgets}/` — toggle (`maintenance_mode.on`), pickers (`default_language` ar/en, `default_currency` via the pre-existing `ListCurrencies(activeOnly: true)`, the two visibility defaults), validated-text rows (`support_contact.phone/whatsapp/email`, `terms_url`, `privacy_url`, bilingual `maintenance_mode.message`) (depends on T014, T015)
- [X] T017 [US1] Register the route in `lib/core/routing/app_router.dart` — add `AppRoutes.adminSettings = '/admin/settings'` + `AppRouteNames.adminSettings` + a `GoRoute` in the authenticated/admin branch of `buildAppRouter()` (depends on T016)
- [X] T018 [US1] Flip the Settings tile in `lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart` from `DashboardSectionState.comingSoon` to active with the `/admin/settings` target (still gated by `PermissionKeys.settingsManage`) (depends on T017)
- [ ] **⚠️ PARTIAL —** T019 [US1] Run `build_runner` (DI) + `flutter analyze`; verify on-device the tile opens the editor for a `settings.manage` user and is hidden/absent otherwise — **acceptance (record outcome)** — analyze clean + build_runner ok; on-device tile→editor + permission-hide walk deferred to Wave 3 QA.

**Checkpoint**: US1 functional — admins can read/write settings; changes audited.

---

## Phase FC — Maintenance gate + app-load/resume fetch + registration seeding + about (serves US2, US3, US4, US6) — Wave 2

**Goal**: The app consumes public settings, gates on maintenance (with `settings.manage` bypass), seeds new users, and surfaces support/terms — fail-open on fetch error.
**Independent Test**: Toggle maintenance on a 2nd device → screen appears on next foreground; `settings.manage` user bypasses; offline launch runs on safe defaults (not maintenance); a new account is seeded with the default language/currency.

- [X] T020 [P] [US4] Create `AppSettingsCubit` in `lib/features/settings/presentation/bloc/app_settings_cubit.dart` — `load()` (via `LoadPublicSettings`) at start + on resume; expose `AppSettings current` + `bool get maintenanceActive`; serve `AppSettings.safeDefaults()` on load failure (FR-014, fail-open / fail-safe)
- [X] T021 [P] [US2] Create `MaintenanceScreen` in `lib/features/settings/presentation/pages/maintenance_screen.dart` — localized title + active-locale custom message (`LocalizedText.forLocale`, built-in fallback) + `SupportContact` affordances + a **retry** that re-invokes `AppSettingsCubit.load()`
- [X] T022 [P] [US4] Create `AboutSupportPage`/section in `lib/features/settings/presentation/pages/about_support_page.dart` + `widgets/support_contact_row.dart` — render set `support_contact` channels + `terms_url`/`privacy_url`, omitting unset ones (no broken link)
- [X] T023 [P] [US6] Add maintenance + about l10n keys to `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` + matching `_DebugAppLocalizations` overrides in `lib/core/localization/app_strings.dart`; run `flutter gen-l10n`
- [X] T024 [US2] Create `lib/features/settings/presentation/widgets/maintenance_gate.dart` and compose it into the **existing global `redirect`** in `lib/core/routing/app_router.dart` — redirect to `MaintenanceScreen` when `maintenanceActive` UNLESS `getIt<PermissionChecker>().has(PermissionKeys.settingsManage)` (the only bypass) (depends on T020, T021)
- [X] T025 [US4] Provide `AppSettingsCubit` above the router in `lib/app.dart` + trigger the initial `load()` and a `WidgetsBindingObserver` / `AppLifecycleState.resumed` re-load (depends on T020)
- [X] T026 [US3] Amend the post-sign-in seeding block in `lib/features/auth/data/repositories/auth_repository_impl.dart` (currently `_profileRepository.updateLocale(deviceLocale)` at ~L94) to seed the new user's `locale` from `default_language` via `ProfileRepository.updateLocale(...)` AND `display_currency` from `default_currency` via the **Phase 9** `CurrenciesRepository.writeUserDisplayCurrency(code)` (`lib/features/currencies/domain/repositories/currencies_repository.dart`), both read from `LoadPublicSettings()` (FR-007, forward-only; depends on FD T009)
- [X] T027 [US3] Pre-select a **new** listing's `contact_name_visibility` / `location_visibility` from the `AppSettings` defaults in the new-listing initial state in `lib/features/listing_form/presentation/bloc/listing_form_bloc.dart` (consuming the `ListingVisibility` entity in `lib/features/listing_form/domain/entities/listing_visibility.dart`; existing listings untouched — FR-008)
- [ ] T028 **⚠️ PARTIAL —** analyze clean + build_runner ok; two-device maintenance/bypass/offline-fail-open walk deferred to Wave 3 QA [US2] Run `build_runner` (DI) + `flutter analyze`; verify on a second device the maintenance toggle, the `settings.manage` bypass matrix, and the offline fail-open (not maintenance, no crash) — **acceptance (record outcome)**

**Checkpoint**: US2/US3/US4 functional — maintenance gate, defaults seeding, support surface all live.

---

## Phase Polish — Cross-cutting verification (serves US5, US6) — Wave 3

- [X] T029 [US5] Run the wire-level security checks (quickstart steps 13–14): non-`settings.manage` `set_app_setting` → `42501`; direct `UPDATE app_settings` denied; anon reads public keys; a temp `is_public=false` key is hidden from anon/non-admin then removed — **acceptance: ALL PASS via Supabase MCP (SET LOCAL ROLE). (1) anon SELECT → 8 public keys; (2) `terms_url` flipped `is_public=false` → anon sees 7, hidden key absent (rolled back); (3) `SET ROLE authenticated; UPDATE app_settings` → `42501 permission denied for table`; (4) `SET ROLE authenticated; set_app_setting(...)` → `42501 permission denied: settings.manage required`. ⚠️ Found+fixed a real RLS bug: the original single PUBLIC-scoped SELECT policy referenced `current_user_has_permission` (anon lacks EXECUTE → anon read failed `42501`); fixed in migration `…019` by splitting into a function-free public-read + an authenticated-scoped admin-read.**
- [ ] T030 [P] [US6] Run the four-combination render check (quickstart step 16) for the editor + `MaintenanceScreen` + about on the Infinix Note 8 + a 412 dp AVD (light/dark × ar/en) — **⚠️ PARTIAL —** on-device render walk deferred to QA; not runnable from the orchestrator. Editor/maintenance/about are themed via Phase 2 tokens + bilingual ARBs (l10n-parity passed, 870 keys); the four-combination visual check itself is unrun.
- [X] T031 [P] Run the full verify suite (`flutter analyze` + format + design-tokens + l10n-parity + l10n-literals + SDK-boundary — memory `project_wave_run_full_verify_suite`) + the structural gate (quickstart step 18: one new table, no new permission key, no `supported_currencies`, no Supabase import in `domain/`, no iOS/Web, no new dependency, **and no Realtime channel subscribes to `app_settings`** — FR-012) — **acceptance: structural gate ALL PASS (1 new table `app_settings`; 0 new permission keys; `supported_currencies` only in doc/comment noting its absence; 0 supabase in `domain/`; 0 iOS/Web/desktop changes; pubspec unchanged → 0 new deps; `app_settings` in no Realtime subscription/publication). Verify suite: `flutter analyze --fatal-infos` clean; l10n-parity pass (870 keys); SDK-boundary clean. Phase 23 introduces ZERO design-token/l10n-literal/format violations (fixed the one FA `settingsEditorSaveError` literal; formatted all Phase 23 files). PRE-EXISTING Phase 13–21 debt remains repo-wide (3 design-token + 9 l10n-literal + ~65 dart-format) from the 2026-05-22 CI pause — NOT Phase 23, out of scope; logged here for a future cleanup spec.**
- [ ] T032 Run the remaining quickstart steps (SC-001/004/005/009) two-device and update `supabase/docs/app_settings.md` / spec / plan if reality diverged (Principle X) — **⚠️ PARTIAL —** docs reconciled to reality: `supabase/docs/app_settings.md` + `supabase/policies/app_settings_policies.sql` updated for the `…019` two-policy split (Principle X divergence captured). Audit infra confirmed live (`trg_app_settings_audit` + `set_app_setting` deny path wire-tested in T029). The two-device behavioural walks (SC-001 editor persistence+audit row, SC-004/005 forward-only seeding/defaults, SC-009 surfaced support/terms) are on-device — deferred to QA.

---

## Dependencies & Execution Order

### Phase dependencies
- **PB** and **FD** have no dependency on each other → **Wave 1 (parallel)**. (FD's calls to `set_app_setting` / `app_settings` are string-keyed runtime/DB contracts — FD compiles without PB applied.)
- **FA** and **FC** each depend on **FD** (named symbols below) but not on each other → **Wave 2 (parallel)**, after FD merges.
- **Polish** depends on FA + FC merged and PB applied → **Wave 3**.

### Within-phase ordering
- PB: T001 → {T002}; T003/T004/T005 [P]; T006 (apply) after T001–T004.
- FD: T007/T008/T010 [P]; T009 after T008; T011 after T010; T012 after T008+T011; T013 after T012.
- FA: T014/T015 [P]; T016 after T014+T015; T017 after T016; T018 after T017; T019 last.
- FC: T020/T021/T022/T023 [P]; T024 after T020+T021; T025 after T020; T026 after FD T009; T027 after T020; T028 last.

### Build edges (Dart symbols — see Dependency Audit below)
- FA → FD; FC → FD. (PB ↔ FD, FA ↔ FC: none.)

---

## Parallel Example

```text
# Wave 1 — dispatch PB and FD together (no shared Dart symbol):
Agent A (PB): T001–T006  (SQL migrations + apply)
Agent B (FD): T007–T013  (Flutter domain + data + DI)

# Wave 2 — after FD merges, dispatch FA and FC together (both import FD, not each other):
Agent C (FA): T014–T019  (admin editor + tile + route)
Agent D (FC): T020–T028  (maintenance gate + fetch + seeding + about)

# Within FD, launch the independent creators in parallel:
T007 entities  ‖  T008 repository interface  ‖  T010 DTO
```

---

## Implementation Strategy

### MVP scope
US1 (admin editor) + US2 (maintenance mode) are the two P1 stories — the demonstrable core (the plan's two acceptance criteria). MVP = PB + FD + FA (US1) + the FC maintenance slice (US2). US3/US4 (defaults seeding, about) and US5/US6 (enforcement, l10n/theming) layer on.

### Incremental delivery
1. Wave 1 (PB ‖ FD) → backend + Flutter foundation ready.
2. Wave 2 (FA ‖ FC) → US1 (editor) + US2/US3/US4 (gate, seeding, about).
3. Wave 3 (Polish) → US5 (wire-level enforcement) + US6 (four-combination) + full verify + quickstart.

---

# Multi-Agent Execution Plan

## Touch-Fan Table

Shared / contention-prone files each phase modifies (the `/wave` orchestrator uses this to warn sub-agents up front and to pick merge order least-touch-first). New, phase-private files are omitted.

- **PB**: `supabase/migrations/20260602120014_create_app_settings.sql`, `…015_create_set_app_setting_rpc.sql`, `…016_seed_app_settings.sql`, `…017_app_settings_advisor_hardening.sql`, `supabase/policies/app_settings_policies.sql`, `supabase/docs/app_settings.md` — **all new; ZERO shared-file contention** with any other phase.
- **FD**: `lib/core/di/injection.config.dart` (codegen) — the only shared file.
- **FA**: `lib/core/routing/app_router.dart`, `lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart`, `lib/l10n/app_localizations*.dart` (gen), `lib/core/di/injection.config.dart` (codegen).
- **FC**: `lib/core/routing/app_router.dart`, `lib/app.dart`, `lib/features/auth/data/repositories/auth_repository_impl.dart`, `lib/features/listing_form/**` (new-listing default pre-selection), `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart`, `lib/l10n/app_localizations*.dart` (gen), `lib/core/di/injection.config.dart` (codegen).
- **Polish**: none (verification only; may touch `supabase/docs/app_settings.md`, spec/plan on drift).

**Contention set (FA ∩ FC)**: `lib/core/routing/app_router.dart` (disjoint regions — FA adds a route, FC adds a redirect branch), `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart`, `lib/core/di/injection.config.dart`. **Merge least-touch-first → FD (1 shared) → FA → FC**: the second of FA/FC rebases, union-merges the ARBs + `app_strings.dart`, re-applies its disjoint `app_router.dart` edit, regenerates `injection.config.dart` (`build_runner`), and re-runs l10n-parity + the `_DebugAppLocalizations` override gate. **PB merges anytime** (zero contention) but must be APPLIED before Wave-3 live verification.

## Dependency Audit

Re-read of plan.md §"Phase Dependencies". Every declared edge names a concrete consumer:

- **FA → FD** — `lib/features/settings/admin/presentation/bloc/app_settings_editor_cubit.dart` imports the abstract `AppSettingsRepository` and the use cases `LoadAllSettings` + `UpdateSetting`; `app_settings_editor_page.dart` imports the `AppSettingKey` enum + `SupportContact` / `LocalizedText` / `MaintenanceState` entities — all from `lib/features/settings/domain/` (FD). **Real.**
- **FC → FD** — `lib/features/settings/presentation/bloc/app_settings_cubit.dart` imports `AppSettingsRepository` + `LoadPublicSettings` + the `AppSettings` / `MaintenanceState` / `SupportContact` entities; `maintenance_gate.dart` consumes the `AppSettings.maintenance` getter; the `auth_repository_impl.dart` amendment imports `LoadPublicSettings` — all from `lib/features/settings/domain/` (FD). **Real.**

Edges checked and **NOT** declared (would be false / pessimistic):
- **FD → PB**: none. FD calls `set_app_setting` / selects `app_settings` by **string name** (`_client.rpc('set_app_setting',…)`), not a Dart import — runtime/DB contract; FD compiles without PB. Removing this as a build edge keeps PB and FD in the same wave.
- **FA → PB / FC → PB**: none — no Dart symbol from PB.
- **FA ↔ FC**: none — FA builds `settings/admin/**` + edits `dashboard_sections.dart` + adds a route; FC builds `settings/presentation/**` + edits the global redirect + `auth_repository_impl.dart`. Their shared edits to `app_router.dart`/ARBs/`app_strings.dart` are **merge-contention**, not symbol imports — handled by merge order, not a wave edge.

**False deps removed: 0** (the graph was already minimal at plan time — 2 edges, both named). **Unnamed deps: 0.**

## Wave Plan

Topological sort of {PB, FD, FA, FC, Polish} over the audited edges (FA→FD, FC→FD, Polish→{FA,FC,PB}):

- **Wave 1**: **PB, FD** — no unmet deps. (2 phases ≤ 4 ✓)
- **Wave 2**: **FA, FC** — both deps (FD) satisfied by Wave 1. (2 phases ≤ 4 ✓)
- **Wave 3**: **Polish** — FA + FC merged and PB applied. (1 phase ≤ 4 ✓)

Run via `/wave all --auto`. No wave exceeds the cap of 4; no tests-only exception needed.

## Model Routing per Phase

- **PB: Opus** — RLS policy + SECURITY DEFINER `set_app_setting` (server-side permission boundary) + audit trigger; a security boundary where checks-at-both-ends correctness matters.
- **FD: Sonnet** — domain entities + DAO/datasource + repository scaffolding + DI; no invariants beyond mapping.
- **FA: Sonnet** — typed editor widgets + l10n + route/tile wiring; standard UI/CRUD.
- **FC: Opus** — the maintenance gate carries real invariants (the `settings.manage`-only bypass must never lock the operator out; a failed fetch must be fail-open, never maintenance-on) plus the forward-only registration seeding; correctness-critical guard logic.
- **Polish: Sonnet** — verification runs + docs reconciliation.

`Phase PB: Opus (RLS + definer RPC + audit). Phase FD: Sonnet (domain + data scaffolding). Phase FA: Sonnet (typed editor + l10n). Phase FC: Opus (maintenance-gate invariants + fail-safe + forward-only seeding). Phase Polish: Sonnet (verification + docs).`

---

## Notes

- `[P]` = different file, no dependency on an incomplete task.
- `[US#]` maps a task to its spec user story; PB/FD are foundational (no label).
- **Flip checkboxes in the same commit as the code** — never defer to a cleanup pass; acceptance/verification tasks stay unchecked (or `**⚠️ PARTIAL —**`) until actually run on-device and recorded (memory `feedback_strict_task_completion`).
- Run every `flutter run`/`build` with `--dart-define-from-file=.env.json` (memory `project_dart_defines`).
- `/wave` sub-agents: `git reset --hard origin/023-app-settings` first, verify ancestry before merge, re-anchor orchestrator CWD to repo root before each merge (memories `project_wave_worktree_base`, `project_wave_merge_cascade_gotchas`).

**Total tasks**: 32 (PB 6, FD 7, FA 6, FC 9, Polish 4). **Per story**: US1 ≈ T014–T019; US2 ≈ T021/T024/T028; US3 ≈ T026/T027; US4 ≈ T020/T022/T025; US5 ≈ T029 (+ PB enforcement); US6 ≈ T015/T023/T030.
