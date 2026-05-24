# Implementation Plan: Search & Filters

**Branch**: `014-search-filters` | **Date**: 2026-05-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/014-search-filters/spec.md`

## Summary

Phase 14 introduces the **search and filter surface** — a dedicated `/search` route and `SearchPage` that replaces Phase 13's Coming-soon snackbar stubs on the hero search bar and the eight property-type shortcut chips. The phase ships: **two new SQL migrations** (`_listings_search_vector.sql` adding a `GENERATED ALWAYS AS STORED` `tsvector` column + GIN index on `public.listings`, and `_create_v_listings_public.sql` adding a convenience view); **one new SQL RPC** (`search_listings(...)`) that composes full-text matching, nine facet-filter dimensions, currency-converted price-range filtering, dual-mode room/bathroom counting ("Exactly N" / "At least N"), and three sort orders into a single paginated query; **one new full-featured Flutter feature folder** at `lib/features/search/` with a three-layer Clean Architecture structure (data + domain + presentation) housing `SearchBloc`, `SearchPage`, `SearchFilterSheet` (modal bottom sheet), `InlineSortControl`, and `SearchResultCard`; **updates to two Phase 13 stub widgets** (`hero_search_bar.dart` and `property_type_shortcut_row.dart`) replacing their snackbar-only tap handlers with real navigation; and **an 34-key ARB delta** across both locale files. Zero new pubspec packages are required — all needed packages (`supabase_flutter`, `flutter_bloc`, `go_router`, `get_it` + `injectable`, `intl`, `flutter_localizations`, `cached_network_image`) are already in `pubspec.yaml`.

**Technical approach**: Phase 14 uses a **SQL RPC** (`search_listings`) rather than raw PostgREST filter chains for the search query, because composing tsvector full-text search, nine optional facet dimensions, price-range currency conversion (client-side rate fetch), and two cursor shapes (timestamp-based for "newest" sort, price-based for price sorts) into a PostgREST URL would be unreadable and fragile. The RPC is `SECURITY DEFINER` with an explicit `status = 'approved'` + publish-window guard mirroring the Phase 10 RLS posture; Constitution III is honored by the RPC's own filter rather than relying solely on RLS, which is acceptable for a read-only function per the constitution's "Edge Functions or RPCs that re-check permissions server-side" provision. **Filter state persistence** is achieved by keeping the `SearchBloc` alive inside the route's widget sub-tree (not disposing it on pop) so back-navigation restores state from the live BLoC instance — no explicit `PageStorageKey` or `RestorableValue` needed for v1. **Price-range currency conversion** is done client-side: the datasource fetches the latest rate via the existing `latest_rates_for_base` RPC (Phase 9 — `supabase/migrations/20260518120006_create_latest_rates_for_base_rpc.sql`), converts filter bounds to per-currency amounts, and passes them directly to the search RPC. Phase 14 introduces zero new Supabase tables, zero new RLS policies, zero new audit-log call sites, and zero new pubspec packages.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel). PostgreSQL (Supabase remote, Postgres 15+) for three new SQL artifacts (two migrations + one RPC function). Zero TypeScript Edge Function additions — Phase 14's server logic lives in a SQL function called via PostgREST RPC.

**Primary Dependencies**:
- `supabase_flutter` — Phase 1 wrapper at `lib/core/network/supabase_client.dart` consumed unchanged. Phase 14 calls `client.rpc('search_listings', params: {...})` and `client.rpc('latest_rates_for_base', params: {...})` through this wrapper.
- `flutter_bloc` — one new `SearchBloc` in `lib/features/search/presentation/bloc/`.
- `go_router` — one new `/search` route added to `lib/core/routing/app_router.dart`; `GoRouterState.extra` used to pass the optional pre-filter map from home chips.
- `get_it` + `injectable` — DI registrations for new datasource, repository, use case, bloc; `build_runner` regenerates `injection.config.dart`.
- `flutter_localizations` + `intl` — `AppLocalizations` already generated; Phase 14 adds 34 ARB keys and regenerates.
- `cached_network_image` — used by `SearchResultCard` (same pattern as Phase 13's `HomeListingCard` widget).
- `equatable` — `FilterState`, `SearchResultItem`, `SortOrder` all extend `Equatable`.

**Zero new pubspec packages**. All packages already present.

**Storage**: Remote Supabase Postgres. Phase 14 backend artifacts:
- `<timestamp>_listings_search_vector.sql` — `ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(address_text,''))) STORED;` + `CREATE INDEX IF NOT EXISTS idx_listings_search_vector ON public.listings USING GIN(search_vector);`. Note: `description` lives in `listing_details`, not `listings`, so it is searched via the RPC with an ILIKE supplement (R-73).
- `<timestamp>_create_v_listings_public.sql` — view `public.v_listings_public` selecting only the publicly readable projection of `listings` + embedded price + media (mirrors the Phase 13 home-feed projection shape). The `search_listings` RPC reads from this view (R-74).
- `<timestamp>_create_search_listings_rpc.sql` — SECURITY DEFINER function `search_listings(...)` accepting all filter/sort/cursor parameters and returning a typed SETOF rows. Full parameter list in `contracts/phase14-search-listings-rpc.md`.

**Testing**: Manual UI verification only per `feedback_no_new_tests.md` (eleventh consecutive phase). Verification via Supabase MCP `execute_sql` for RPC smoke tests + EXPLAIN checks + manual two-device walk (Infinix Note 8 primary, Pixel 8 Pro emulator secondary). All 11 SCs codified as a manual checklist in `quickstart.md`.

**Target Platform**: Android 7.0+ (API 24+). No iOS, no Flutter Web, no desktop.

**Project Type**: Mobile app + Supabase backend. Phase 14 introduces one new feature folder (`lib/features/search/`) with full three-layer structure; three updated files in `lib/features/home/presentation/widgets/`; one updated routing file; two updated DI files; two updated ARB files; three new SQL migration/function files.

**Performance Goals**:
- Keyword search query → first page of results rendered: ≤ 2 seconds p95 per SC-001 / SC-002. Measured at device from keyboard submit to first card visible.
- Filter sheet open animation: ≤ 500 ms (bottom sheet slide-up).
- Sort reorder (inline control tap → list reordered): ≤ 1 second per SC-004.
- Empty-state appearance after filter yields zero results: ≤ 1 second per SC-006.
- `EXPLAIN (ANALYZE, BUFFERS)` on a keyword query uses `idx_listings_search_vector` (GIN bitmap scan).
- `EXPLAIN (ANALYZE, BUFFERS)` on a governorate + property_type facet query uses Phase 13's `idx_listings_governorate_status` or `idx_listings_property_type_status`.

**Constraints**:
- Constitution II: all three SQL artifacts are checked-in files under `supabase/migrations/`. Applied via Supabase MCP `apply_migration`. No Studio-only edits.
- Constitution III: the `search_listings` RPC is SECURITY DEFINER with an explicit `WHERE status = 'approved' AND (expires_at IS NULL OR expires_at > now())` guard. Phase 14 code MUST NOT add a redundant application-layer `status='approved'` filter — the RPC + the existing Phase 10 RLS together enforce the public-read gate per FR-011.
- Arabic search is exact-token only (no morphological stemming) per spec clarification Q1=A. FR-003 and SC-001 are precise on this.
- Price-range currency conversion is client-side: the datasource fetches the rate, converts bounds, passes both per-currency amount pairs to the RPC. If no exchange rate is available for the selected filter currency, the price-range filter is disabled in the UI with a localized message per the spec edge case.
- Migrations MUST be idempotent (`ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `CREATE OR REPLACE VIEW`).

