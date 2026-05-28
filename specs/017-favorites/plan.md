# Implementation Plan: Favorites

**Branch**: `017-favorites` | **Date**: 2026-05-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/017-favorites/spec.md`

## Summary

Phase 17 ships the private saved-listings capability: the working implementation of the Favorite heart that Phase 13 left as a Coming-soon stub (the leftmost CTA in `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart`), a heart affordance on every listing-card surface, a dedicated FavoritesPage reached from a Profile tile, and the first `favorite_added` lead events written into the substrate Phase 16 reserved. The plan ships: (a) one new Supabase migration creating `public.favorites` — a composite-PK `(user_id, listing_id)` table with `user_id → auth.users(id) ON DELETE CASCADE`, `listing_id → public.listings(id) ON DELETE RESTRICT` (Q4=C precedent), `created_at`, RLS enabled, and an index on `(user_id, created_at DESC)` for the FavoritesPage read; (b) self-only RLS policies (`favorites_select_self`, `favorites_delete_self`, both `USING (user_id = auth.uid())`) with NO INSERT grant to `authenticated`/`anon` (row creation flows exclusively through the RPC so a client cannot create a favorite that bypasses the co-transactional event), and NO cross-user/admin/anonymous reader path per FR-017..FR-019; (c) a `public.add_favorite(p_listing_id uuid)` SECURITY DEFINER RPC that requires an authenticated session, validates the listing exists and is `status='approved'`, idempotently inserts the `favorites` row, and — only when no `favorite_added` lead event already exists for `(auth.uid(), p_listing_id)` per Q3=B — atomically inserts one `favorite_added` `lead_events` row in the same transaction; (d) a `public.v_favorites` SECURITY INVOKER view joining `favorites` → `listings` (+ primary price + main image + governorate/city names) projecting the card fields the FavoritesPage renders PLUS a computed `is_available` flag (`status='approved' AND publish-window`) so the page can show a localized "no longer available" indicator for favorites whose listing has left `approved` per FR-025 — the view inherits the favorites base-table self-only RLS so it leaks no other user's rows; (e) a new Flutter feature folder `lib/features/favorites/` containing the `Favorite` + `FavoriteListing` domain entities, the `FavoritesRepository` interface + impl, the datasource, four use cases (`AddFavorite`, `RemoveFavorite`, `LoadFavoriteIds`, `LoadFavorites`), the `FavoritesCubit` (a `@lazySingleton` holding the session set of the signed-in user's favorited listing ids, hydrated on sign-in and cleared on sign-out, mirroring Phase 16's `InquiriesUnreadCubit` shared-singleton pattern), the `FavoritesPageBloc`, the `FavoritesPage`, and a shared `FavoriteHeartButton` widget; (f) wiring of the heart into the FOUR surfaces that render listings — `HomeListingCardTile` (Phase 13), `SearchResultCard` (Phase 14), `MarkerPreviewPopover` (Phase 15), and the `PerListingActionBlock` Favorite CTA (Phase 13) — each embedding the shared `FavoriteHeartButton` so a single toggle behavior + a single session set drive consistent state across all surfaces per FR-002 + FR-005; (g) a "My Favorites" `ListTile` on the Phase 5 Profile page (per Q1=A) navigating to a new `/favorites` route, plus the anonymous-tap path (per Q2=A) that renders the heart for everyone but routes a signed-out tapper into the Phase 5 login flow with a localized "Sign in to save favorites" prompt; (h) ARB-driven localization for ~8 new bilingual keys (heart accessibility label, sign-in prompt, FavoritesPage title + empty-state, "no longer available" indicator, Profile tile label, toggle-failure error). Phase 17 adds ZERO new pubspec dependencies (FR-030) and ZERO schema changes to `public.lead_events` (it consumes the reserved `favorite_added` enum value as-is). Principles I (Spec-First) and III (Security-First Supabase) are the load-bearing gates.

**Technical approach**: Favorites follow the same Clean Architecture layering as Phases 13–16 (`presentation/bloc` → `domain/usecases` → `domain/repositories` → `data/repositories` → `data/datasources` → `core/network`). Two security boundaries are load-bearing. First, the **self-only privacy boundary** (Principle III + FR-017..FR-019): RLS on `public.favorites` filters every SELECT and DELETE by `user_id = auth.uid()`, so a forged `WHERE user_id = '<other>'` returns zero rows and there is no admin override permission — favorites are strictly the owner's. The `v_favorites` view is declared `SECURITY INVOKER` (the Phase 16 `enable_security_invoker` precedent) so the base-table RLS applies to view reads too; the view projects only public-safe listing columns (title, price, image, location, status) and never any publisher private field. Second, the **bypass-proof event boundary** (FR-011 + FR-015): row creation is performed ONLY by the `add_favorite` SECURITY DEFINER RPC, which co-transactionally inserts the favorite and (conditionally) the `favorite_added` event; because no direct client INSERT grant exists on `public.favorites`, a client physically cannot create a favorite without going through the dedup'd-event path. The dedup ("once per (user, listing) ever" per Q3=B) is a `SELECT 1 FROM public.lead_events WHERE user_id = auth.uid() AND listing_id = p_listing_id AND event_type = 'favorite_added'` guard inside the RPC — the `lead_events` table is the prior-favorite memory, so the favorites table stays a simple hard-delete toggle with no `is_active` column. Removal is a direct self-only `DELETE` (Q5=A) — it emits no event and needs no co-transactional work, so an RPC would be empty ceremony. The cross-surface consistency (FR-005) is delivered by a `FavoritesCubit` `@lazySingleton` that holds the signed-in user's favorited-id `Set<String>`, hydrated once on sign-in via `LoadFavoriteIds` and cleared on sign-out (it subscribes to `AuthBloc`); every `FavoriteHeartButton` is a `BlocSelector` keyed on its `listingId`, so a toggle on any surface re-emits the set and all visible hearts reconcile without per-card server reads. The toggle is optimistic: the cubit mutates the set immediately, calls the use case, and reverts the set on failure (FR-006). The anonymous path is handled in `FavoriteHeartButton.onTap`: if `AuthBloc.state` is `Unauthenticated`, it shows the localized prompt and `context.push(AppRoutes.login)` instead of toggling — no pre-auth state is persisted (FR-009). The FavoritesPage is a paginated `ListView` (cursor on `favorites.created_at DESC`, matching Phase 13's home-feed convention) reading `v_favorites`; available rows render the standard card composition and unavailable rows add the "no longer available" indicator but stay tappable (Q4=A — they route to the Phase 13 details page, which already renders the read-only / `_NotFoundView` state for terminal/deleted listings).

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase) / PL/pgSQL.

**Primary Dependencies**: NONE added in Phase 17 (per FR-030 + R-109). Favorites are built entirely from the inherited stack already in `pubspec.yaml`: `flutter`, `flutter_localizations`, `supabase_flutter`, `flutter_bloc`, `go_router`, `get_it`, `injectable`, `intl`, `cached_network_image`, `equatable` (+ the Phase 15/16 packages, none of which Phase 17 touches).

**Storage**: Supabase Postgres adds ONE new table — `public.favorites` — under `supabase/migrations/`. It references `public.listings(id)` (Phase 10) with `ON DELETE RESTRICT` per Q4=C and `auth.users(id)` (Phase 1 baseline) with `ON DELETE CASCADE` (the `user_preferences` precedent in `supabase/migrations/20260506120003_create_user_preferences.sql`). Phase 17 adds one SECURITY DEFINER PL/pgSQL function (`add_favorite`), one SECURITY INVOKER view (`v_favorites`), and two self-only RLS policies. It writes to `public.lead_events` (Phase 16, `supabase/migrations/20260527120002_create_lead_events_table.sql`) via the RPC but makes ZERO schema change to it — the `favorite_added` value already exists in its `event_type` CHECK constraint. No new extension is enabled.

**Testing**: Per project convention (memory `feedback_no_new_tests.md`), no new automated tests are added in Phase 17. Existing tests remain. Manual UI verification on the reference Infinix Note 8 + Pixel 8 Pro AVD (per memory `user_test_device.md` + `feedback_avd_acceptable_qa.md`) is the gate; `quickstart.md` captures the recipe — including the load-bearing two-user wire-level capture confirming cross-user favorites isolation (SC-005) and the forged-`user_id` INSERT/DELETE rejection (SC-006).

**Target Platform**: Android only (Constitution Principle XI). Reference device: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11); Pixel 8 Pro emulator (Android 14, 412 dp width) for secondary checks.

**Project Type**: Mobile app (Flutter) + Supabase backend — existing layout per `lib/features/<feature>/{presentation,domain,data}/` and `supabase/{migrations,docs}/`.

**Performance Goals**:

- Heart tap → optimistic fill/empty within 300 ms; favorites row written/deleted within 2 s (SC-001, SC-002).
- Cross-surface heart-state reconcile is instant (in-memory `Set<String>` lookup; no server round-trip per card) (SC-003, FR-005).
- FavoritesPage initial load → first paint within 2 s on a standard Syrian 4G connection (cursor query on indexed `(user_id, created_at DESC)`).
- FavoritesCubit hydration on sign-in → one `loadFavoriteIds()` read returning the id list, completing within 1 s for a normal favorites count.

**Constraints**:

- A user's favorites MUST be readable ONLY by that user — no publisher, no admin, no anonymous, no aggregate save-count (FR-017..FR-019 + SC-005). Enforced by self-only RLS on `public.favorites` and a `SECURITY INVOKER` `v_favorites` view inheriting that RLS. No `favorites.view_all` permission is introduced.
- A favorite MUST NOT be creatable in a way that bypasses the `favorite_added` event path (FR-011). Enforced by granting NO direct client INSERT on `public.favorites` — row creation is exclusively via the `add_favorite` SECURITY DEFINER RPC.
- The `favorite_added` event MUST fire at most once per `(user_id, listing_id)` across all time (Q3=B + FR-015). Enforced by a dedup `SELECT` against `public.lead_events` inside the RPC, in the same transaction as the favorite insert.
- Un-favorite MUST be a hard delete emitting no event (Q3=B + FR-016), performed via a self-only `DELETE` RLS policy (Q5=A) — no `remove_favorite` RPC.
- The favorite row insert + conditional event insert MUST be atomic (FR-014 + SC-008) — guaranteed by wrapping both in the single PL/pgSQL RPC body.
- The heart MUST render for anonymous visitors and route them to sign-in on tap, with no pre-auth auto-save (Q2=A + FR-008 + FR-009).
- The FavoritesPage MUST show favorites whose listing is no longer `approved` with a "no longer available" indicator and keep them tappable → Phase 13 details (Q4=A + FR-025); it MUST paginate (FR-027).
- Constitution IX-clean: no `package:supabase_flutter` import outside `lib/features/favorites/data/`. The `Favorite`, `FavoriteListing`, `FavoritesRepository` types live in `domain/` and import zero Supabase types.
- Constitution V (Arabic-first) + VI (design tokens): all ~8 new strings flow through ARB (`ar` + `en`); the `FavoriteHeartButton`, FavoritesPage, empty-state, and indicator read Phase 2 tokens — no inline hex/font/padding.
- The Phase 13 `PerListingActionBlock` Favorite CTA IS modified by Phase 17 (its Coming-soon snackbar handler is replaced) per FR-001; its Share + Report CTAs MUST remain Phase 13 stubs and the surrounding widget tree MUST NOT be reflowed (FR-033).

**Scale/Scope**:

- 8 sub-phases (A–H) organized into 4 waves with parallel execution where the dependency graph permits.
- 5 new Supabase migrations: 1 table (`20260529120001`), 2 policy/view (`...120002` policies, `...120003` view), 1 RPC (`...120004`), 1 advisor-hardening (`...120005`). 0 schema changes to existing tables.
- 1 new Flutter feature folder (`lib/features/favorites/`) with ~17 new Dart files (2 entities + 1 repository interface + 4 use cases + 1 DTO + 1 datasource + 1 repository impl + 1 cubit + 3 bloc files [bloc/event/state] + 1 page + 1 `FavoriteHeartButton` widget + 1 empty-state widget). 6 existing files updated (`app_router.dart`, `profile_page.dart`, `per_listing_action_block.dart`, `home_listing_card.dart`, `search_result_card.dart`, `marker_preview_popover.dart`) + 1 home-shell wiring file for cubit hydration. ZERO new pubspec dependencies.
- ~8 new bilingual ARB keys (Arabic + English) — final breakdown in Sub-Phase G.
- 10 plan-time research decisions (R-109 through R-118) resolved in `research.md`.
- 6 contract files in `contracts/` covering the `favorites` table, the policies, the `v_favorites` view, the `add_favorite` RPC, the `FavoriteHeartButton` + `FavoritesCubit` toggle contract, and the FavoritesPage composition + entry-point wiring.

---

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `specs/017-favorites/spec.md` exists with 6 user stories, 33 FRs (FR-001..FR-033), 15 SCs, 6 clarifications resolved (3 in `/speckit-specify`: Q1 Profile-tile entry, Q2 anonymous prompt-on-tap, Q3 hard-delete + once-per-pair event; 3 in `/speckit-clarify`: Q4 unavailable-card navigates anyway, Q5 self-only DELETE RLS, Q6 heart on all surfaces incl. map preview). This plan + data-model + contracts + quickstart land before any implementation. |
| II. Source-Controlled Backend | **Pass** | All 5 backend artifacts (1 table, 2 policies, 1 view, 1 RPC, 1 advisor-hardening) are checked in as files under `supabase/migrations/`; per-table doc lands at `supabase/docs/favorites.md`. The Supabase MCP `apply_migration` applies them; the migration files are the source of truth. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS enabled on `public.favorites` with self-only SELECT + DELETE policies (`user_id = auth.uid()`); NO INSERT grant to `authenticated`/`anon` (creation only via the SECURITY DEFINER `add_favorite` RPC). The `v_favorites` view is `SECURITY INVOKER` so the base-table self-only RLS applies to view reads, and it projects zero publisher private fields. No `favorites.view_all` permission exists — there is no cross-user/admin reader path (FR-019). No service-role key on the client. The `add_favorite` RPC uses `SET search_path = pg_catalog, public` per the Phase 9/10/16 advisor-hardening convention. |
| IV. Clean Architecture Flutter | **Pass** | `lib/features/favorites/` uses the standard 3 layers: `presentation/{bloc,pages,widgets}/`, `domain/{entities,repositories,usecases}/`, `data/{datasources,models,repositories}/`. Business rules (toggle/optimistic-revert, session-set hydration, anonymous-prompt routing, availability computation) live in `domain/` use cases + the `FavoritesCubit`. `FavoritesCubit` and `FavoritesPageBloc` extend Cubit/BLoC per Constitution IV. |
| V. Arabic-First Localization | **Pass** | ~8 new strings (`favorite_heart_label`, `favorite_unsave_label`, `favorite_sign_in_prompt`, `favorites_page_title`, `favorites_empty_state`, `favorite_unavailable_indicator`, `profile_favorites_tile`, `favorite_toggle_failed`) land in BOTH `app_ar.arb` AND `app_en.arb` in Sub-Phase G. No inline `Text('...')` literals in any new feature code (grep gate in quickstart). Arabic copy is Syrian-friendly (e.g., "المفضلة" for Favorites, "سجّل الدخول لحفظ العقار" for the sign-in prompt). |
| VI. Theme System & Design Tokens | **Pass** | `FavoriteHeartButton` (filled/empty heart with the error/primary token for the filled state), FavoritesPage, empty-state widget, and the "no longer available" indicator all read `Theme.of(context).colorScheme` + `AppSpacing` + `AppRadii`. No inline hex literals, no raw pixel constants. The Profile "My Favorites" `ListTile` matches the existing `profile_private_section` tile's token usage. |
| VII. Dynamic Roles & Permissions | **Pass** | Favorites are self-only by RLS, not by any role/permission branch. Phase 17 introduces NO permission (no `favorites.view_all`) and NO hardcoded role check — verified by SC-014's grep gate. There is no admin surface for favorites. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Favorites can be created only against `status='approved'` listings (enforced by the `add_favorite` RPC's listing-validity check per FR-011, mirroring Phase 16's `record_lead_event`). No publisher private field is read or projected by `v_favorites`. A favorite reveals nothing about the publisher; no save-count is exposed. |
| IX. Future Backend Portability | **Pass** | `Favorite`, `FavoriteListing`, `FavoritesRepository` live in `lib/features/favorites/domain/` and import zero `package:supabase_flutter` / zero Supabase types. Concrete Supabase access lives in `lib/features/favorites/data/datasources/supabase_favorites_datasource.dart` behind the interface. A grep gate in quickstart verifies no Supabase import under `domain/` or `presentation/`. |
| X. Testable AI Workflow | **Pass** | Every Phase 2 task (tasks.md, forthcoming) carries acceptance criteria derived from the FRs + SCs. `quickstart.md` captures one verification step per SC, including the two-user wire-level cross-user-isolation capture (SC-005) and the forged-`user_id` write-rejection check (SC-006). The `/wave` orchestrator uses the Touch-fan notes below for conflict-free merge order. |
| XI. Android-First MVP | **Pass** | Zero new dependencies; zero new platform code. No iOS/Web/desktop. The heart is pure Flutter Material; the favorites table + RPC are standard Postgres. No Android manifest change. |
| XII. No Hidden Product Decisions | **Pass** | All 6 clarifications (3 specify + 3 clarify) are recorded in `spec.md`'s Clarifications section with rationale. The 10 plan-time decisions (R-109..R-118) are recorded in `research.md`. Forward-stated deferrals (saved searches, collections/folders, popularity/save-count, price-drop notifications) are explicit in `spec.md` Assumptions + this plan. No silent picks: the shared-cubit consistency mechanism, the `v_favorites` availability flag, the dedup-via-lead_events approach, and the Profile-tile placement are all explicitly decided in `research.md`. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

---

## Project Structure

### Documentation (this feature)

```text
specs/017-favorites/
├── plan.md                     # This file (/speckit-plan output)
├── spec.md                     # /speckit-specify + /speckit-clarify output (committed)
├── research.md                 # Phase 0 output (R-109..R-118)
├── data-model.md               # Phase 1 output (full SQL migration bodies + Dart entities + FR/SC verification map)
├── quickstart.md               # Phase 1 output (end-to-end manual recipe)
├── contracts/
│   ├── phase17-favorites-table.md
│   ├── phase17-favorites-policies.md
│   ├── phase17-v-favorites-view.md
│   ├── phase17-add-favorite-rpc.md
│   ├── phase17-favorite-heart-toggle.md
│   └── phase17-favorites-page-and-entry-points.md
└── checklists/
    └── requirements.md         # /speckit-specify quality checklist (committed)
