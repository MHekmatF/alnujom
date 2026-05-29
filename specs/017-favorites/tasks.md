---
description: "Phase 17 — Favorites task list"
---

# Tasks: Favorites

**Input**: Design documents from `specs/017-favorites/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: No new automated tests per project memory `feedback_no_new_tests.md`. Manual UI verification on Infinix Note 8 + Pixel 8 Pro AVD (per memories `user_test_device.md` and `feedback_avd_acceptable_qa.md`) is the gate. `quickstart.md` captures the recipe.
**Organization**: Tasks are grouped by Sub-Phase (matching plan.md §Phase Dependencies — Phase 1 = Sub-Phase A … Phase 8 = Sub-Phase H). Story labels [US1]..[US6] tag the primary user story each task enables; many tasks serve multiple stories where the heart, the FavoritesPage, and the backend share infrastructure.

**Acceptance-criteria convention** (Constitution Principle X; matches Phase 14/15/16 precedent): each implementation task's acceptance criteria is the **linked contract file** or **data-model section** it references. A task that says "Create X per contracts/phase17-Y.md" is accepted when (a) the file exists at the specified path, (b) its content matches the contract's stated structure (signature, columns, behavior), and (c) `flutter analyze` returns zero new errors / `flutter build apk --debug` succeeds where applicable. The **Phase Checkpoint** at the end of each sub-phase is the cumulative acceptance gate.

**Checkbox discipline (MANDATORY for every sub-agent)**: Each sub-agent dispatched against this tasks.md MUST flip its `- [ ] T<id>` checkboxes to `- [X] T<id>` in the **same commit** as the implementation. Do NOT leave checkbox-flipping for a "cleanup pass" — it never happens. If a task is partially complete or device-verified-only, leave it `- [ ]` and prefix the description note with `**⚠️ PARTIAL —**` + a one-line reason + a `DEFERRED.md §D-T<id>` pointer per memory `feedback_strict_task_completion.md`.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Maps the task to one or more user stories from spec.md
- All file paths are repo-relative

---

## Phase 1: Sub-Phase A — Bootstrap (route slot + domain skeleton)

**Purpose**: Register the `/favorites` route (with an anonymous-deep-link redirect to login), scaffold the `lib/features/favorites/` skeleton, define the `Favorite` entity, and stub `FavoritesPage` so the route resolves end-to-end.

**Goal**: After Phase 1, `flutter build` is green and navigating to `/favorites` (signed-in) shows a stub page; an anonymous deep-link to `/favorites` redirects to `/login`.

- [X] T001 [US2] In `lib/core/routing/app_router.dart`, add `static const favorites = '/favorites';` to `AppRoutes` (after `static const inquiryDetail = '/inquiries/:id';`) and `static const favorites = 'favorites';` to `AppRouteNames`.
- [X] T002 [P] Create the `lib/features/favorites/` skeleton directories: `data/datasources/`, `data/models/`, `data/repositories/`, `domain/entities/`, `domain/repositories/`, `domain/usecases/`, `presentation/bloc/`, `presentation/pages/`, `presentation/widgets/` (each with a placeholder file so it commits).
- [X] T003 [P] [US1] Create `lib/features/favorites/domain/entities/favorite.dart` per data-model.md §6 — `Favorite extends Equatable { final String listingId; final DateTime createdAt; }`. Import only `package:equatable/equatable.dart`.
- [X] T004 [P] [US2] Create stub `lib/features/favorites/presentation/pages/favorites_page.dart` — `class FavoritesPage extends StatelessWidget { const FavoritesPage({super.key}); }` rendering an empty `Scaffold` + `AppBar` (placeholder title, replaced in Phase 7).
- [X] T005 [US2] In `lib/core/routing/app_router.dart`, register a `GoRoute` at `AppRoutes.favorites` → `const FavoritesPage()` with a `redirect:` returning `AppRoutes.login` when the resolved `AuthBloc.state is Unauthenticated` and `null` otherwise (per contracts/phase17-favorites-page-and-entry-points.md §Route + R-115). Add the `FavoritesPage` import.
- [X] T006 Run `flutter build apk --debug --dart-define-from-file=.env.json` to confirm the app builds. Flip checkboxes T001–T006 in the same commit.

**Phase Checkpoint**: App launches; signed-in navigation to `/favorites` shows the stub; anonymous deep-link to `/favorites` redirects to `/login`. Build green.

---

## Phase 2: Sub-Phase B — Backend schema (`favorites` table)

**Purpose**: Land the migration creating `public.favorites` (composite PK, FK delete behaviors, index, RLS enabled).

**Goal**: After Phase 2, `public.favorites` exists with `(user_id, listing_id)` PK, the `idx_favorites_user_created` index, and RLS enabled (no policies yet).

- [X] T007 [US3] Create migration file `supabase/migrations/20260529120001_create_favorites_table.sql` with the full body per data-model.md §1 + contracts/phase17-favorites-table.md. Columns: `user_id` (FK → `auth.users(id)` ON DELETE CASCADE), `listing_id` (FK → `public.listings(id)` ON DELETE RESTRICT per Q4=C), `created_at`; `PRIMARY KEY (user_id, listing_id)`; `ALTER TABLE … ENABLE ROW LEVEL SECURITY`; `CREATE INDEX idx_favorites_user_created ON public.favorites (user_id, created_at DESC)`.
- [ ] T008 [US3] Apply T007's migration via Supabase MCP `apply_migration`: name `"create_favorites_table"`, query = T007's file contents. The body uses `CREATE TABLE IF NOT EXISTS`, so re-application is SQL-safe (per memory `project_supabase_mcp_apply_migration.md`). Verify `SELECT to_regclass('public.favorites');` is non-null. **⚠️ deferred — DB application is the orchestrator/human tail step.
- [X] T009 [P] Create `supabase/docs/favorites.md` documenting columns, the composite-PK uniqueness rule, the FK delete behaviors, the (forward-stated) self-only RLS posture, and the "creation-via-RPC-only / removal-via-DELETE-policy" write model.

**Phase Checkpoint**: `public.favorites` exists; a privileged-session `INSERT` succeeds; a duplicate `(user_id, listing_id)` is rejected by the PK; a `listings` hard-delete of a favorited listing is RESTRICTed.

---

## Phase 3: Sub-Phase C — Backend policies + `v_favorites` view

**Purpose**: Land the self-only RLS policies (the load-bearing privacy boundary) and the `SECURITY INVOKER` `v_favorites` view with the `is_available` flag.

**Goal**: After Phase 3, a user reads/deletes only their own favorites; anonymous reads are denied; `v_favorites` returns the caller's favorites (available + unavailable) with `is_available`.

- [X] T010 [US3] Create migration file `supabase/migrations/20260529120002_create_favorites_policies.sql` per data-model.md §2 + contracts/phase17-favorites-policies.md: `favorites_select_self` (SELECT, `USING (user_id = auth.uid())`), `favorites_delete_self` (DELETE, `USING (user_id = auth.uid())`), `REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon`. NO INSERT policy, NO `anon` policy.
- [X] T011 [US2] Create migration file `supabase/migrations/20260529120003_create_v_favorites_view.sql` per data-model.md §3 + contracts/phase17-v-favorites-view.md: `CREATE OR REPLACE VIEW public.v_favorites WITH (security_invoker = true) AS …` joining `favorites` → `listings` (+ LATERAL primary price + LATERAL main image + governorate/city display-name joins) projecting card fields + `is_available` (computed; NOT a `WHERE l.status` filter). `GRANT SELECT … TO authenticated`.
- [ ] T012 [US3] Apply T010's migration via Supabase MCP `apply_migration`: name `"create_favorites_policies"`, query = T010's file contents. **⚠️ deferred — DB application is the orchestrator/human tail step.
- [ ] T013 [US2] Apply T011's migration via Supabase MCP `apply_migration`: name `"create_v_favorites_view"`, query = T011's file contents. **⚠️ deferred — DB application is the orchestrator/human tail step.
- [ ] T014 [US3] Smoke-test the privacy boundary per contracts/phase17-favorites-policies.md §Smoke tests using two JWT sessions (user-A, user-B): confirm a forged `WHERE user_id='<B>'` from A returns 0 rows; a DELETE of B's row from A affects 0 rows; an anon SELECT is denied. Then update `supabase/docs/favorites.md` with the RLS matrix + the `is_available` contract. **⚠️ smoke deferred — needs live DB (orchestrator/human tail).

**Phase Checkpoint**: Self-only RLS verified across two users + anon (SC-005 / SC-006 backend portion); `v_favorites` returns the caller's favorites only, with unavailable favorites still present (`is_available=false`).

---

## Phase 4: Sub-Phase D — `add_favorite` RPC + advisor hardening

**Purpose**: Land the SECURITY DEFINER `add_favorite` RPC (the bypass-proof, deduped favorite + event write) and the advisor-hardening migration.

**Goal**: After Phase 4, `SELECT public.add_favorite('<approved-listing>')` inserts the favorite + exactly one `favorite_added` event the first time; re-adding after removal inserts no second event; anonymous/non-approved calls are rejected.

- [X] T015 [US5] Create migration file `supabase/migrations/20260529120004_create_add_favorite_rpc.sql` per data-model.md §4 + contracts/phase17-add-favorite-rpc.md: `public.add_favorite(p_listing_id uuid) RETURNS void` SECURITY DEFINER `SET search_path = pg_catalog, public`. Body: `auth_required` guard (ERRCODE 28000), `listing_not_found` (23503) / `listing_not_approved` (23514) validation, idempotent `INSERT … ON CONFLICT (user_id, listing_id) DO NOTHING`, and the `EXISTS`-deduped `favorite_added` `lead_events` insert (IP/UA from server context) — both inserts in one transaction. `REVOKE ALL … FROM PUBLIC; GRANT EXECUTE … TO authenticated` (NOT anon).
- [X] T016 Create migration file `supabase/migrations/20260529120005_phase17_advisor_hardening.sql` per data-model.md §5: `ALTER FUNCTION public.add_favorite(uuid) SET search_path = pg_catalog, public;` + idempotent `REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon` + `GRANT SELECT ON public.v_favorites TO authenticated` + `REVOKE ALL ON FUNCTION … FROM PUBLIC; GRANT EXECUTE … TO authenticated`.
- [ ] T017 [US5] Apply T015's migration via Supabase MCP `apply_migration`: name `"create_add_favorite_rpc"`, query = T015's file contents. **⚠️ deferred — DB application/smoke is the orchestrator/human tail step.
- [ ] T018 Apply T016's migration via Supabase MCP `apply_migration`: name `"phase17_advisor_hardening"`, query = T016's file contents. Then run Supabase advisors (`get_advisors`) and confirm zero new security/performance warnings attributable to Phase 17. **⚠️ deferred — DB application/smoke is the orchestrator/human tail step.
- [ ] T019 [US5] Smoke-test the RPC per contracts/phase17-add-favorite-rpc.md §Smoke tests as an authenticated session: first `add_favorite('<approved>')` → exactly one `favorite_added`; `DELETE` then re-`add_favorite` → still exactly one (dedup); `add_favorite('<pending>')` → `listing_not_approved` error. **⚠️ deferred — DB application/smoke is the orchestrator/human tail step.

**Phase Checkpoint**: RPC inserts favorite + deduped event atomically; rejects anon/non-approved; advisors clean (SC-007 / SC-008 backend portion).

---

## Phase 5: Sub-Phase E — Domain + data layer

**Purpose**: Build the `FavoriteListing` entity, the `FavoritesRepository` interface + impl, the four use cases, the DTO, and the datasource; register DI.

**Goal**: After Phase 5, the repository can add/remove a favorite, load the user's favorited ids, and page the FavoritesPage list — all behind the domain interface, Supabase confined to `data/`.

- [X] T020 [P] [US2] Create `lib/features/favorites/domain/entities/favorite_listing.dart` per data-model.md §6 — `FavoriteListing extends Equatable` with `id`, `title`, `propertyType` (PropertyType, Phase 10), `purpose` (ListingPurpose, Phase 10), `primaryAmount`, `primaryCurrency`, `mainImagePath` (String?), `governorateNameAr/_En`, `cityNameAr/_En`, `isAvailable` (bool), `favoritedAt` (DateTime).
- [X] T021 [P] [US1] Create `lib/features/favorites/domain/repositories/favorites_repository.dart` per data-model.md §6 — `abstract interface class FavoritesRepository` with `addFavorite`, `removeFavorite`, `loadFavoriteIds`, `loadFavorites({cursor, limit})`, all returning `Result<…, Failure>` from `lib/core/errors/`.
- [X] T022 [P] [US1] Create `lib/features/favorites/domain/usecases/add_favorite.dart` — single-method use case wrapping `FavoritesRepository.addFavorite`. `@injectable`.
- [X] T023 [P] [US1] Create `lib/features/favorites/domain/usecases/remove_favorite.dart` — wraps `removeFavorite`. `@injectable`.
- [X] T024 [P] [US1] Create `lib/features/favorites/domain/usecases/load_favorite_ids.dart` — wraps `loadFavoriteIds`. `@injectable`.
- [X] T025 [P] [US2] Create `lib/features/favorites/domain/usecases/load_favorites.dart` — wraps `loadFavorites`. `@injectable`.
- [X] T026 [P] [US2] Create `lib/features/favorites/data/models/favorite_listing_dto.dart` mirroring the `v_favorites` row shape (`fromJson` + `toEntity()`).
- [X] T027 [US1,US2] Create `lib/features/favorites/data/datasources/supabase_favorites_datasource.dart` per plan.md Sub-Phase E step 5: `addFavorite` → `rpc('add_favorite', {'p_listing_id': …})`; `removeFavorite` → `from('favorites').delete().eq('listing_id', …)`; `loadFavoriteIds` → `from('favorites').select('listing_id')`; `loadFavorites` → `from('v_favorites').select().order('favorited_at', ascending: false)` with cursor pagination on `favorited_at`. `@injectable`.
- [X] T028 [US1,US2] Create `lib/features/favorites/data/repositories/favorites_repository_impl.dart` implementing `FavoritesRepository`, mapping DTOs → entities + datasource errors → `Failure`. `@Injectable(as: FavoritesRepository)`.
- [X] T029 [US1,US2] Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart` (picks up the 4 use cases + datasource + repository). Confirm `flutter analyze` is clean.