**Scale/Scope**:
- Three new SQL artifacts (two migrations + one RPC function).
- One new feature folder `lib/features/search/` (full three-layer structure, ~18 new Dart files).
- Two updated Phase 13 stub widgets (`hero_search_bar.dart`, `property_type_shortcut_row.dart`).
- One updated routing file (`app_router.dart`) — one new `/search` route + `AppRoutes.search` constant.
- Two updated DI files (`injection.dart` annotations + generated `injection.config.dart`).
- 34 new ARB keys in `app_ar.arb` + `app_en.arb` + `app_strings.dart` debug subclass.
- Zero new pubspec packages.
- Zero new RLS policies.
- Zero new audit-log call sites.
- Zero new automated tests.

---

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists with 5 user stories, 19 FRs (FR-001..FR-019), 11 SCs (SC-001..SC-011); `/speckit-clarify` Session 2026-05-24 resolved 5 questions (Q1 Arabic precision + future smart-search, Q2 rooms/baths dual-mode, Q3 bottom-sheet pattern, Q4 inline sort control, Q5 pre-filter from home chip). All Qs folded into FRs, SCs, and Assumptions. |
| II. Source-Controlled Backend | **Pass** | All three Phase 14 SQL artifacts are checked-in files under `supabase/migrations/`. Applied via Supabase MCP `apply_migration`. No Studio-only changes. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | The `search_listings` RPC is SECURITY DEFINER with an explicit `status = 'approved'` + publish-window guard — read-only function with no mutation surface. Existing Phase 10 RLS on `public.listings` remains enabled and provides defense-in-depth. No new tables with RLS gaps. |
| IV. Clean Architecture Flutter | **Pass** | `lib/features/search/` carries the three-layer split. Domain entities and repository interface are Supabase-free per Principle IX. `SearchBloc` owns the page boundary. `SearchFilterSheet` is a stateful widget whose only external coupling is `FilterState` (domain type). |
| V. Arabic-First Localization | **Pass** | All 34 new user-visible strings flow through `AppLocalizations`. `SearchFilterSheet` and `SearchPage` use `EdgeInsetsDirectional`; the inline sort control and result list scroll in the locale's reading direction. Phase 3 localization lint guard catches any hardcoded string at PR review. |
| VI. Theme System & Design Tokens | **Pass** | `SearchPage`, `SearchFilterSheet`, `SearchResultCard`, and `InlineSortControl` consume Phase 2 design tokens only. No inline hex / font-size / padding per SC-007. |
| VII. Dynamic Roles & Permissions | **Pass (N/A)** | Search is anonymous-readable via RLS — zero new permission keys, zero permission checks, zero audit-log call sites. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Search results are bounded to `status = 'approved'` listings via the RPC guard. Publisher private fields (legal name, national ID, private contact methods) are NOT projected in the search result shape. |
| IX. Future Backend Portability | **Pass** | `lib/features/search/domain/` imports nothing from `package:supabase_flutter`. `SearchRepository` is an abstract Dart class. Only `lib/features/search/data/datasources/supabase_search_datasource.dart` touches Supabase types. |
| X. Testable AI Workflow | **Pass — Justified** | Per `feedback_no_new_tests.md`, every FR is verifiable via a manual Supabase MCP `execute_sql` RPC smoke test OR a manual UI walk on device (keyword search, filter sheet apply/reset, sort reorder, back-navigation state restoration, pre-filter chip entry, Arabic hint trigger, price-range validation). All 11 SCs codified in `quickstart.md` as a manual checklist. |
| XI. Android-First MVP | **Pass** | All Flutter additions target Android only. No iOS-conditional code. No new pubspec package with iOS-only implementations. The two-device walk uses Infinix Note 8 + Pixel 8 Pro emulator — both Android. |
| XII. No Hidden Product Decisions | **Pass** | Five `/speckit-clarify` questions (Q1–Q5) are recorded in `spec.md ## Clarifications`. All plan-time research decisions (R-73..R-84) are documented in `research.md`. The smart-Arabic-search deferral is explicitly named. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

