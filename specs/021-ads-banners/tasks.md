# Tasks: Ads & Banners Admin Module (Phase 21)

**Input**: Design documents from `specs/021-ads-banners/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: NONE — per the project's MVP convention (memory `feedback_no_new_tests`): no new automated tests; verification is manual on-device + wire-level/SQL inspection (see `quickstart.md`).

## Organization

Phases here are the plan's **implementation/wave phases** (PB / PD / PA / PS — see `plan.md` § Implementation Phases), NOT one-phase-per-user-story, because this tasks.md drives `/wave` and the appended Touch-Fan / Dependency-Audit / Wave-Plan / Model-Routing sections all key off PB/PD/PA/PS. Each task still carries its `[US#]` story tag for traceability (US1 authoring · US2 serving · US3 tap/click · US4 both-ends security · US5 l10n/theme).

## Format: `[ID] [P?] [Story] Description`
- **[P]**: parallelizable (different files, no incomplete-task dependency)
- **[US#]**: the user story the task serves
- Exact file paths included; backend = `supabase/migrations/`, app = `lib/`

> **Checkbox discipline (MANDATORY for every dispatched sub-agent)**: when you finish a task, flip its `- [ ] T<id>` to `- [X] T<id>` **in the same commit as the implementation**. Do NOT defer checkbox-flipping to a "cleanup pass" — it never happens.

---

## Phase 1: Setup (Shared)

**Purpose**: feature-tree skeleton + dependency confirmation. Folds into Wave 1 (PD creates the files).

- [X] T001 [P] Create the `lib/features/ads/` Clean-Arch tree per `plan.md` § Project Structure: `domain/{entities,repositories,usecases}/`, `data/{datasources,dtos,repositories}/`, `admin/presentation/{bloc,pages,widgets}/`, `presentation/{bloc,widgets}/`.
- [X] T002 [P] Confirm ZERO `pubspec.yaml` changes are needed (`url_launcher`, `go_router`, `image_picker`, `image`, `flutter_image_compress`, `cached_network_image` all already present) — record `git diff pubspec.yaml pubspec.lock` is empty (FR-025).

---

## Phase 2 — PB: Backend (9 migrations) [Wave 1]

**Goal**: the three ads tables, serving view, storage bucket, write RPCs, click recorder, audit triggers — the server-side foundation for every story. All SQL under `supabase/migrations/`; bodies in `data-model.md`.

**Independent test**: apply via Supabase MCP; `get_advisors` clean; structural check confirms tables (RLS on) + view + bucket + RPCs exist with the grants in `contracts/`.

- [X] T003 [P] [US1] Migration `supabase/migrations/20260601120006_create_ads.sql` — `ads` table (title, image_path, caption_ar/en both-or-neither CHECK, link_kind CHECK + link_value, start_at/end_at window CHECK, is_active, archived_at, created_by, timestamps), `idx_ads_active_window`, RLS on, `ads_select_admin` (`current_user_has_permission('ads.manage')`), `REVOKE INSERT,UPDATE,DELETE … FROM authenticated, anon`, `set_updated_at` trigger.
- [X] T004 [P] [US1] Migration `supabase/migrations/20260601120007_create_ad_placements.sql` — PK `(ad_id, placement_key)`, `ad_id` FK CASCADE, `placement_key` CHECK (5 keys), `priority` INT, `idx_ad_placements_key_priority`, RLS + `ad_placements_select_admin` + REVOKE writes.
- [X] T005 [P] [US3] Migration `supabase/migrations/20260601120008_create_ad_impressions.sql` — clicks-only (`kind` CHECK ∈ ('click') DEFAULT 'click'), ad_id FK CASCADE, placement_key CHECK, nullable user_id, metadata, `idx_ad_impressions_ad_kind`, RLS + admin SELECT + REVOKE writes.
- [X] T006 [P] [US2] Migration `supabase/migrations/20260601120009_create_v_ads_serving.sql` — SECURITY DEFINER view (eligible JOIN: active + `archived_at IS NULL` + in-window), serving fields only, `GRANT SELECT TO anon, authenticated`.
- [X] T007 [P] [US1] Migration `supabase/migrations/20260601120010_create_ads_storage.sql` — public `ads` bucket (`ON CONFLICT DO UPDATE`, image mimes, 5 MB) + `storage.objects` policies (public select; `ads.manage`+path-shape insert; `ads.manage` update/delete).
- [X] T008 [P] [US1] [US4] Migration `supabase/migrations/20260601120011_create_ad_write_rpcs.sql` — `create_ad`/`update_ad`/`set_ad_active`/`archive_ad` (SECURITY DEFINER, re-check `ads.manage` → `permission_denied`/42501, bind `created_by := auth.uid()`, atomic placement replace), `REVOKE … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated`.
- [X] T009 [P] [US3] [US4] Migration `supabase/migrations/20260601120012_create_record_ad_event_rpc.sql` — `record_ad_event(p_ad_id, p_placement_key)` SECURITY DEFINER (eligibility+assignment gate → `ad_not_eligible`/23514, insert `kind='click'` + IP/UA, `auth.uid()` nullable), `REVOKE … FROM PUBLIC; GRANT … TO authenticated, anon` (mirrors `record_lead_event`, R-167).
- [X] T010 [P] [US1] Migration `supabase/migrations/20260601120013_create_ad_audit_triggers.sql` — `log_audit('ad.created',…)` AFTER INSERT; `log_audit('ad.deleted',…)` AFTER UPDATE OF archived_at WHEN newly-non-null; additive `log_audit('ad.activation_changed',…)` AFTER UPDATE OF is_active.
- [X] T011 [P] [US4] Migration `supabase/migrations/20260601120014_phase21_advisor_hardening.sql` — `ALTER FUNCTION … SET search_path` on the 5 new RPCs.
- [X] T012 [US4] Apply migrations T003–T011 in timestamp order via Supabase MCP `apply_migration` (memory `project_supabase_apply_via_mcp`); run `get_advisors`; resolve any SECURITY DEFINER / function-search-path / RLS advisory; structural check (tables RLS-on, view, bucket public, 5 RPCs with correct grants). (Depends on T003–T011.) — **DONE**: migrations …006–…014 applied; follow-up `…015_scope_ads_bucket_select` resolves the `public_bucket_allows_listing` advisory (scoped to eligible-ad EXISTS, mirroring `listing-images`); remaining advisories are the intentional `v_ads_serving` definer view (R-166) + per-RPC executable INFO (all gate internally); audit triggers runtime-verified (ad.created/activation_changed/deleted → target_type='ads').

**Checkpoint**: backend live; `v_ads_serving` queryable by anon; RPCs callable; advisors clean.

---

## Phase 3 — PD: Flutter domain + data [Wave 1]

**Goal**: the shared Dart contract (entities, repositories, use cases, datasources, DTOs, DI) every UI phase imports. Compiles/analyzes WITHOUT the DB applied (string-keyed Supabase access per `contracts/`).

**Independent test**: `flutter analyze` clean; `injection.config.dart` contains the new registrations.

- [X] T013 [P] [US2] Entities `lib/features/ads/domain/entities/ad_link.dart` (`AdLinkKind`), `ad_placement.dart` (`AdPlacement` + wire-key mapping), `ad_status.dart` (`AdStatus`).
- [X] T014 [P] [US1] Entities `lib/features/ads/domain/entities/ad.dart` (`Ad` + derived-`AdStatus` getter, R-171), `ad_placement_assignment.dart` (`AdPlacementAssignment`), `serving_ad.dart` (`ServingAd`).
- [X] T015 [P] [US1] [US2] Abstract repos `lib/features/ads/domain/repositories/ads_admin_repository.dart` + `ads_serving_repository.dart` (return `Result<T>`/`Failure`).
- [X] T016 [P] [US1] Admin use cases `lib/features/ads/domain/usecases/`: `create_ad.dart`, `update_ad.dart`, `set_ad_active.dart`, `archive_ad.dart`, `load_ads.dart`, `upload_ad_image.dart`.
- [X] T017 [P] [US2] [US3] Serving use cases `lib/features/ads/domain/usecases/`: `load_serving_ads.dart`, `record_ad_click.dart`.
- [X] T018 [P] [US1] [US2] DTOs `lib/features/ads/data/dtos/ad_dto.dart` (↔ `ads` + placements) + `serving_ad_dto.dart` (↔ `v_ads_serving`).
- [X] T019 [US1] Datasource `lib/features/ads/data/datasources/supabase_ads_admin_datasource.dart` — `rpc('create_ad'|'update_ad'|'set_ad_active'|'archive_ad')`, admin `ads` select, `ads` bucket `uploadBinary` + `getPublicUrl` + orphan cleanup on failure. (Depends on T013–T018.)
- [X] T020 [US2] [US3] Datasource `lib/features/ads/data/datasources/supabase_ads_serving_datasource.dart` — `from('v_ads_serving').eq('placement_key',…).order('priority',desc)`, `rpc('record_ad_event')`. (Depends on T013–T018.)
- [X] T021 [US1] [US2] Repo impls `lib/features/ads/data/repositories/ads_admin_repository_impl.dart` + `ads_serving_repository_impl.dart` (`@LazySingleton(as:)`; map errors 42501→permission, 23514→ineligible, 23503→not-found → `Failure`). (Depends on T019, T020.)
- [X] T022 [US1] Regenerate DI: `dart run build_runner build --delete-conflicting-outputs`; confirm `lib/core/di/injection.config.dart` registers the new repos/datasources; `flutter analyze` clean. (Depends on T021.)

**Checkpoint**: ads domain/data layer compiles + is DI-wired; ready for UI phases to import.

---

## Phase 4 — PA: Admin CRUD surface + route + dashboard flip [Wave 2 · depends on PD]

**Goal** (US1, US4): an `ads.manage`-gated surface to author/schedule/place/soft-delete ads, reached from the dashboard's now-navigable Ads tile.

**Independent test**: as an `ads.manage` admin, create→edit→archive an ad end-to-end; non-holder sees no tile and is redirected from `/admin/ads`.

- [X] T023 [P] [US1] `lib/features/ads/admin/presentation/bloc/ads_admin_cubit.dart` — states (loading/list/saving/error); drives `CreateAd`/`UpdateAd`/`SetAdActive`/`ArchiveAd`/`LoadAds`/`UploadAdImage`.
- [X] T024 [P] [US1] Admin widgets `lib/features/ads/admin/presentation/widgets/`: `ad_status_chip.dart`, `placement_picker.dart` (multi-select + per-placement priority; flags `category_banner` "not yet live", R-175), `link_target_picker.dart` (kind+value per R-179: external→URL · listing/agency→UUID · category→property-type key · search→free-text query; validate value per kind), `schedule_picker.dart` (start/end, enforce `start < end`).
- [X] T025 [US1] `lib/features/ads/admin/presentation/pages/ads_list_page.dart` — list with `AdStatus` chips + archived filter + create FAB + activate/deactivate + soft-delete actions. (Depends on T023, T024.)
- [X] T026 [US1] `lib/features/ads/admin/presentation/pages/ad_editor_page.dart` — title, image pick+upload (`UploadAdImage`), optional ar+en caption (both-or-neither), link picker, schedule, placement+priority, active toggle; save via `CreateAd`/`UpdateAd`. (Depends on T023, T024.)
- [X] T027 [US1] [US4] Route + guard: `lib/core/routing/app_router.dart` (`AppRoutes.adminAds='/admin/ads'`, `AppRouteNames.adminAds`, `GoRoute(path:'ads', redirect: requireAdsManageRedirect, builder: AdsListPage)` under `/admin`); `lib/core/routing/auth_redirect.dart` (`requireAdsManageRedirect` — `checker.has(PermissionKeys.adsManage)` else `/admin?denied=ads`, mirrors `requireAuditLogsViewRedirect`).
- [X] T028 [US1] Flip the dashboard Ads tile in `lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart`: `state: DashboardSectionState.comingSoon` → `enabled` + `route: AppRoutes.adminAds`.
- [X] T029 [P] [US1] [US5] Add ads-admin l10n keys (namespaced `adsAdmin*`/`adStatus*`/`adLink*`/`adPlacement*`/schedule) to BOTH `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb`.
- [X] T030 [US1] DI regen (`dart run build_runner build --delete-conflicting-outputs`) for `AdsAdminCubit`; `flutter analyze` + l10n-parity clean. (Depends on T023–T029.)

**Checkpoint**: admin can fully manage the ad inventory; tile navigable; guard enforced.

---

## Phase 5 — PS: Public AdSlot + serving + host insertions [Wave 2 · depends on PD]

**Goal** (US2, US3): the placement-aware `AdSlot` on home/search/details serving eligible ads as a priority-ordered auto-advancing carousel, with tap→open-target + click recording.

**Independent test**: an active `home_top_banner` ad shows on home; ≥2 rotate by priority; tap opens target + records one click; empty placement collapses with no reflow.

- [X] T031 [P] [US2] `lib/features/ads/presentation/bloc/ad_slot_cubit.dart` — loads `LoadServingAds(placement)`; states empty/single/carousel/error.
- [X] T032 [P] [US2] [US5] `lib/features/ads/presentation/widgets/ad_banner_card.dart` — `CachedNetworkImage` from `getPublicUrl(image_path)` + optional locale-matched caption (themed, Phase 2 tokens).
- [X] T033 [US2] `lib/features/ads/presentation/widgets/ad_carousel.dart` — `PageView` + auto-advance `Timer` (~5 s) + manual swipe + page indicator, order `priority DESC`; single ad → static (no timer). (Depends on T032.)
- [X] T034 [US2] [US3] `lib/features/ads/presentation/widgets/ad_slot.dart` — collapses to `SizedBox.shrink()` when empty (FR-012); renders single/carousel; tap → `RecordAdClick` (best-effort, non-blocking) then open target (`launchUrl` external / `context.push` listing `/listings/:id`, search, category, agency `/agency/:id`); graceful fallback on unresolved target. (Depends on T031, T032, T033.)
- [X] T035 [US2] [US3] Insert into `lib/features/home/presentation/pages/home_page.dart` — `AdSlot(home_top_banner)` `SliverToBoxAdapter` after `MapEntryTile`; `AdSlot(home_middle_banner)` single slot after the first feed page (R-176). (Depends on T034.)
- [X] T036 [P] [US2] [US3] Insert `AdSlot(search_results_banner)` into `lib/features/search/presentation/pages/search_page.dart` — item before result cards (offset the `ListView.builder` index, like the Arabic-hint row). (Depends on T034.)
- [X] T037 [P] [US2] [US3] Insert `AdSlot(listing_details_banner)` into `lib/features/listing_details/presentation/pages/listing_details_page.dart` — after `ReporterStatusBanner`, before the title. (Depends on T034.)
- [X] T038 [P] [US2] [US5] Add AdSlot l10n keys (`adSlot*` — fallback/unavailable messages) to BOTH `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb`.
- [X] T039 [US2] DI regen (`dart run build_runner build --delete-conflicting-outputs`) for `AdSlotCubit`; `flutter analyze` + l10n-parity clean. (Depends on T031–T038.)

**Checkpoint**: ads render + rotate + tap-through + record clicks on all three surfaces.

---

## Phase 6: Polish & Cross-Cutting Verification [post-Wave 2, sequential]

**Purpose**: the cross-cutting QA pass (US4 security, US5 l10n/theme, SC verification). No production-file mods — verification only; on-device walk mandatory (memory `project_wave_output_needs_device_qa`).

- [ ] T040 [US5] 4-combination render check (light/dark × ar-RTL/en-LTR) on the admin surface + `AdSlot` (image-only AND image+caption) on the Infinix Note 8 + a 412 dp Pixel 8 Pro AVD (SC-010).
- [ ] T041 [US4] Wire-level security checks: from a non-`ads.manage` (and anon) session, confirm `ads`/`ad_placements` insert-update-delete, `ads`-bucket write, `ad_impressions` insert, and the admin RPCs are all DENIED; anon `v_ads_serving` returns eligible-only (no drafts/inactive/expired/archived, no admin fields) — SC-008.
- [ ] T042 [US3] Click verification: `SELECT COUNT(*) FROM ad_impressions WHERE ad_id='…' AND kind='click'` == taps; `SELECT COUNT(*) … WHERE kind<>'click'` == 0; offline tap still opens target (SC-006/007); `SELECT … FROM audit_logs WHERE target_type='ads'` shows create+delete (SC-011).
- [ ] T043 Run the full CI linter suite (`flutter analyze` + format + design-tokens + l10n-parity + l10n-literals + SDK-boundary — memory `project_wave_run_full_verify_suite`); grep the ads feature for hardcoded role branches (none — FR-022); confirm `git diff pubspec.yaml` empty + no ad-network dep + no §9.1/seed change (SC-013).
- [ ] T044 Execute `quickstart.md` end-to-end on device; record SC-001..SC-013 outcomes; confirm advisors clean. Update spec/plan/data-model/contracts if any real behavior diverged (Principle X).

---

## Dependencies & Execution Order

### Phase Dependencies (wave phases)
- **Setup (P1)**: no deps; folds into Wave 1.
- **PB (P2)** and **PD (P3)**: no code edge between them — both implement the shared `contracts/` interface; run in parallel (Wave 1). Internally, PB's T012 (apply) depends on T003–T011; PD's T019–T022 depend on T013–T018.
- **PA (P4)** and **PS (P5)**: each depends on PD (Wave 1) only, not on each other; run in parallel (Wave 2).
- **Polish (P6)**: after PA + PS merge + PB applied; sequential QA.

### Within-phase parallelism
- PB: T003–T011 are `[P]` (distinct migration files); T012 is the apply gate.
- PD: T013–T018 are `[P]` (distinct domain/dto files); T019/T020 then T021 then T022.
- PA: T023/T024/T029 are `[P]`; T025/T026 depend on T023+T024; T030 is the DI gate.
- PS: T031/T032/T036/T037/T038 are `[P]` where files differ; T033→T034→T035; T039 is the DI gate.

---

## Implementation Strategy

**MVP** = PB + PD + PA (US1 authoring) → admins can manage the inventory; then PS (US2/US3) makes ads visible + tappable. US4 (security) is built into PB/PA/PS and verified in Polish; US5 (l10n/theme) is built into PA/PS and verified in Polish.

**Wave execution** (`/wave all --auto`): dispatch Wave 1 (PB, PD) → merge PD then PB → dispatch Wave 2 (PA, PS) → merge PA then PS → run Polish QA. See the Wave Plan below.

---

# ════════ Multi-Agent Execution Plan (for `/wave`) ════════

## Touch-Fan Table

Shared/cross-cutting files each phase modifies (orchestrator: warn sub-agents up front + merge least-touch-first):

- **Setup (P1)**: *(none shared)* — creates empty `lib/features/ads/**` folders only.
- **PB (Backend)**: `supabase/migrations/20260601120006…014_*.sql` (9 NEW files) — **no shared-file contention**.
- **PD (Domain+Data)**: `lib/features/ads/{domain,data}/**` (new) · **`lib/core/di/injection.config.dart`** (codegen).
- **PA (Admin UI)**: `lib/features/ads/admin/**` (new) · `lib/core/routing/app_router.dart` · `lib/core/routing/auth_redirect.dart` · `lib/features/admin/dashboard/presentation/widgets/dashboard_sections.dart` · **`lib/l10n/app_ar.arb`** · **`lib/l10n/app_en.arb`** · **`lib/core/di/injection.config.dart`** (codegen).
- **PS (Serving UI)**: `lib/features/ads/presentation/**` (new) · `lib/features/home/presentation/pages/home_page.dart` · `lib/features/search/presentation/pages/search_page.dart` · `lib/features/listing_details/presentation/pages/listing_details_page.dart` · **`lib/l10n/app_ar.arb`** · **`lib/l10n/app_en.arb`** · **`lib/core/di/injection.config.dart`** (codegen).
- **Polish (P6)**: *(none)* — verification only.

**Contended files**: `lib/core/di/injection.config.dart` (PD, PA, PS) · `lib/l10n/app_ar.arb` + `app_en.arb` (PA, PS). The dashboard/route files (PA) and host-surface files (PS) are **disjoint** — PA and PS do not collide outside the DI+ARB trio.
**Merge least-touch-first**: **PB** (0 shared) → **PD** (DI only) → **PA** (DI+ARB+routing) → **PS** (DI+ARB+hosts). Each successor rebases on the merged predecessor, re-runs `dart run build_runner build --delete-conflicting-outputs`, and unions the namespaced ARB keys (no key collision expected; l10n-parity linter MUST pass).

## Dependency Audit

Re-reading `plan.md` § Phase Dependencies — every declared edge, with the named consumer (false deps removed):

- **PA → PD**: ✅ REAL — `lib/features/ads/admin/presentation/bloc/ads_admin_cubit.dart` imports the abstract `AdsAdminRepository` + the use cases `CreateAd`/`UpdateAd`/`SetAdActive`/`ArchiveAd`/`LoadAds`/`UploadAdImage`, and `ad_editor_page.dart` imports the entities `Ad`/`AdLinkKind`/`AdPlacement`/`AdPlacementAssignment`/`AdStatus` — all defined under `lib/features/ads/domain/` by PD (T013–T017).
- **PS → PD**: ✅ REAL — `lib/features/ads/presentation/bloc/ad_slot_cubit.dart` imports `AdsServingRepository` + `LoadServingAds`, and `ad_slot.dart`/`ad_banner_card.dart` import `ServingAd`/`AdLinkKind`/`AdPlacement` + `RecordAdClick` — all defined under `lib/features/ads/domain/` by PD (T013–T017).
- **PB → (none)**: no Dart symbol crosses out of PB. Its relationships to PD are **runtime contracts** (datasource calls `rpc('create_ad'…)` / `from('v_ads_serving')` by string name — compiles without PB). **Not a build edge.**
- **PD → (none)**: PD has NO Dart import from PB; the DB names are string-keyed contracts. **No edge.**
- **PA ↔ PS**: NO edge — PS's in-app deep-link targets consume **pre-existing** route constants (`AppRoutes.listingDetailsFor`, `AppRoutes.search`, `/agency/:id`) from earlier phases, NOT PA's new `AppRoutes.adminAds`.
- **Setup → ***: NO code edge — Setup only creates folders (no exported symbol); file creation auto-makes dirs. Folds into Wave 1.

**Result**: exactly **2** real edges (PA→PD, PS→PD), both with named consumers. **0** false/pessimistic edges. Graph is minimal.

## Wave Plan

Topological sort of the dispatchable phases (Setup folds into Wave 1; Polish is post-merge QA):

- **Wave 1**: **PB, PD** — no unmet deps (Setup folds in; both implement the shared contract).
- **Wave 2**: **PA, PS** — all deps (PD) satisfied by Wave 1.
- **Post-wave**: **Polish (P6)** — sequential on-device QA after PA+PS merge and PB applied (not a parallel dispatch).

Both waves ≤ 4 phases (2 each) — cap respected. Execute with `/wave all --auto`; the orchestrator does NOT need to re-derive this.

## Model Routing per Phase

- **Setup (P1)**: Sonnet (folder scaffold).
- **PB (Backend)**: **Opus** — RLS policies + REVOKE posture + SECURITY DEFINER RPCs (permission re-checks, atomic multi-table writes, eligibility gate) + audit triggers. Security invariants / RLS → Opus per the heuristic.
- **PD (Domain+Data)**: Sonnet — entities, DTOs, repository/datasource scaffolding, error-mapping, DI codegen. No invariants/ledger/state-machine.
- **PA (Admin UI)**: Sonnet — admin CRUD widgets, forms, pickers, route+one-line guard, dashboard-tile flip, l10n.
- **PS (Serving UI)**: Sonnet — AdSlot/carousel widgets, host-surface insertions, best-effort tap/click + deep-link nav, l10n.
- **Polish (P6)**: Sonnet — on-device QA, wire-level checks, linter suite, docs reconciliation.

Format line: `PB: Opus (RLS + SECURITY DEFINER RPCs + audit). PD: Sonnet (entities/DTOs/DI). PA: Sonnet (admin CRUD + route + l10n). PS: Sonnet (AdSlot + carousel + host insertions). Setup/Polish: Sonnet.`

---

## Notes
- `[P]` = different files, no incomplete-task dependency.
- `[US#]` maps each task to its user story for traceability (phases are wave units, not per-story).
- **Every dispatched sub-agent flips its `- [ ] T<id>` → `- [X] T<id>` in the same commit as the implementation** — never a deferred cleanup pass.
- No new automated tests (memory `feedback_no_new_tests`); verification is the on-device walk + wire/SQL checks in `quickstart.md`, recorded against SC-001..SC-013.
- Backend applied via Supabase MCP, not `db push` (memory `project_supabase_apply_via_mcp`); MCP doesn't dedupe by name, so SQL is idempotent (memory `project_supabase_mcp_apply_migration`).