**Phase Checkpoint**: `flutter analyze` clean; DI resolves `FavoritesRepository` + the 4 use cases; no `package:supabase_flutter` import under `domain/`.

---

## Phase 6: Sub-Phase F — Presentation (FavoritesCubit + FavoriteHeartButton + FavoritesPage)

**Purpose**: Build the shared session-set cubit, the reusable heart button (with the anonymous branch), the FavoritesPage + its bloc, and the empty-state.

**Goal**: After Phase 6, the FavoritesPage lists the user's saved listings (newest-first, paginated, unavailable marked), and `FavoriteHeartButton` toggles optimistically and routes anonymous taps to login — though hosts wire in Phase 8.

- [X] T030 [US1] Create `lib/features/favorites/presentation/bloc/favorites_cubit.dart` per contracts/phase17-favorite-heart-toggle.md §FavoritesCubit — `@lazySingleton`; `FavoritesState({Set<String> favoritedIds, bool isSignedIn})`; subscribes to `AuthBloc` (hydrate via `LoadFavoriteIds` on signed-in, clear on `Unauthenticated`); `toggle(listingId)` optimistic add/remove → `AddFavorite`/`RemoveFavorite` → revert + surface-failure-flag on `Result.failure`; `isFavorited(listingId)` helper.
- [X] T031 [US1,US6] Create `lib/features/favorites/presentation/widgets/favorite_heart_button.dart` per contracts/phase17-favorite-heart-toggle.md §FavoriteHeartButton — `BlocSelector<FavoritesCubit, FavoritesState, bool>` keyed on `isFavorited(listingId)`; filled (`colorScheme.error`) / empty heart via Phase 2 tokens; `semanticLabel` from `favorite_unsave_label`/`favorite_heart_label`; `onTap` → if anonymous, show `favorite_sign_in_prompt` + `context.push(AppRoutes.login)` (no toggle, no pre-auth save); else `getIt<FavoritesCubit>().toggle(listingId)`.
- [X] T032 [US2] Create `lib/features/favorites/presentation/bloc/favorites_page_bloc.dart` + `favorites_page_event.dart` + `favorites_page_state.dart` per contracts/phase17-favorites-page-and-entry-points.md §FavoritesPageBloc — events `FavoritesPageOpened`/`Refresh`/`MoreLoaded`; states `Loading`/`Loaded({items, hasMore})`/`Error`; `LoadFavorites` cursor on `favoritedAt DESC`, limit 30. `@injectable`.
- [X] T033 [US2] Replace the Phase 1 stub `lib/features/favorites/presentation/pages/favorites_page.dart` with the full composition per contracts/phase17-favorites-page-and-entry-points.md §FavoritesPage composition — `AppBar` (`DeepLinkAwareBackButton` + `favorites_page_title`); `RefreshIndicator` + `ListView.builder` of cards with embedded `FavoriteHeartButton`; available cards tap → `AppRoutes.listingDetailsFor(item.id)`; unavailable cards render `favorite_unavailable_indicator` AND stay tappable → same route (Q4=A); scroll-end paginates; empty → `FavoritesEmptyState`.
- [X] T034 [P] [US2] Create `lib/features/favorites/presentation/widgets/favorites_empty_state.dart` — localized `favorites_empty_state` message + heart illustration from Phase 2 tokens.
- [X] T035 [US1,US2] Register `FavoritesCubit` (`@lazySingleton`) + `FavoritesPageBloc` (`@injectable`); run `build_runner` to regenerate `injection.config.dart`. Confirm `flutter analyze` clean.