---

## Project Structure

### Documentation (this feature)

```text
specs/014-search-filters/
├── plan.md                              # This file (/speckit-plan output)
├── research.md                          # Phase 0 — 12 locked tech decisions (R-73..R-84)
├── data-model.md                        # Phase 1 — SQL artifacts + Dart entities + ARB key inventory
├── quickstart.md                        # Phase 1 — manual verification recipe (11 SCs)
├── contracts/
│   ├── phase14-search-vector-migration.md    # Search column + GIN index SQL spec + EXPLAIN expected output
│   ├── phase14-search-listings-rpc.md        # Full RPC parameter list + return type + behavior contract
│   ├── phase14-filter-sheet.md               # SearchFilterSheet composition + Apply/Reset behavior
│   ├── phase14-search-page-composition.md    # SearchPage widget tree + inline sort + entry-point wiring
│   ├── phase14-filter-state-persistence.md   # BLoC-lifetime preservation pattern for back-navigation
│   └── phase14-home-rewiring.md              # hero_search_bar + property_type_shortcut_row tap-handler delta
├── checklists/
│   └── requirements.md                  # All 5 Qs resolved; checklist fully green
└── spec.md                              # From /speckit-specify + /speckit-clarify (Q1–Q5 resolved)
```

### Source Code (repository root)