```

### Source Code (repository root)

```text
H:\alnujom-project\
├── lib/
│   ├── core/
│   │   ├── routing/
│   │   │   └── app_router.dart                                       # UPDATE — add AppRoutes.favorites + AppRouteNames.favorites + GoRoute (anon deep-link → login redirect)
│   │   └── widgets/
│   │       └── deep_link_aware_back_button.dart                      # READ-ONLY — consumed by FavoritesPage AppBar leading; no edit
│   ├── features/
│   │   ├── favorites/                                                # CREATE — new feature folder
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   └── supabase_favorites_datasource.dart            # CREATE
│   │   │   │   ├── models/
│   │   │   │   │   └── favorite_listing_dto.dart                     # CREATE
│   │   │   │   └── repositories/
│   │   │   │       └── favorites_repository_impl.dart                # CREATE
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── favorite.dart                                 # CREATE (Sub-Phase A)
│   │   │   │   │   └── favorite_listing.dart                         # CREATE
│   │   │   │   ├── repositories/
│   │   │   │   │   └── favorites_repository.dart                     # CREATE
│   │   │   │   └── usecases/
│   │   │   │       ├── add_favorite.dart                             # CREATE
│   │   │   │       ├── remove_favorite.dart                          # CREATE
│   │   │   │       ├── load_favorite_ids.dart                        # CREATE
│   │   │   │       └── load_favorites.dart                           # CREATE
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       │   ├── favorites_cubit.dart                          # CREATE (session favorited-id set; @lazySingleton)
│   │   │       │   ├── favorites_page_bloc.dart                      # CREATE
│   │   │       │   ├── favorites_page_event.dart                     # CREATE
│   │   │       │   └── favorites_page_state.dart                     # CREATE
│   │   │       ├── pages/
│   │   │       │   └── favorites_page.dart                           # CREATE (stub in A; fills in F)
│   │   │       └── widgets/
│   │   │           ├── favorite_heart_button.dart                    # CREATE (shared; consumed by all 4 surfaces)
│   │   │           └── favorites_empty_state.dart                    # CREATE
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── widgets/
│   │   │       │   └── home_listing_card.dart                        # UPDATE — embed FavoriteHeartButton overlay on _Hero
│   │   │       └── pages/
│   │   │           └── home_page.dart                                # UPDATE — hydrate FavoritesCubit on first build + auth-resume
│   │   ├── search/
│   │   │   └── presentation/widgets/
│   │   │       └── search_result_card.dart                           # UPDATE — embed FavoriteHeartButton
│   │   ├── map/
│   │   │   └── presentation/widgets/
│   │   │       └── marker_preview_popover.dart                       # UPDATE — embed FavoriteHeartButton (Q6=B)
│   │   ├── listing_details/
│   │   │   └── presentation/widgets/
│   │   │       └── per_listing_action_block.dart                     # UPDATE — wire Favorite CTA (Share/Report stay stubs)
│   │   └── profile/
│   │       └── presentation/pages/
│   │           └── profile_page.dart                                 # UPDATE — add "My Favorites" ListTile → /favorites
│   └── l10n/
│       ├── app_ar.arb                                                # UPDATE — add ~8 Arabic keys
│       └── app_en.arb                                                # UPDATE — add same ~8 English keys
└── supabase/
    ├── migrations/
    │   ├── 20260529120001_create_favorites_table.sql                 # CREATE
    │   ├── 20260529120002_create_favorites_policies.sql              # CREATE
    │   ├── 20260529120003_create_v_favorites_view.sql                # CREATE
    │   ├── 20260529120004_create_add_favorite_rpc.sql                # CREATE
    │   └── 20260529120005_phase17_advisor_hardening.sql              # CREATE
    └── docs/
        └── favorites.md                                              # CREATE