**Phase Checkpoint**: FavoritesPage renders list + empty-state; `FavoriteHeartButton` toggles optimistically and the anonymous branch routes to login (verified once hosts wire in Phase 8 / via a temporary test mount).

---

## Phase 7: Sub-Phase G — Localization (~8 bilingual ARB keys)

**Purpose**: Add the favorites strings to both ARB files and regenerate the localizations.

**Goal**: After Phase 7, `l10n.favorites_page_title`, `favorite_sign_in_prompt`, etc. resolve in both `ar` and `en`.

- [X] T036 [P] Add the ~8 keys to `lib/l10n/app_en.arb` per plan.md Sub-Phase G: `favorite_heart_label`, `favorite_unsave_label`, `favorite_sign_in_prompt`, `favorites_page_title`, `favorites_empty_state`, `favorite_unavailable_indicator`, `profile_favorites_tile`, `favorite_toggle_failed` (English values).
- [X] T037 [P] Add the same ~8 keys to `lib/l10n/app_ar.arb` with Syrian-friendly Arabic values (e.g., `favorites_page_title` = "المفضلة", `favorite_sign_in_prompt` = "سجّل الدخول لحفظ العقار").
- [X] T038 Run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations.dart` + `app_localizations_ar.dart` + `app_localizations_en.dart`. Confirm `flutter analyze` clean.

**Phase Checkpoint**: Both ARBs carry all 8 keys (ar + en); generated getters compile.

---

## Phase 8: Sub-Phase H — Entry-point wiring (4 surfaces + Profile tile + cubit hydration)

**Purpose**: Embed `FavoriteHeartButton` into the four listing surfaces, add the Profile tile, and hydrate the cubit on the home shell.

**Goal**: After Phase 8, the heart works on the home feed, search results, map preview, and listing details; the Profile "My Favorites" tile opens `/favorites`; the cubit hydrates on sign-in.

- [X] T039 [US1] Update `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` per FR-001 + contracts/phase17-favorite-heart-toggle.md — replace the Favorite `_ActionButton`'s `_showComingSoon` handler with a `BlocSelector<FavoritesCubit, FavoritesState, bool>`-driven icon/label + the anonymous-aware toggle; add `required String listingId` to the constructor. Share + Report `_ActionButton`s and the row layout UNCHANGED (FR-033).
- [X] T040 [US1] Update `lib/features/listing_details/presentation/pages/listing_details_page.dart` — pass `listingId: <aggregate listing id>` to the `PerListingActionBlock()` call site. One-line change; no widget-tree reflow.
- [X] T041 [P] [US1] Update `lib/features/home/presentation/widgets/home_listing_card.dart` — wrap `_Hero`'s `AspectRatio` child in a `Stack` and overlay `PositionedDirectional(top: AppSpacing.sm, end: AppSpacing.sm, child: FavoriteHeartButton(listingId: card.id))`.
- [X] T042 [P] [US1] Update `lib/features/search/presentation/widgets/search_result_card.dart` — add `FavoriteHeartButton(listingId: item.id)` (top-end of `_CardImage` via a `Stack`, or trailing the title), preserving the 116 dp fixed-height layout.
- [X] T043 [P] [US1,US6] Update `lib/features/map/presentation/widgets/marker_preview_popover.dart` (per Q6=B) — add `FavoriteHeartButton(listingId: widget.marker.id)` to the action `Row` next to the "View details" `TextButton` (or beside the close `IconButton`).
- [X] T044 [P] [US2] Update `lib/features/profile/presentation/pages/profile_page.dart` — insert a `ListTile(leading: Icon(Icons.favorite_border), title: Text(l10n.profile_favorites_tile), trailing: Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.favorites))` immediately after the `profile_private_section` `ListTile` (current lines 132–138) and before the sign-out `Divider`.
- [X] T045 [US1,US4] Update `lib/features/home/presentation/pages/home_page.dart` — touch `getIt<FavoritesCubit>()` at shell entry (or expose via `BlocProvider.value`) so its `AuthBloc` subscription hydrates the session set on first signed-in build (mirrors the `InquiriesUnreadCubit` home-shell touch). No `AppLifecycleListener` needed (favorites state is auth-driven). Run `flutter build apk --debug --dart-define-from-file=.env.json`.

**Phase Checkpoint**: Heart present + working on all four surfaces with cross-surface consistency (SC-003); Profile tile opens `/favorites`; cubit hydrates on sign-in. Build green.

---

## Phase 9: Polish & Cross-Cutting Verification

**Purpose**: Run the quickstart SC matrix + the grep gates; capture any partials.

- [ ] T046 Execute `quickstart.md` §3–§11 on the reference Infinix Note 8 + Pixel 8 Pro AVD; tick SC-001..SC-013 (toggle timing, cross-surface consistency, FavoritesPage, two-user wire-level isolation, forged write rejection, lead-event dedup, persistence across device/reinstall, anonymous prompt, unavailable-favorite indicator, theme×locale matrix). Any partial / substitute-device result stays `- [ ]` with a `**⚠️ PARTIAL —**` note + `DEFERRED.md` pointer per memory `feedback_strict_task_completion.md`.
- [ ] T047 [P] Run the `quickstart.md` §12 grep gates (SC-014 + Constitution IX/V/VI): zero new pubspec deps; no role/permission branch in `lib/features/favorites/`; no `package:supabase_flutter` under `domain/`+`presentation/`; no inline `Text('…')` literals; no inline hex/font-size in favorites widgets. All must return no matches.
- [ ] T048 [P] Confirm `lib/features/favorites/` follows Clean Architecture layering and the `lead_events` table schema is unchanged (FR-033). Update `specs/017-favorites/DEFERRED.md` only if a partial was recorded in T046.

**Phase Checkpoint**: All SCs ticked (or partials logged); all grep gates pass; the feature is reviewer-verifiable end-to-end.

---

## Dependencies & Story Mapping

- **Setup/foundational**: Phase 1 (route + skeleton) is the only true prerequisite for the Flutter layers; Phase 2 is the prerequisite for all backend work.
- **By user story**:
  - **US1 (toggle anywhere)** — Phases 2,3,4 (table/policies/RPC) + Phase 5 (use cases) + Phase 6 (cubit + heart) + Phase 8 (4 surfaces). MVP-critical.
  - **US2 (FavoritesPage)** — Phase 3 (view) + Phase 5 (`loadFavorites`) + Phase 6 (page/bloc/empty-state) + Phase 8 (Profile tile).
  - **US3 (self-only privacy)** — Phase 2 (RLS enable) + Phase 3 (policies + invoker view). Verified in T014 + T046.
  - **US4 (persistence)** — emergent from the server-side table (Phase 2) + cubit hydration (Phase 6/8). Verified in T046.
  - **US5 (favorite_added event)** — Phase 4 (RPC dedup). Verified in T019 + T046.
  - **US6 (anonymous nudge)** — Phase 6 (heart anonymous branch) + Phase 7 (prompt string) + Phase 8 (surfaces). Verified in T046.

## Implementation Strategy (MVP first)

The MVP is **US1 + US3**: a working, private favorite toggle. Minimum path: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 (the FavoritesPage of US2 rides along in Phases 5/6/8). All 8 sub-phases ship in one PR per the one-PR-per-spec git contract.

---

# Multi-Agent Execution Plan

> These sections drive `/wave all --auto`. The orchestrator executes them WITHOUT re-deriving. Phase N ↔ Sub-Phase letter: 1=A, 2=B, 3=C, 4=D, 5=E, 6=F, 7=G, 8=H, 9=Polish.

## Touch-Fan Table

Shared files each phase modifies (the orchestrator warns sub-agents up front + merges least-touch-first):

- **Phase 1 (A)**: `lib/core/routing/app_router.dart`, `lib/features/favorites/domain/entities/favorite.dart` (new), `lib/features/favorites/presentation/pages/favorites_page.dart` (new stub)
- **Phase 2 (B)**: `supabase/migrations/20260529120001_create_favorites_table.sql` (new), `supabase/docs/favorites.md` (new)
- **Phase 3 (C)**: `supabase/migrations/20260529120002_create_favorites_policies.sql` (new), `supabase/migrations/20260529120003_create_v_favorites_view.sql` (new), `supabase/docs/favorites.md` (append — shared with Phase 2)
- **Phase 4 (D)**: `supabase/migrations/20260529120004_create_add_favorite_rpc.sql` (new), `supabase/migrations/20260529120005_phase17_advisor_hardening.sql` (new)
- **Phase 5 (E)**: all-new files under `lib/features/favorites/{domain,data}/`, `lib/core/di/injection.config.dart` (regenerated — shared with Phase 6)
- **Phase 6 (F)**: all-new files under `lib/features/favorites/presentation/`, `lib/core/di/injection.config.dart` (regenerated — shared with Phase 5)
- **Phase 7 (G)**: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations*.dart` (regenerated)
- **Phase 8 (H)**: `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart`, `lib/features/listing_details/presentation/pages/listing_details_page.dart`, `lib/features/home/presentation/widgets/home_listing_card.dart`, `lib/features/search/presentation/widgets/search_result_card.dart`, `lib/features/map/presentation/widgets/marker_preview_popover.dart`, `lib/features/profile/presentation/pages/profile_page.dart`, `lib/features/home/presentation/pages/home_page.dart` (7 existing files, one edit each, across 5 feature folders — conflict-isolated)
- **Phase 9 (Polish)**: no source edits (verification only); may touch `specs/017-favorites/DEFERRED.md` if a partial is logged