```text
supabase/
├── migrations/
│   ├── (existing Phase 1–13 migrations)                            # NO CHANGE.
│   ├── 20260525120001_listings_search_vector.sql                    # NEW — ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS
│   │                                                                #   search_vector tsvector GENERATED ALWAYS AS
│   │                                                                #   (to_tsvector('simple', coalesce(title,'') || ' ' ||
│   │                                                                #    coalesce(address_text,''))) STORED;
│   │                                                                #   + CREATE INDEX IF NOT EXISTS idx_listings_search_vector
│   │                                                                #   ON public.listings USING GIN(search_vector);
│   ├── 20260525120002_create_v_listings_public.sql                  # NEW — CREATE OR REPLACE VIEW public.v_listings_public AS
│   │                                                                #   SELECT l.*, lp.amount AS primary_amount,
│   │                                                                #   lp.currency_code AS primary_currency,
│   │                                                                #   lm.storage_path AS main_image_path ...
│   │                                                                #   WHERE l.status = 'approved'
│   │                                                                #   AND (l.expires_at IS NULL OR l.expires_at > now())
│   └── 20260525120003_create_search_listings_rpc.sql                # NEW — SECURITY DEFINER function search_listings(...)
│                                                                    #   Full parameter list in contracts/phase14-search-listings-rpc.md.
└── docs/
    └── listings.md                                                  # OPTIONAL UPDATE — note new search_vector column + GIN index.

lib/
├── core/
│   ├── routing/
│   │   └── app_router.dart                                          # UPDATE — add AppRoutes.search = '/search' constant;
│   │                                                                #   add GoRoute('/search', builder: (_,s) => SearchPage(
│   │                                                                #     initialPropertyType: s.extra as PropertyType?))
│   │                                                                #   See Sub-Phase F.
│   ├── di/
│   │   ├── injection.dart                                           # UPDATE — @injectable annotations trigger build_runner to
│   │   │                                                            #   register SearchDatasource, SearchRepositoryImpl,
│   │   │                                                            #   SearchListingsUseCase, SearchBloc. Updated in Sub-Phase D.
│   │   └── injection.config.dart                                    # REGENERATED — via build_runner after Sub-Phase D annotations.
│   └── errors/
│       └── failure.dart                                             # NO CHANGE — existing ServerFailure reused for RPC errors.
│                                                                    #   No new Failure subtype needed (search errors are ServerFailure).
├── features/
│   ├── home/
│   │   └── presentation/
│   │       └── widgets/
│   │           ├── hero_search_bar.dart                             # UPDATE (Sub-Phase G) — replace snackbar handler with
│   │           │                                                    #   context.go(AppRoutes.search).
│   │           └── property_type_shortcut_row.dart                  # UPDATE (Sub-Phase G) — replace snackbar handler per chip
│   │                                                                #   with context.go(AppRoutes.search,
│   │                                                                #     extra: type) where type is PropertyType enum value.
│   └── search/                                                      # NEW FEATURE FOLDER
│       ├── data/
│       │   ├── datasources/
│       │   │   └── supabase_search_datasource.dart                  # NEW — ONLY search/ file importing package:supabase_flutter.
│       │   │                                                        #   Calls client.rpc('search_listings', params: _buildParams())
│       │   │                                                        #   + client.rpc('latest_rates_for_base',...) for price conversion.
│       │   ├── dtos/
│       │   │   └── search_result_item_dto.dart                      # NEW — matches the v_listings_public projection shape
│       │   │                                                        #   (id, title, property_type, purpose, published_at,
│       │   │                                                        #    primary_amount, primary_currency, main_image_path,
│       │   │                                                        #    governorate_name_ar, governorate_name_en,
│       │   │                                                        #    city_name_ar, city_name_en).
│       │   └── repositories/
│       │       └── search_repository_impl.dart                      # NEW — implements SearchRepository.
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── search_result_item.dart                          # NEW — same projection as HomeListingCard but owned by
│       │   │   │                                                    #   the search feature domain. Fields: id, title,
│       │   │   │                                                    #   propertyType, purpose, governorateNameAr,
│       │   │   │                                                    #   governorateNameEn, cityNameAr, cityNameEn,
│       │   │   │                                                    #   primaryAmount (double), primaryCurrency (String),
│       │   │   │                                                    #   mainImagePath (String?), publishedAt (DateTime).
│       │   │   ├── filter_state.dart                                # NEW — immutable value object. Fields: query(String?),
│       │   │   │                                                    #   purpose(ListingPurpose?), propertyType(PropertyType?),
│       │   │   │                                                    #   governorateId(String?), cityId(String?), areaId(String?),
│       │   │   │                                                    #   priceMin(num?), priceMax(num?), priceCurrency(String?),
│       │   │   │                                                    #   rooms(int?), roomsMode(CountFilterMode), bathrooms(int?),
│       │   │   │                                                    #   bathroomsMode(CountFilterMode), areaSizeMin(num?),
│       │   │   │                                                    #   areaSizeMax(num?). copyWith() generated.
│       │   │   ├── sort_order.dart                                  # NEW — enum: newest, priceAsc, priceDesc.
│       │   │   └── count_filter_mode.dart                           # NEW — enum: exactly, atLeast.
│       │   ├── repositories/
│       │   │   └── search_repository.dart                           # NEW — abstract. Method:
│       │   │                                                        #   Future<Either<Failure, List<SearchResultItem>>> search({
│       │   │                                                        #     required FilterState filters,
│       │   │                                                        #     required SortOrder sort,
│       │   │                                                        #     SearchCursor? cursor,
│       │   │                                                        #     int limit = 20 });
│       │   └── usecases/
│       │       └── search_listings_usecase.dart                     # NEW — wraps SearchRepository.search().
│       └── presentation/
│           ├── bloc/
│           │   ├── search_bloc.dart                                 # NEW — events: SearchQueryChanged, SearchFiltersApplied,
│           │   │                                                    #   SearchSortChanged, SearchNextPageRequested,
│           │   │                                                    #   SearchRefreshRequested.
│           │   │                                                    #   State: SearchState(results, filters, sort, cursor?,
│           │   │                                                    #   status, failure?). BLoC lifetime preserved across
│           │   │                                                    #   back-navigation per R-77.
│           │   ├── search_event.dart                                # NEW
│           │   └── search_state.dart                                # NEW
│           ├── pages/
│           │   └── search_page.dart                                 # NEW — FR-001. Composes: AppBar (back arrow) +
│           │                                                        #   search text field (auto-focus when opened from hero bar) +
│           │                                                        #   Row(InlineSortControl, FiltersButton) +
│           │                                                        #   paginated ListView of SearchResultCard + empty/error states.
│           │                                                        #   BlocProvider<SearchBloc> wraps the page.
│           └── widgets/
│               ├── search_filter_sheet.dart                         # NEW — DraggableScrollableSheet bottom sheet (R-78).
│               │                                                    #   Dimensions: purpose, property_type, location cascade,
│               │                                                    #   price range + currency, rooms (dual-mode), bathrooms
│               │                                                    #   (dual-mode), area size (min/max). Apply → emits
│               │                                                    #   SearchFiltersApplied event; Reset → clears to empty
│               │                                                    #   FilterState without closing sheet.
│               ├── inline_sort_control.dart                         # NEW — SegmentedButton or DropdownButton (R-84) showing
│               │                                                    #   3 sort options inline on the results page.
│               ├── search_result_card.dart                          # NEW — wraps Phase 13's _HomeListingCard visual design
│               │                                                    #   accepting a SearchResultItem; tap routes to
│               │                                                    #   AppRoutes.listingDetails/:id (Phase 13 route).
│               └── price_range_input.dart                           # NEW — two numeric text fields (min, max) + inline
│                                                                    #   validation rejecting min > max per FR-017.
└── l10n/
    ├── app_ar.arb                                                   # UPDATE — 34 new keys per data-model.md ARB inventory.
    ├── app_en.arb                                                   # UPDATE — 34 new keys.
    └── app_strings.dart                                             # UPDATE — hand-maintained _DebugAppLocalizations extended.
```