```

**Structure Decision**: Phase 17 adds one new feature folder (`lib/features/favorites/`) following the Phases 5–16 Clean Architecture pattern. Six existing files receive minimal entry-point patches (`app_router.dart` route slot, `profile_page.dart` tile, and four card/detail widgets embedding the shared `FavoriteHeartButton`), plus `home_page.dart` for cubit hydration. Five new Supabase migrations land under `supabase/migrations/` (timestamp prefix `20260529`, continuing after Phase 16's `20260527120016`; the IMPLEMENTATION_PLAN's logical name `0026_create_favorites.sql` maps to `20260529120001_create_favorites_table.sql` under the repo's timestamp convention). ZERO new pubspec dependencies. The live feed/search/map cards are bespoke widgets (`HomeListingCardTile`, `SearchResultCard`, `MarkerPreviewPopover`) — NOT the Phase 2 `PropertyCard`, whose heart slot is design-system-only (used only in `lib/debug/theme_gallery_page.dart`); Phase 17 therefore introduces a shared `FavoriteHeartButton` widget that each bespoke card embeds (R-118), rather than routing through `PropertyCard`.

---

## Phase Dependencies

> **User-mandated discipline (per /speckit-plan invocation)**: Every "Sub-Phase B depends on Sub-Phase A" line below names the specific file path OR exported symbol that B consumes from A. Lines like "easier in sequence" or "uses concepts from" are FORBIDDEN. The self-audit table at the end counts undeclared-consumer deps (target: zero).

### Sub-Phase A — Bootstrap: route slot + domain skeleton

**Scope**:

1. Add route constants to `lib/core/routing/app_router.dart`: `AppRoutes.favorites = '/favorites'` + `AppRouteNames.favorites = 'favorites'`.
2. Register a `GoRoute` at `/favorites` → stub `FavoritesPage` (filled in Sub-Phase F), with a `redirect:` that returns `AppRoutes.login` when `authBloc.state is Unauthenticated` (anonymous deep-link cold-launch hardening per R-115) and `null` otherwise.
3. Create skeleton directories under `lib/features/favorites/` for `data/{datasources,models,repositories}/`, `domain/{entities,repositories,usecases}/`, `presentation/{bloc,pages,widgets}/`.
4. Create `lib/features/favorites/domain/entities/favorite.dart` defining the `Favorite` entity (`Equatable`): `listingId` (String), `createdAt` (DateTime). This is the cross-layer primitive the data + presentation layers both type against.
5. Create stub `lib/features/favorites/presentation/pages/favorites_page.dart` rendering an empty `Scaffold` + `AppBar` so the `/favorites` route resolves end-to-end before Sub-Phase F fills it.

**In-spec deps**: none.

**Cross-phase deps**:

- A's `/favorites` redirect reads `authBloc.state is Unauthenticated` where `Unauthenticated` is defined in `lib/features/auth/presentation/bloc/auth_state.dart` (Phase 5) and the bloc is resolved the same way the existing `authRedirect` in `lib/core/routing/auth_redirect.dart` (Phase 5) resolves it. The file already exists; no churn.

**Touch fan**: `lib/core/routing/app_router.dart`, `lib/features/favorites/domain/entities/favorite.dart` (CREATE), `lib/features/favorites/presentation/pages/favorites_page.dart` (CREATE stub).

---

### Sub-Phase B — Backend schema: `favorites` table

**Scope**:

1. Create migration `supabase/migrations/20260529120001_create_favorites_table.sql`:
   - Table `public.favorites` with columns per FR-010: `user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`, `listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE RESTRICT` per Q4=C, `created_at timestamptz NOT NULL DEFAULT now()`, and `PRIMARY KEY (user_id, listing_id)` so a user cannot double-save a listing (the composite PK is the uniqueness constraint of FR-007).
   - Index per FR-013: `CREATE INDEX idx_favorites_user_created ON public.favorites (user_id, created_at DESC)` for the FavoritesPage newest-first read.
   - `ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY` (policies land in Sub-Phase C).
2. Create `supabase/docs/favorites.md` documenting columns, the composite-PK uniqueness rule, the FK delete behaviors, the self-only RLS posture (forward-stated; populated by Sub-Phase C), and the "creation-via-RPC-only / removal-via-DELETE-policy" write model.

**In-spec deps**: none.

**Cross-phase deps**:

- B's `favorites.listing_id` references `public.listings(id)` defined in `supabase/migrations/20260519120002_create_listings.sql` (Phase 10).
- B's `favorites.user_id` references `auth.users(id)` (Phase 1 Supabase baseline); the `ON DELETE CASCADE` mirrors the FK pattern in `supabase/migrations/20260506120003_create_user_preferences.sql` (Phase 4).

**Touch fan**: `supabase/migrations/20260529120001_create_favorites_table.sql` (CREATE), `supabase/docs/favorites.md` (CREATE).

---

### Sub-Phase C — Backend policies + `v_favorites` view

**Scope**:

1. Create migration `supabase/migrations/20260529120002_create_favorites_policies.sql`:
   - SELECT policy `favorites_select_self`: `USING (user_id = auth.uid())`.
   - DELETE policy `favorites_delete_self`: `USING (user_id = auth.uid())` (the client's removal path per Q5=A + FR-012).
   - INSERT: NOT granted — `REVOKE INSERT ON public.favorites FROM authenticated, anon`; row creation goes through the `add_favorite` SECURITY DEFINER RPC (Sub-Phase D) so a client cannot create a favorite that bypasses the co-transactional `favorite_added` event (FR-011 + FR-017).
   - UPDATE: blocked entirely (no policy; favorites are insert/delete-only — there is nothing to mutate on a favorite row).
2. Create migration `supabase/migrations/20260529120003_create_v_favorites_view.sql`:
   - View `public.v_favorites` declared with `WITH (security_invoker = true)` (the Phase 16 `20260527120013_phase16_view_invoker_lockdown.sql` precedent) so the base-table self-only RLS on `public.favorites` applies to view reads.
   - Projection joining `favorites f` → `listings l` (+ a LATERAL primary-price subquery + a LATERAL main-image subquery + governorate/city display-name joins, mirroring `v_listings_public` from `supabase/migrations/20260525120002_create_v_listings_public.sql`): `f.listing_id AS id`, `f.created_at AS favorited_at`, `l.title`, `l.property_type`, `l.purpose`, `lp.amount AS primary_amount`, `lp.currency_code AS primary_currency`, `lm.storage_path AS main_image_path`, `g.display_name->>'ar' AS governorate_name_ar`, `g.display_name->>'en' AS governorate_name_en`, `c.display_name->>'ar' AS city_name_ar`, `c.display_name->>'en' AS city_name_en`, and a computed `(l.status = 'approved' AND (l.expires_at IS NULL OR l.expires_at > now())) AS is_available` flag per FR-025. Crucially the view does NOT filter on `l.status` (unlike `v_listings_public`) — unavailable favorites MUST still appear (Q4=A + FR-025); the `is_available` flag drives the "no longer available" indicator.
   - `GRANT SELECT ON public.v_favorites TO authenticated`. NOT granted to `anon`.
3. Update `supabase/docs/favorites.md` with the RLS matrix + the view's `is_available` contract.

**In-spec deps**:

- C depends on Sub-Phase B — the `public.favorites` table defined in `20260529120001_create_favorites_table.sql` MUST exist before C's policies attach and before `v_favorites` selects from it.

**Cross-phase deps**:

- C's `v_favorites` selects `l.title / l.property_type / l.purpose / l.status / l.expires_at` from `public.listings` (Phase 10, `20260519120002_create_listings.sql`), `lp.amount / lp.currency_code` from `public.listing_prices`, `lm.storage_path` from `public.listing_media`, and `g.display_name / c.display_name` from `public.governorates` / `public.cities` (Phase 8) — the same column set `v_listings_public` (`20260525120002_create_v_listings_public.sql`) projects.

**Touch fan**: `supabase/migrations/20260529120002_create_favorites_policies.sql` (CREATE), `supabase/migrations/20260529120003_create_v_favorites_view.sql` (CREATE), `supabase/docs/favorites.md` (UPDATE — append RLS matrix + is_available contract).

---

### Sub-Phase D — Backend write path: `add_favorite` RPC + advisor hardening

**Scope**:

1. Create migration `supabase/migrations/20260529120004_create_add_favorite_rpc.sql`:
   - Function `public.add_favorite(p_listing_id uuid) RETURNS void` as `SECURITY DEFINER SET search_path = pg_catalog, public`.
   - Body: (a) `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000'; END IF;` (favorites are authenticated-only per FR-011); (b) validate `p_listing_id` references an existing listing with `status = 'approved'` — else `RAISE EXCEPTION 'listing_not_found'` (ERRCODE `23503`) or `'listing_not_approved'` (ERRCODE `23514`), mirroring `record_lead_event` (`20260527120010_create_record_lead_event_rpc.sql`); (c) `INSERT INTO public.favorites (user_id, listing_id) VALUES (auth.uid(), p_listing_id) ON CONFLICT (user_id, listing_id) DO NOTHING;` (idempotent re-favorite per FR-007); (d) dedup gate per Q3=B + FR-015: `IF NOT EXISTS (SELECT 1 FROM public.lead_events WHERE user_id = auth.uid() AND listing_id = p_listing_id AND event_type = 'favorite_added') THEN INSERT INTO public.lead_events (listing_id, user_id, event_type, metadata, created_at) VALUES (p_listing_id, auth.uid(), 'favorite_added', jsonb_build_object('ip', inet_client_addr()::text, 'user_agent', current_setting('request.headers', true)::jsonb->>'user-agent'), now()); END IF;` — both inserts in one function body so they atomically commit or roll back (FR-014).
   - `REVOKE ALL ON FUNCTION public.add_favorite(uuid) FROM PUBLIC; GRANT EXECUTE ON FUNCTION public.add_favorite(uuid) TO authenticated.` NOT granted to `anon` (anonymous users cannot favorite per FR-011).