**Merge-order hint (least-touch-first)**: Phase 2 → Phase 4 → Phase 3 (3 shares `favorites.md` with 2) → Phase 1 → Phase 7 → Phase 5 → Phase 6 (6 shares `injection.config.dart` with 5; merge 5 then 6) → Phase 8 → Phase 9. The only intra-feature shared files are `supabase/docs/favorites.md` (Phases 2+3) and `injection.config.dart` (Phases 5+6, both regenerated — re-run `build_runner` after merge rather than hand-merging). Phase 8's seven edits live in distinct files across five feature folders → near-zero conflict.

## Dependency Audit

Re-reading plan.md §Phase Dependencies; one sentence per declared edge naming the specific consumed symbol/file. Any edge without a nameable consumer would be false and removed — none are.

- **Phase 3 → Phase 2**: the `favorites_select_self`/`favorites_delete_self` policies and `v_favorites` view attach to / select from the `public.favorites` table defined in `20260529120001_create_favorites_table.sql`. **Real.**
- **Phase 4 → Phase 2**: `add_favorite`'s `INSERT … ON CONFLICT (user_id, listing_id) DO NOTHING` targets the `public.favorites` table + its composite PK from `20260529120001_create_favorites_table.sql`. **Real.**
- **Phase 5 → Phase 3**: `SupabaseFavoritesDatasource.loadFavorites()` selects from `public.v_favorites` (`20260529120003`); `loadFavoriteIds()`/`removeFavorite()` rely on the `favorites_select_self`/`favorites_delete_self` policies (`20260529120002`). **Real.**
- **Phase 5 → Phase 4**: `SupabaseFavoritesDatasource.addFavorite()` invokes `public.add_favorite(uuid)` from `20260529120004_create_add_favorite_rpc.sql`. **Real.**
- **Phase 6 → Phase 1**: `FavoriteHeartButton.onTap`'s anonymous branch navigates to `AppRoutes.login`, and `FavoritesPage` is registered at `AppRoutes.favorites` — both constants added to `lib/core/routing/app_router.dart` in Phase 1. **Real.**
- **Phase 6 → Phase 5**: `FavoritesCubit` injects `LoadFavoriteIds`/`AddFavorite`/`RemoveFavorite` and `FavoritesPageBloc` injects `LoadFavorites` (use cases at `lib/features/favorites/domain/usecases/*.dart`); `FavoritesPage` renders `FavoriteListing` (`…/domain/entities/favorite_listing.dart`) — all from Phase 5. **Real.**
- **Phase 6 → Phase 7**: `FavoritesPage`/`FavoriteHeartButton`/`FavoritesEmptyState` read `l10n.favorites_page_title`/`favorite_sign_in_prompt`/`favorites_empty_state`/`favorite_unavailable_indicator` generated in `lib/l10n/app_localizations.dart` by Phase 7. **Real.**
- **Phase 8 → Phase 1**: the Profile tile's `onTap` uses `AppRoutes.favorites` from `lib/core/routing/app_router.dart` (Phase 1). **Real.**
- **Phase 8 → Phase 6**: all four surfaces embed `FavoriteHeartButton` (`…/presentation/widgets/favorite_heart_button.dart`) and H1/H6 consume `FavoritesCubit` (`…/presentation/bloc/favorites_cubit.dart`), both from Phase 6. **Real.**
- **Phase 8 → Phase 7**: the Profile tile reads `l10n.profile_favorites_tile`, and the embedded hearts read the heart/prompt strings — generated by Phase 7. **Real.**
- **Phase 9 → Phases 1–8**: the SC matrix + grep gates exercise the shipped feature end-to-end; depends on everything. **Real (verification gate).**