**Structure Decision**: Phase 14 is a Mobile app + Supabase backend phase. The single new feature folder `lib/features/search/` owns the complete three-layer search surface. Two Phase 13 stub widgets in `lib/features/home/presentation/widgets/` are updated (not replaced). Three SQL files land under `supabase/migrations/`. No new pubspec packages, no new iOS/Web targets, no new audit-log call sites.

---

## Phase Dependencies

> **User-mandated discipline**: Every "Sub-Phase B depends on Sub-Phase A" line below names the specific file path OR exported symbol that B consumes from A. Lines like "easier in sequence" or "uses concepts from" are FORBIDDEN. Self-audit count is at the end of this section.

Phase 14 decomposes into **seven sub-phases (Sub-Phase A through Sub-Phase G)** across **four sequential waves**. Each sub-phase carries a **Touch fan** listing every modified or created file — the `/wave` orchestrator uses these to pick merge order and pre-warn agents about expected conflicts.

---

### Sub-Phase A — Backend SQL (migrations + RPC)

**Scope**: Apply three SQL migrations in order:
1. `20260525120001_listings_search_vector.sql` — `ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (...) STORED` + `CREATE INDEX IF NOT EXISTS idx_listings_search_vector ON public.listings USING GIN(search_vector)`.
2. `20260525120002_create_v_listings_public.sql` — `CREATE OR REPLACE VIEW public.v_listings_public` projecting the approved-listing feed columns with embedded price + main-image join.
3. `20260525120003_create_search_listings_rpc.sql` — SECURITY DEFINER function `search_listings(p_query text, p_purpose text, ...)` returning `SETOF search_result_row`. Full parameter list in `contracts/phase14-search-listings-rpc.md`. Verify via `EXPLAIN (ANALYZE, BUFFERS)` that a keyword query uses `idx_listings_search_vector` (GIN) and a facet query uses `idx_listings_governorate_status` or `idx_listings_property_type_status`.