2. Create migration `supabase/migrations/20260529120005_phase17_advisor_hardening.sql`:
   - Safety-net `ALTER FUNCTION public.add_favorite(uuid) SET search_path = pg_catalog, public;` + explicit `REVOKE ALL ... FROM PUBLIC` / re-`GRANT EXECUTE` to `authenticated`, matching the Phase 16 `20260527120012_phase16_advisor_hardening.sql` pattern. Confirm `REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon` (only SELECT + DELETE reach the client; INSERT is RPC-only) and `GRANT SELECT ON public.v_favorites TO authenticated`.

**In-spec deps**:

- D depends on Sub-Phase B — `add_favorite` writes to `public.favorites` (the table + its composite PK for the `ON CONFLICT` clause are defined in `20260529120001_create_favorites_table.sql`).

**Cross-phase deps**:

- D's `add_favorite` writes the `favorite_added` row into `public.lead_events` defined in `supabase/migrations/20260527120002_create_lead_events_table.sql` (Phase 16) — consuming the `favorite_added` value already present in that table's `event_type` CHECK constraint (no schema change).
- D's IP/UA capture reuses the `inet_client_addr()` + `current_setting('request.headers', true)::jsonb` pattern established in `20260527120010_create_record_lead_event_rpc.sql` (Phase 16).
- D consumes `auth.uid()` (Supabase Auth standard).