Edges deliberately ABSENT (proving the graph is not pessimistic): Phase 3 does **not** depend on Phase 4 (the `v_favorites` view does NOT call `add_favorite` — no view→function coupling, unlike Phase 16), so C ∥ D. Phase 7 (l10n) depends on nothing. Phase 2 depends on nothing (the table FKs target pre-existing Phase 1/10 artifacts, not any Phase 17 sub-phase).

## Wave Plan

Topological sort (each wave = phases whose deps are all in earlier waves), cap 4 per wave:

- **Wave 1**: Phase 1, Phase 2, Phase 7  *(no unmet deps — route/skeleton, table, l10n)*
- **Wave 2**: Phase 3, Phase 4  *(both depend only on Phase 2)*
- **Wave 3**: Phase 5  *(depends on Phase 3 + Phase 4)*
- **Wave 4**: Phase 6  *(depends on Phase 1 + Phase 5 + Phase 7)*
- **Wave 5**: Phase 8  *(depends on Phase 1 + Phase 6 + Phase 7)*
- **Wave 6**: Phase 9  *(depends on all — final verification)*

All waves ≤ 4 phases; no tests-only/docs-only cap exception needed. Wave 3–5 are single-phase because the Flutter layers are a strict chain (data → presentation → wiring); this is genuine, not pessimism (Wave 1 fans 3-wide, Wave 2 fans 2-wide).

## Model Routing per Phase

- **Phase 1: Sonnet** (route slot + scaffolding + a trivial entity).
- **Phase 2: Sonnet** (plain table DDL + index; RLS only enabled, no policy logic).
- **Phase 3: Opus** (self-only RLS policies + SECURITY INVOKER view — the load-bearing privacy boundary; RLS heuristic).
- **Phase 4: Opus** (SECURITY DEFINER RPC with an atomic, deduped favorite + lead-event co-transaction and invariant enforcement; atomic-transaction/RLS heuristic).
- **Phase 5: Sonnet** (domain entities, repository, DAO-style datasource CRUD, DTO).
- **Phase 6: Sonnet** (BLoC/Cubit + widgets; optimistic-revert is standard client state, no server invariant).
- **Phase 7: Sonnet** (l10n ARB keys).
- **Phase 8: Sonnet** (widget embedding + a Profile tile + a cubit-hydration touch).
- **Phase 9: Sonnet** (manual SC verification + grep gates + docs).