**Touch fan**: `supabase/migrations/20260525120001_listings_search_vector.sql` (CREATE), `supabase/migrations/20260525120002_create_v_listings_public.sql` (CREATE), `supabase/migrations/20260525120003_create_search_listings_rpc.sql` (CREATE).

---

### Sub-Phase B — Domain layer

**Scope**: Create the full `lib/features/search/domain/` subtree — entities (`SearchResultItem`, `FilterState`, `SortOrder`, `CountFilterMode`), abstract repository (`SearchRepository`), and use case (`SearchListingsUseCase`). No Supabase imports anywhere in this subtree.

**Touch fan**: `lib/features/search/domain/entities/search_result_item.dart` (CREATE), `lib/features/search/domain/entities/filter_state.dart` (CREATE), `lib/features/search/domain/entities/sort_order.dart` (CREATE), `lib/features/search/domain/entities/count_filter_mode.dart` (CREATE), `lib/features/search/domain/repositories/search_repository.dart` (CREATE), `lib/features/search/domain/usecases/search_listings_usecase.dart` (CREATE).

---

### Sub-Phase C — ARB key delta

**Scope**: Add all 34 Phase 14 search/filter ARB keys to `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`. Extend `lib/l10n/app_strings.dart` `_DebugAppLocalizations` subclass with concrete getters for each new key. Run `flutter gen-l10n` to regenerate `AppLocalizations`. Full key list in `data-model.md §ARB Key Inventory`.

**Touch fan**: `lib/l10n/app_ar.arb` (UPDATE), `lib/l10n/app_en.arb` (UPDATE), `lib/l10n/app_strings.dart` (UPDATE).

> **Wave 1 boundary**: Sub-Phases A, B, and C are fully independent and run in parallel.

---

### Sub-Phase D — Data layer

**Scope**: Create `lib/features/search/data/` — `SearchResultItemDto` (JSON → Dart), `SupabaseSearchDatasource` (calls `search_listings` RPC + `latest_rates_for_base` RPC), `SearchRepositoryImpl`. Update `injection.dart` with `@injectable` annotations; regenerate `injection.config.dart` via `build_runner`.

**Depends on Sub-Phase A**:
- `supabase_search_datasource.dart` calls `client.rpc('search_listings', ...)` — the `search_listings` function defined in `supabase/migrations/20260525120003_create_search_listings_rpc.sql` (Sub-Phase A) must exist in the remote DB before this datasource can be tested.
- `supabase_search_datasource.dart` calls `client.rpc('latest_rates_for_base', ...)` — this RPC already exists in `supabase/migrations/20260518120006_create_latest_rates_for_base_rpc.sql` (Phase 9, already applied).

**Depends on Sub-Phase B**:
- `SearchRepositoryImpl` implements the abstract `SearchRepository` defined in `lib/features/search/domain/repositories/search_repository.dart` (Sub-Phase B).
- `SupabaseSearchDatasource.fetchPage()` maps SQL rows to `SearchResultItemDto` and ultimately to `SearchResultItem` entities defined in `lib/features/search/domain/entities/search_result_item.dart` (Sub-Phase B).
- `SearchRepositoryImpl.search()` receives a `FilterState` argument defined in `lib/features/search/domain/entities/filter_state.dart` (Sub-Phase B) and a `SortOrder` from `lib/features/search/domain/entities/sort_order.dart` (Sub-Phase B).

**Touch fan**: `lib/features/search/data/datasources/supabase_search_datasource.dart` (CREATE), `lib/features/search/data/dtos/search_result_item_dto.dart` (CREATE), `lib/features/search/data/repositories/search_repository_impl.dart` (CREATE), `lib/core/di/injection.dart` (UPDATE — add `@injectable` annotations), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase E — SearchFilterSheet widget

**Scope**: Create `lib/features/search/presentation/widgets/search_filter_sheet.dart` (DraggableScrollableSheet hosting all filter dimensions), `price_range_input.dart` (numeric min/max pair with inline min>max validation). The sheet is a stateful widget that takes an initial `FilterState` and surfaces an `onApply(FilterState)` callback.