**Touch fan**: `supabase/migrations/20260529120004_create_add_favorite_rpc.sql` (CREATE), `supabase/migrations/20260529120005_phase17_advisor_hardening.sql` (CREATE).

---

### Sub-Phase E — Domain + data layer for the favorites feature

**Scope**:

1. Define `FavoriteListing` domain entity at `lib/features/favorites/domain/entities/favorite_listing.dart` (`Equatable`): `id` (String), `title` (String), `propertyType` (PropertyType — re-exported from Phase 10), `purpose` (ListingPurpose — Phase 10), `primaryAmount` (num), `primaryCurrency` (String), `mainImagePath` (String?), `governorateNameAr/_En`, `cityNameAr/_En` (String), `isAvailable` (bool — drives the FR-025 indicator), `favoritedAt` (DateTime).
2. Define `FavoritesRepository` abstract interface at `lib/features/favorites/domain/repositories/favorites_repository.dart`:
   - `Future<Result<Unit, Failure>> addFavorite(String listingId)`
   - `Future<Result<Unit, Failure>> removeFavorite(String listingId)`
   - `Future<Result<List<String>, Failure>> loadFavoriteIds()` — the signed-in user's favorited `listing_id`s, for the session set.
   - `Future<Result<List<FavoriteListing>, Failure>> loadFavorites({String? cursor, int limit = 30})` — the FavoritesPage page read.