**Depends on Sub-Phase B**:
- `SearchFilterSheet` constructor parameter `initialFilters` is typed `FilterState` — defined in `lib/features/search/domain/entities/filter_state.dart` (Sub-Phase B).
- The rooms/bathrooms dual-mode control uses `CountFilterMode` enum from `lib/features/search/domain/entities/count_filter_mode.dart` (Sub-Phase B).

**Depends on Sub-Phase C**:
- `SearchFilterSheet` references ARB keys (e.g., `search_filter_apply`, `search_filter_reset`, `search_filter_rooms_exactly`, `search_filter_rooms_at_least`, `search_filter_purpose_label`) added to `app_ar.arb` + `app_en.arb` in Sub-Phase C. The localization lint guard will reject the widget if these keys are absent.

**Cross-phase dependencies**:
- `SearchFilterSheet`'s cascading location picker reads `Governorate` entities from `lib/features/locations/domain/entities/governorate.dart` (Phase 8) and `City` from `lib/features/locations/domain/entities/city.dart` (Phase 8) and `Area` from `lib/features/locations/domain/entities/area.dart` (Phase 8), fetched via Phase 8's `LocationRepository` (injected).
- `SearchFilterSheet`'s currency selector populates from `Currency` entities from `lib/features/currencies/domain/entities/currency.dart` (Phase 9), fetched via Phase 9's `CurrencyRepository` (injected).

**Touch fan**: `lib/features/search/presentation/widgets/search_filter_sheet.dart` (CREATE), `lib/features/search/presentation/widgets/price_range_input.dart` (CREATE).

> **Wave 2 boundary**: Sub-Phases D and E are independent of each other (D depends on A+B; E depends on B+C) and run in parallel.

---

### Sub-Phase F — SearchPage + SearchBloc + routing

**Scope**: Create `SearchBloc` (events, state), `SearchPage`, `InlineSortControl`, and `SearchResultCard`. Add `AppRoutes.search = '/search'` to `app_router.dart` and wire the new `GoRoute`. Regenerate DI after bloc annotation.

**Depends on Sub-Phase D**:
- `SearchBloc` dispatches to `SearchListingsUseCase` — registered in DI by Sub-Phase D. `SearchBloc` constructor receives `SearchListingsUseCase` via `GetIt`; the `@injectable` annotation is applied in Sub-Phase D's DI update.

**Depends on Sub-Phase E**:
- `SearchPage` imports `SearchFilterSheet` from `lib/features/search/presentation/widgets/search_filter_sheet.dart` (Sub-Phase E) and renders it as a bottom sheet on `FiltersButton` tap.

**Cross-phase dependencies**:
- `SearchResultCard` widget takes a `SearchResultItem` entity (Sub-Phase B) and renders it using the same visual structure as Phase 13's `HomeListingCard` widget at `lib/features/home/presentation/widgets/home_listing_card.dart`. It reuses Phase 13's `HomeListingCard` as a display reference but does not import from the `home` feature domain — it uses `SearchResultItem` directly.
- `SearchPage`'s card tap calls `context.go('${AppRoutes.listingDetails}/${item.id}')` where `AppRoutes.listingDetails` is the existing route constant in `lib/core/routing/app_router.dart` (Phase 13).
- `SearchPage` accepts an optional `PropertyType? initialPropertyType` constructor parameter, used when entered from a property-type chip (Q5=A pre-filter behavior from `property_type_shortcut_row.dart` update in Sub-Phase G).

**Touch fan**: `lib/features/search/presentation/bloc/search_bloc.dart` (CREATE), `lib/features/search/presentation/bloc/search_event.dart` (CREATE), `lib/features/search/presentation/bloc/search_state.dart` (CREATE), `lib/features/search/presentation/pages/search_page.dart` (CREATE), `lib/features/search/presentation/widgets/inline_sort_control.dart` (CREATE), `lib/features/search/presentation/widgets/search_result_card.dart` (CREATE), `lib/core/routing/app_router.dart` (UPDATE), `lib/core/di/injection.dart` (UPDATE — bloc annotation), `lib/core/di/injection.config.dart` (REGENERATED).

> **Wave 3 boundary**: Sub-Phase F runs alone after Sub-Phases D and E complete.

---

### Sub-Phase G — Home screen rewiring

**Scope**: Update Phase 13's two stub widgets to replace their Coming-soon snackbar handlers with real navigation. No structural changes to surrounding widgets or the home feature folder.

**Depends on Sub-Phase F**:
- `hero_search_bar.dart` (Phase 13, `lib/features/home/presentation/widgets/hero_search_bar.dart`) replaces its `ScaffoldMessenger.of(context).showSnackBar(...)` handler with `context.go(AppRoutes.search)` — `AppRoutes.search` is defined in `lib/core/routing/app_router.dart` by Sub-Phase F.
- `property_type_shortcut_row.dart` (Phase 13, `lib/features/home/presentation/widgets/property_type_shortcut_row.dart`) replaces its `ScaffoldMessenger.of(context).showSnackBar(...)` handler per chip with `context.go(AppRoutes.search, extra: type)` — where `type` is the `PropertyType` value consumed by `SearchPage`'s `initialPropertyType` parameter, wired in Sub-Phase F's `GoRoute` builder.

**Touch fan**: `lib/features/home/presentation/widgets/hero_search_bar.dart` (UPDATE), `lib/features/home/presentation/widgets/property_type_shortcut_row.dart` (UPDATE).

> **Wave 4 boundary**: Sub-Phase G runs last after Sub-Phase F completes.

---

### Self-audit — undeclared consumer check

Every sub-phase dependency line above names a specific file path and/or exported symbol. Count of dependency lines without a named consumer: **0**. ✓

### Wave summary

| Wave | Sub-Phases | Parallelism |
|---|---|---|
| 1 | A (Backend SQL) + B (Domain) + C (ARB keys) | Fully parallel |
| 2 | D (Data layer) + E (Filter sheet widget) | Parallel (D needs A+B; E needs B+C) |
| 3 | F (SearchPage + SearchBloc + routing) | Sequential (needs D+E) |
| 4 | G (Home rewiring) | Sequential (needs F) |

---

## Research Decisions (R-73..R-84)

*See `research.md` for full rationale. This section is a summary index.*

| Decision | Locked Choice |
|---|---|
| R-73 | `search_vector` covers `title` + `address_text` only (GENERATED ALWAYS AS STORED). `description` (in `listing_details`) searched via ILIKE supplement in the RPC. |
| R-74 | SQL RPC (`search_listings`) rather than raw PostgREST for query composition. RPC is SECURITY DEFINER; `v_listings_public` view provides the approved-listing projection read by the RPC. |
| R-75 | Price-range currency conversion is **client-side**: datasource fetches rate via `latest_rates_for_base` RPC (Phase 9), converts bounds to per-currency amounts, passes both to the search RPC as `p_price_min_usd/p_price_max_usd` + `p_price_min_syp/p_price_max_syp`. |
| R-76 | Cursor for **newest** sort: `(published_at DESC, id DESC)` — same as Phase 13 home feed. Cursor for **price** sorts: `(price_amount, id)` pair — sort-specific cursor shape, encoded in `SearchState.cursor` as a discriminated union. |
| R-77 | Filter state persistence: `SearchBloc` is provided at the `SearchPage` level and kept alive by `go_router`'s default page-cache behavior. Back-navigation restores BLoC state automatically — no `PageStorageKey` or `RestorableValue` needed. |
| R-78 | `SearchFilterSheet` uses `DraggableScrollableSheet` (not `showModalBottomSheet`) for the bottom-sheet implementation, allowing the sheet to be partially dragged open by the user. |
| R-79 | Rooms/bathrooms dual-mode control uses a `SegmentedButton<CountFilterMode>` (Flutter Material 3 native) with two segments: "تماماً N / Exactly N" and "على الأقل N / At least N". |
| R-80 | Pre-filter from home chip: the `PropertyType` value is passed via `GoRouterState.extra` (not as a URL query parameter) to avoid leaking enum values into the URL. `SearchPage` reads `GoRouterState.extra as PropertyType?` in its `GoRoute` builder. |
| R-81 | `v_listings_public` view is shipped. It pre-joins `listing_prices` (primary) + `listing_media` (main image) + governorate/city name columns. The `search_listings` RPC reads from this view rather than joining the base tables directly, keeping the RPC SQL readable. |
| R-82 | `app_strings.dart` `_DebugAppLocalizations` subclass is extended with concrete getters for all 34 new Phase 14 keys (same pattern as Phase 13). |
| R-83 | Location data (governorates list, cities per governorate, areas per city) is **lazy-loaded on filter sheet open** via Phase 8's existing `LocationRepository` (injected into `SearchFilterSheet`). Governorates are loaded once on sheet open and cached in the sheet's local state; cities/areas are re-fetched when the parent picker changes. |
| R-84 | Inline sort control uses a `DropdownButton<SortOrder>` (not `SegmentedButton`) — three options with localized labels; rendered compactly next to the Filters button in the search results app bar area. `SegmentedButton` would consume too much horizontal space for three options in RTL/LTR. |