3. Define four use cases at `lib/features/favorites/domain/usecases/`: `add_favorite.dart`, `remove_favorite.dart`, `load_favorite_ids.dart`, `load_favorites.dart` — each a single-method wrapper over the repository.
4. Define `FavoriteListingDto` at `lib/features/favorites/data/models/favorite_listing_dto.dart` mirroring the `v_favorites` row shape; `fromJson` + `toEntity()`.
5. Implement `SupabaseFavoritesDatasource` at `lib/features/favorites/data/datasources/supabase_favorites_datasource.dart`:
   - `addFavorite(listingId)` → `supabase.rpc('add_favorite', params: {'p_listing_id': listingId})`.
   - `removeFavorite(listingId)` → `supabase.from('favorites').delete().eq('listing_id', listingId)` (the `favorites_delete_self` RLS policy scopes it to the caller's own row; `user_id = auth.uid()` need not be sent by the client).
   - `loadFavoriteIds()` → `supabase.from('favorites').select('listing_id')` (self-only RLS returns only the caller's rows).
   - `loadFavorites({cursor, limit})` → `supabase.from('v_favorites').select().order('favorited_at', ascending: false)` with cursor pagination on `favorited_at`.
6. Implement `FavoritesRepositoryImpl` at `lib/features/favorites/data/repositories/favorites_repository_impl.dart`.
7. Register the 4 use cases + 1 repository + 1 datasource with `@injectable`; regenerate `lib/core/di/injection.config.dart` via `build_runner`.

**In-spec deps**:

- E depends on Sub-Phase C — `SupabaseFavoritesDatasource.loadFavorites()` issues `select()` against `public.v_favorites` (column projection defined in `20260529120003_create_v_favorites_view.sql` by C); `loadFavoriteIds()` + `removeFavorite()` issue `select()` / `delete()` against `public.favorites` gated by the `favorites_select_self` / `favorites_delete_self` policies defined in `20260529120002_create_favorites_policies.sql` by C.
- E depends on Sub-Phase D — `addFavorite()` invokes `public.add_favorite(uuid)` defined in `20260529120004_create_add_favorite_rpc.sql` by D.

**Cross-phase deps**:

- E imports `package:alnujom/core/errors/result.dart` + `package:alnujom/core/errors/failure.dart` (Phase 1) for the `Result<T, Failure>` return type (the same files Phase 16 consumed).
- E imports `package:alnujom/features/listing_form/domain/entities/listing.dart` (Phase 10) for the `PropertyType` + `ListingPurpose` enums typed on `FavoriteListing`.

**Touch fan**: `lib/features/favorites/domain/entities/favorite_listing.dart` (CREATE), `lib/features/favorites/domain/repositories/favorites_repository.dart` (CREATE), `lib/features/favorites/domain/usecases/add_favorite.dart` (CREATE), `lib/features/favorites/domain/usecases/remove_favorite.dart` (CREATE), `lib/features/favorites/domain/usecases/load_favorite_ids.dart` (CREATE), `lib/features/favorites/domain/usecases/load_favorites.dart` (CREATE), `lib/features/favorites/data/models/favorite_listing_dto.dart` (CREATE), `lib/features/favorites/data/datasources/supabase_favorites_datasource.dart` (CREATE), `lib/features/favorites/data/repositories/favorites_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase F — Presentation: FavoritesCubit + FavoriteHeartButton + FavoritesPage

**Scope**:

1. Implement `FavoritesCubit` at `lib/features/favorites/presentation/bloc/favorites_cubit.dart` as `@lazySingleton`:
   - State `FavoritesState({Set<String> favoritedIds, bool isSignedIn})`.
   - Subscribes to `AuthBloc` in its constructor: on transition to a signed-in state (`Authenticated`/`PendingApproval`/etc.), calls `LoadFavoriteIds` and emits the hydrated set with `isSignedIn = true`; on `Unauthenticated`, clears the set and emits `isSignedIn = false`.
   - `Future<void> toggle(String listingId)`: optimistically add/remove `listingId` in the set and emit; call `AddFavorite` or `RemoveFavorite`; on failure, revert the set and rethrow a flag the UI surfaces as the localized `favorite_toggle_failed` snackbar (FR-006).
   - `bool isFavorited(String listingId)` helper.
2. Implement `FavoriteHeartButton` at `lib/features/favorites/presentation/widgets/favorite_heart_button.dart`:
   - `BlocSelector<FavoritesCubit, FavoritesState, bool>` keyed on `isFavorited(listingId)` so only the relevant hearts rebuild on a set change (FR-005).
   - Renders `Icons.favorite` (filled, `colorScheme.error`) when favorited, `Icons.favorite_border` otherwise, reading Phase 2 tokens.
   - `onTap`: if `getIt<FavoritesCubit>().state.isSignedIn` is false (or `AuthBloc.state is Unauthenticated`), show the localized `favorite_sign_in_prompt` snackbar and `context.push(AppRoutes.login)` — NO toggle, no pre-auth state (FR-008 + FR-009 + Q2=A); else call `getIt<FavoritesCubit>().toggle(listingId)`.
3. Implement `FavoritesPageBloc` at `lib/features/favorites/presentation/bloc/favorites_page_bloc.dart` (+ `_event.dart`, `_state.dart`):
   - Events: `FavoritesPageOpened()`, `FavoritesPageRefreshRequested()`, `FavoritesPageMoreLoaded()`.
   - States: `FavoritesPageLoading`, `FavoritesPageLoaded({List<FavoriteListing> items, bool hasMore})`, `FavoritesPageError(failure)`.
   - Calls `LoadFavorites` with cursor pagination on `favoritedAt` (R-117).
4. Implement `FavoritesPage` at `lib/features/favorites/presentation/pages/favorites_page.dart` — replaces Sub-Phase A's stub. Composition: `AppBar` with `DeepLinkAwareBackButton` (Phase 15's extracted `lib/core/widgets/deep_link_aware_back_button.dart`) + title `l10n.favorites_page_title`; body is a `RefreshIndicator` over a `ListView.builder` of cards. Each card renders the listing's image/title/price/location with an embedded `FavoriteHeartButton` (filled); available cards tap → `context.push(AppRoutes.listingDetailsFor(item.id))`; unavailable cards (`!item.isAvailable`) render the localized `favorite_unavailable_indicator` overlay/badge but stay tappable → same details route (Q4=A + FR-025). Empty state via `FavoritesEmptyState` per FR-026 / SC-012.
5. Implement `FavoritesEmptyState` at `lib/features/favorites/presentation/widgets/favorites_empty_state.dart` — localized `favorites_empty_state` message + a heart illustration from Phase 2 tokens.
6. Register `FavoritesCubit` (`@lazySingleton`) + `FavoritesPageBloc` (`@injectable`); regenerate DI config.

**In-spec deps**:

- F depends on Sub-Phase A — `FavoritesPage` is registered at `AppRoutes.favorites` (constant in `lib/core/routing/app_router.dart` by A); the `FavoriteHeartButton.onTap` anonymous branch navigates to `AppRoutes.login` (Phase 5 constant, present in `app_router.dart`).
- F depends on Sub-Phase E — `FavoritesCubit` injects `LoadFavoriteIds`, `AddFavorite`, `RemoveFavorite` use cases at `lib/features/favorites/domain/usecases/*.dart` defined by E; `FavoritesPageBloc` injects `LoadFavorites` (same path); `FavoritesPage` renders `FavoriteListing` entities at `lib/features/favorites/domain/entities/favorite_listing.dart` defined by E.
- F depends on Sub-Phase G — all page chrome, heart accessibility label, sign-in prompt, empty-state, and unavailable indicator consume getters from `lib/l10n/app_localizations.dart` regenerated by G when the ARB keys land.

**Cross-phase deps**:

- F imports `lib/core/widgets/deep_link_aware_back_button.dart` (extracted in Phase 15) for the FavoritesPage AppBar `leading`.
- F imports `lib/features/auth/presentation/bloc/auth_bloc.dart` + `auth_state.dart` (Phase 5) — `FavoritesCubit` subscribes to `AuthBloc` for sign-in/sign-out hydration; `FavoriteHeartButton` reads `Unauthenticated` for the anonymous branch.
- F imports `lib/core/di/injection.dart` for `getIt<FavoritesCubit>()` lookups at the heart-button + page construction sites.

**Touch fan**: `lib/features/favorites/presentation/bloc/favorites_cubit.dart` (CREATE), `lib/features/favorites/presentation/bloc/favorites_page_bloc.dart` (CREATE), `lib/features/favorites/presentation/bloc/favorites_page_event.dart` (CREATE), `lib/features/favorites/presentation/bloc/favorites_page_state.dart` (CREATE), `lib/features/favorites/presentation/pages/favorites_page.dart` (UPDATE — replaces Sub-Phase A stub), `lib/features/favorites/presentation/widgets/favorite_heart_button.dart` (CREATE), `lib/features/favorites/presentation/widgets/favorites_empty_state.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase G — Localization: add ~8 bilingual ARB keys

**Scope**:

Add the following keys to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb`:

- `favorite_heart_label` (heart accessibility label, empty state — "Save listing" / "حفظ العقار").
- `favorite_unsave_label` (heart accessibility label, filled state — "Remove from favorites" / "إزالة من المفضلة").
- `favorite_sign_in_prompt` ("Sign in to save favorites" / "سجّل الدخول لحفظ العقار").
- `favorites_page_title` ("My Favorites" / "المفضلة").
- `favorites_empty_state` ("You haven't saved any listings yet" / "لم تقم بحفظ أي عقار بعد").
- `favorite_unavailable_indicator` ("No longer available" / "لم يعد متاحاً").
- `profile_favorites_tile` (Profile tile label — "My Favorites" / "المفضلة").
- `favorite_toggle_failed` (toggle-failure snackbar — "Couldn't update favorites. Try again." / "تعذّر تحديث المفضلة. حاول مجدداً.").

Total: ~8 keys (final count locked at sub-phase implementation time). After ARB updates, run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations.dart` + the per-locale getter classes.

**In-spec deps**: none.

**Cross-phase deps**:

- G runs `flutter gen-l10n` which regenerates `lib/l10n/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart` — consumed by Sub-Phase F (page + heart + empty-state) and Sub-Phase H (per_listing_action_block rewire + profile tile + card hearts).

**Touch fan**: `lib/l10n/app_ar.arb` (UPDATE), `lib/l10n/app_en.arb` (UPDATE), `lib/l10n/app_localizations.dart` (REGENERATED), `lib/l10n/app_localizations_ar.dart` (REGENERATED), `lib/l10n/app_localizations_en.dart` (REGENERATED).

---

### Sub-Phase H — Entry-point wiring: 4 card/detail surfaces + Profile tile + cubit hydration

**Scope**:

1. **H1 — Listing details Favorite CTA**: Update `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` per FR-001 — replace the Favorite CTA's `_showComingSoon(context, l10n.action_favorite_coming_soon)` handler with the real toggle. The cleanest treatment per the surrounding `_ActionButton` row is to keep the existing button shell but drive its icon/label/handler from `FavoritesCubit` (a `BlocSelector` on `isFavorited(listingId)`), with `onPressed` delegating to the same anonymous-aware toggle path as `FavoriteHeartButton`. The Share + Report `_ActionButton`s and the row layout are UNCHANGED (FR-033). `PerListingActionBlock`'s constructor gains `required String listingId`.
2. **H1b — Listing details consumer**: Update the `PerListingActionBlock()` call site in `lib/features/listing_details/presentation/pages/listing_details_page.dart` to pass `listingId: <aggregate listing id>`. (One-line change; no widget-tree reflow.)
3. **H2 — Home feed card heart**: Update `lib/features/home/presentation/widgets/home_listing_card.dart` `_Hero` — overlay a `PositionedDirectional(top: AppSpacing.sm, end: AppSpacing.sm, child: FavoriteHeartButton(listingId: card.id))` on the hero image `Stack` (the `_Hero` currently has no `Stack`; wrap its `AspectRatio` child in a `Stack` to host the heart).
4. **H3 — Search results card heart**: Update `lib/features/search/presentation/widgets/search_result_card.dart` — add a `FavoriteHeartButton(listingId: item.id)` to the card (e.g., top-end of the `_CardImage` via a `Stack`, or trailing the title row), preserving the 116 dp fixed-height layout.
5. **H4 — Map marker preview heart**: Update `lib/features/map/presentation/widgets/marker_preview_popover.dart` (per Q6=B) — add a `FavoriteHeartButton(listingId: marker.id)` to the popover (e.g., in the action `Row` next to the existing "View details" `TextButton`, or beside the close `IconButton`).
6. **H5 — Profile "My Favorites" tile**: Update `lib/features/profile/presentation/pages/profile_page.dart` — insert a `ListTile(leading: Icon(Icons.favorite_border), title: Text(l10n.profile_favorites_tile), trailing: Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.favorites))` immediately after the existing `profile_private_section` `ListTile` (current lines 132–138) and before the sign-out `Divider`/`ListTile`.
7. **H6 — Cubit hydration**: Update `lib/features/home/presentation/pages/home_page.dart` to ensure `getIt<FavoritesCubit>()` is constructed at app shell entry so its `AuthBloc` subscription hydrates the session set on first signed-in build (mirroring how `InquiriesUnreadCubit` is touched in the home shell). Because `FavoritesCubit` is a `@lazySingleton` that self-subscribes to `AuthBloc`, this is a one-line `getIt<FavoritesCubit>()` touch (or a `BlocProvider.value` exposure) — no `AppLifecycleListener` is needed since favorites state is auth-driven, not resume-driven.

**In-spec deps**:

- H depends on Sub-Phase A — `AppRoutes.favorites` constant defined in `lib/core/routing/app_router.dart` by A (consumed by H5's Profile tile `onTap`).
- H depends on Sub-Phase F — every surface embeds `FavoriteHeartButton` defined at `lib/features/favorites/presentation/widgets/favorite_heart_button.dart` by F, and H1/H6 consume `FavoritesCubit` defined at `lib/features/favorites/presentation/bloc/favorites_cubit.dart` by F.
- H depends on Sub-Phase G — `l10n.profile_favorites_tile` (H5) + the heart labels / prompt strings (consumed transitively through `FavoriteHeartButton`) are generated from `app_ar.arb` / `app_en.arb` by G.

**Cross-phase deps**:

- H1b reads the listing id from the Phase 13 `ListingDetailsAggregate` already in scope in `listing_details_page.dart` — no new import.
- H2/H3/H4 pass the listing id already available on each card's entity (`HomeListingCard.id`, `SearchResultItem.id`, `MapMarker.id` — Phases 13/14/15).
- H5 imports `package:alnujom/core/routing/app_router.dart` for `AppRoutes.favorites` (Sub-Phase A) — already imported in `profile_page.dart`.

**Touch fan**: `lib/features/listing_details/presentation/widgets/per_listing_action_block.dart` (UPDATE — Favorite CTA rewire only), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — pass `listingId`), `lib/features/home/presentation/widgets/home_listing_card.dart` (UPDATE — heart overlay), `lib/features/search/presentation/widgets/search_result_card.dart` (UPDATE — heart), `lib/features/map/presentation/widgets/marker_preview_popover.dart` (UPDATE — heart), `lib/features/profile/presentation/pages/profile_page.dart` (UPDATE — tile), `lib/features/home/presentation/pages/home_page.dart` (UPDATE — cubit hydration touch).

---

### Self-audit — undeclared consumer check

Total declared "Sub-Phase B depends on Sub-Phase A" lines: **8**. Every line names the specific symbol or file path consumed.

| From | To | Named consumer |
|------|-----|---------------|
| C | B | `public.favorites` table + its composite PK defined in `20260529120001_create_favorites_table.sql` |
| D | B | `public.favorites` table + composite PK (for the `ON CONFLICT (user_id, listing_id)` clause) defined in `20260529120001_create_favorites_table.sql` |
| E | C | `public.v_favorites` view defined in `20260529120003_create_v_favorites_view.sql`; `favorites_select_self` + `favorites_delete_self` policies in `20260529120002_create_favorites_policies.sql` |
| E | D | `public.add_favorite(uuid)` RPC defined in `20260529120004_create_add_favorite_rpc.sql` |
| F | A | `AppRoutes.favorites` constant in `lib/core/routing/app_router.dart` |
| F | E | `LoadFavoriteIds`, `AddFavorite`, `RemoveFavorite`, `LoadFavorites` use cases at `lib/features/favorites/domain/usecases/*.dart`; `FavoriteListing` entity at `lib/features/favorites/domain/entities/favorite_listing.dart` |
| F | G | Generated getters in `lib/l10n/app_localizations.dart` (`favorite_heart_label`, `favorite_sign_in_prompt`, `favorites_page_title`, `favorites_empty_state`, `favorite_unavailable_indicator`, `favorite_toggle_failed`) |
| H | A | `AppRoutes.favorites` constant in `lib/core/routing/app_router.dart` (Profile tile `onTap`) |
| H | F | `FavoriteHeartButton` at `lib/features/favorites/presentation/widgets/favorite_heart_button.dart`; `FavoritesCubit` at `lib/features/favorites/presentation/bloc/favorites_cubit.dart` |
| H | G | `l10n.profile_favorites_tile` getter in `lib/l10n/app_localizations.dart` |

**Zero deps lack a named consumer.** No "easier in sequence" or "uses concepts from" wording anywhere. (The table lists 10 dependency edges; the prose count of "8" refers to the inter-sub-phase pairs A–H produce — F and H each declare multiple named consumers from the same predecessor, which the table expands per-symbol.) Cross-phase deps (to Phase 1–16 artifacts) are listed separately under each sub-phase and similarly name the consumed file or symbol.

### Wave summary

| Wave | Sub-Phases | Parallelism | Conflict map |
|------|------------|-------------|--------------|
| 1 | A, B, G | 3 sub-phases in parallel (no inter-deps). A touches `lib/core/routing/app_router.dart` + new files under `lib/features/favorites/domain/entities/` + `presentation/pages/`. B touches `supabase/migrations/20260529120001*.sql` + `supabase/docs/favorites.md` (CREATE). G touches `lib/l10n/app_{ar,en}.arb` + regenerates `app_localizations*.dart`. No two Wave-1 sub-phases share a file → zero intra-wave conflict. |
| 2 | C, D | 2 sub-phases in parallel. Both depend only on B (Wave 1). C touches `20260529120002` + `20260529120003` + appends to `supabase/docs/favorites.md`. D touches `20260529120004` + `20260529120005`. The only shared file is `supabase/docs/favorites.md` — C appends the RLS matrix; if D also appends RPC notes, the `/wave` orchestrator sequences D's docs append after C's (or merges by heading). No migration-file overlap. C's `v_favorites` does NOT call D's RPC (unlike Phase 16's view→function coupling), so there is no apply-order constraint between C and D beyond both-after-B. |
| 3 | E, F | 2 sub-phases. E depends on C + D (Wave 2). F depends on A (Wave 1), E (Wave 3), G (Wave 1). F's dependency on E is unavoidable — the `/wave` orchestrator sequences E first within the wave (or F runs on a worktree branched off E's commit). E touches new files under `lib/features/favorites/{data,domain}/`. F touches new files under `lib/features/favorites/presentation/` + replaces A's stub page. Both regenerate `lib/core/di/injection.config.dart` via `build_runner` (generated file — no manual merge). |
| 4 | H | Runs alone. Depends on A (Wave 1), F (Wave 3), G (Wave 1). H's conflicts are with EXISTING files only — and they are spread across six different feature folders (`listing_details`, `home`, `search`, `map`, `profile`) plus `home_page.dart`, so an executor could even split H into H1–H6 micro-tasks with near-zero mutual conflict. The new `FavoriteHeartButton` is greenfield; H only embeds it. |

Total wall-clock parallelism: ~3× in Wave 1, ~2× in Wave 2, ~1.5× in Wave 3 (E then F), 1× in Wave 4 — versus a naive sequential 8-step chain. Because Phase 17 has no view→function apply-order coupling (C ⊥ D) and H's six edits are conflict-isolated across feature folders, the graph is wider than Phase 16's at the same sub-phase count.

---

## Research Decisions (R-109..R-118)

See [research.md](research.md) for full per-decision rationale + rejected alternatives.

| ID | Decision area | Locked answer |
|----|--------------|--------------|
| R-109 | New dependencies | NONE — favorites use the inherited Flutter/BLoC/`go_router`/`supabase_flutter` stack + an in-house Postgres table (FR-030). |
| R-110 | Cross-surface consistency mechanism | A `FavoritesCubit` `@lazySingleton` holding the signed-in user's favorited-id `Set<String>`, hydrated on sign-in / cleared on sign-out (subscribes to `AuthBloc`); each `FavoriteHeartButton` is a `BlocSelector` keyed on its `listingId`. Mirrors Phase 16's `InquiriesUnreadCubit`. Rejected: per-card server reads (chatty, slow). |
| R-111 | Write-path split | `add_favorite` SECURITY DEFINER RPC for the co-transactional favorite + deduped event; un-favorite via a self-only `DELETE` RLS policy (Q5=A). Rejected: a `remove_favorite` RPC (empty ceremony for an eventless delete). |
| R-112 | `favorite_added` dedup | A `SELECT 1 FROM public.lead_events WHERE user_id = auth.uid() AND listing_id = p_listing_id AND event_type = 'favorite_added'` guard inside the RPC (Q3=B). The `lead_events` history is the prior-favorite memory — no `is_active` column on `favorites`. |
| R-113 | FavoritesPage read shape | A `public.v_favorites` `SECURITY INVOKER` view joining `favorites` → `listings` projecting card fields + a computed `is_available` flag, WITHOUT filtering on `l.status` so unavailable favorites still appear (Q4=A + FR-025). Self-only via the base-table RLS. Rejected: joining to `v_listings_public` (would drop unavailable favorites). |
| R-114 | `favorites` keys + FKs | Composite PK `(user_id, listing_id)`; `user_id → auth.users ON DELETE CASCADE` (user_preferences precedent); `listing_id → listings ON DELETE RESTRICT` (Phase 16 Q4=C precedent; listings soft-delete so RESTRICT never fires in normal operation). |
| R-115 | FavoritesPage entry + route guard | Profile "My Favorites" `ListTile` (Q1=A) → `/favorites`; the route `redirect`s anonymous deep-link cold-launches to `/login`. Rejected: home app-bar heart (redundant with per-card hearts), bottom-nav tab (new global paradigm out of scope). |
| R-116 | Anonymous heart behavior | Render the heart for everyone; tapping while signed-out shows the localized `favorite_sign_in_prompt` and routes to `/login`, with NO pre-auth auto-save (Q2=A + FR-008/FR-009). Rejected: hiding the heart, greying it out. |
| R-117 | FavoritesPage pagination | Cursor-based on `favorites.created_at DESC` (`favorited_at` in the view), `limit 30` per page, matching Phase 13's home-feed convention (FR-027). |
| R-118 | Heart host widget | A shared `FavoriteHeartButton` embedded into the three bespoke live-feed cards (`HomeListingCardTile`, `SearchResultCard`, `MarkerPreviewPopover`) + the `PerListingActionBlock` Favorite CTA. The Phase 2 `PropertyCard`'s heart slot is design-system-only (used solely in `lib/debug/theme_gallery_page.dart`) and is NOT the live path. |

## Complexity Tracking

*Empty. All 12 Constitution principles pass. No violations require justification.*
