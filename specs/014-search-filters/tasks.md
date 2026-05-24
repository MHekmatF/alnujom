# Tasks: Search & Filters (Phase 14)

**Input**: Design documents from `specs/014-search-filters/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓ (6 contracts), quickstart.md ✓

**Testing**: Manual UI verification only per project memory `feedback_no_new_tests.md`. No new automated tests. All 11 success criteria verified via `quickstart.md` steps 6–17.

**Checkbox discipline**: Each sub-agent MUST flip its `- [ ] T<id>` to `- [X] T<id>` in the same commit as the implementation. Do NOT leave checkbox-flipping for a cleanup pass — it never happens.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel within the wave (different files, no intra-phase dependencies)
- **[Story]**: User story this task serves (US1 Keyword Search · US2 Facet Filters · US3 Sort · US4 Filter Persistence · US5 Combined)

---

## Phase 1 — Sub-Phase A: Backend SQL (Wave 1)

**Goal**: Three idempotent SQL artifacts applied to Supabase in order. Foundational for Sub-Phases D and F (datasource cannot be tested without the RPC).

**Wave**: 1 — parallel with Phase 2 (Domain) and Phase 3 (ARB Keys).

**⚠️ Apply migrations strictly in order (T004 → T005 → T006). Read migration file before applying — do NOT re-apply an already-applied migration (per `project_supabase_mcp_apply_migration.md`).**

- [X] T001 [P] [US1][US2] Write `supabase/migrations/20260525120001_listings_search_vector.sql` — exact body from `data-model.md §1.1`: `ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(address_text,''))) STORED;` + `CREATE INDEX IF NOT EXISTS idx_listings_search_vector ON public.listings USING GIN(search_vector);`
- [X] T002 [P] [US1][US2] Write `supabase/migrations/20260525120002_create_v_listings_public.sql` — exact body from `data-model.md §1.2`: `CREATE OR REPLACE VIEW public.v_listings_public AS SELECT l.id, l.title, l.address_text, l.property_type, l.purpose, l.governorate_id, l.city_id, l.area_id, l.published_at, l.expires_at, l.search_vector, lp.amount AS primary_amount, lp.currency_code AS primary_currency, lm.storage_path AS main_image_path, g.name_ar AS governorate_name_ar, g.name_en AS governorate_name_en, c.name_ar AS city_name_ar, c.name_en AS city_name_en FROM public.listings l LEFT JOIN LATERAL (...) lp ON true LEFT JOIN LATERAL (...) lm ON true LEFT JOIN public.governorates g ON g.id = l.governorate_id LEFT JOIN public.cities c ON c.id = l.city_id WHERE l.status = 'approved' AND (l.expires_at IS NULL OR l.expires_at > now());`
- [X] T003 [P] [US1][US2] Write `supabase/migrations/20260525120003_create_search_listings_rpc.sql` — exact body from `data-model.md §1.3`: idempotent composite type block (`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'search_result_row') THEN CREATE TYPE public.search_result_row AS (id uuid, title text, property_type text, purpose text, governorate_name_ar text, governorate_name_en text, city_name_ar text, city_name_en text, primary_amount numeric, primary_currency text, main_image_path text, published_at timestamptz); END IF; END; $$;`) + full `CREATE OR REPLACE FUNCTION public.search_listings(...)` SECURITY DEFINER body (22 params, all filter branches, both cursor shapes, ORDER BY CASE, `LIMIT p_limit`) + `GRANT EXECUTE ON FUNCTION public.search_listings TO authenticated, anon;`
- [X] T004 [US1][US2] Apply migration `20260525120001_listings_search_vector` via Supabase MCP `apply_migration`; confirm `search_vector` column exists: `SELECT attname, atttypid::regtype FROM pg_attribute WHERE attrelid = 'public.listings'::regclass AND attname = 'search_vector';` — must return `tsvector`
- [X] T005 [US1][US2] Apply migration `20260525120002_create_v_listings_public` via Supabase MCP `apply_migration`; confirm view exists: `SELECT id, title FROM public.v_listings_public LIMIT 1;` — must succeed (may return 0 rows if no approved listings yet)
- [X] T006 [US1][US2] Apply migration `20260525120003_create_search_listings_rpc` via Supabase MCP `apply_migration`; run all 6 smoke tests from `contracts/phase14-search-listings-rpc.md §Smoke Test Queries`; run EXPLAIN check from `quickstart.md Step 2` — confirm keyword query uses `idx_listings_search_vector` (Bitmap Index Scan or Index Scan on GIN); run anonymous role check (`SET LOCAL ROLE anon; SELECT count(*) FROM public.search_listings(p_limit => 5); RESET ROLE;`) — must succeed

**Checkpoint**: `search_listings` RPC callable via `execute_sql`, returns approved listings, EXPLAIN shows GIN index scan on keyword queries.

---

## Phase 2 — Sub-Phase B: Domain Layer (Wave 1)

**Goal**: Pure Dart domain entities, abstract repository, and use case. Zero `package:supabase_flutter` imports anywhere in this subtree.

**Wave**: 1 — parallel with Phase 1 (SQL) and Phase 3 (ARB Keys).

- [X] T007 [P] [US2] Create `lib/features/search/domain/entities/count_filter_mode.dart` — `enum CountFilterMode { exactly, atLeast }` (exact body from `data-model.md §2.3`)
- [X] T008 [P] [US3] Create `lib/features/search/domain/entities/sort_order.dart` — `enum SortOrder { newest, priceAsc, priceDesc }` (exact body from `data-model.md §2.2`)
- [X] T009 [P] [US1] Create `lib/features/search/domain/entities/search_result_item.dart` — full `SearchResultItem extends Equatable` with 12 fields (`id`, `title`, `propertyType`, `purpose`, `governorateNameAr`, `governorateNameEn`, `cityNameAr`, `cityNameEn`, `primaryAmount`, `primaryCurrency`, `mainImagePath?`, `publishedAt`) and `props: [id]` (exact body from `data-model.md §2.1`; imports `PropertyType` + `ListingPurpose` from `lib/features/listing_form/domain/entities/listing.dart`)
- [X] T010 [US2] Create `lib/features/search/domain/entities/filter_state.dart` — full immutable value object from `data-model.md §2.4`: 15 fields, `static const empty = FilterState()`, `bool get isEmpty` (checks all nullable fields), `copyWith()` with boolean clear sentinels for all nullable fields (`clearQuery`, `clearPurpose`, `clearPropertyType`, `clearGovernorateId`, `clearCityId`, `clearAreaId`, `clearPriceMin`, `clearPriceMax`, `clearRooms`, `clearBathrooms`, `clearAreaSize`), `props` covering all 15 fields
- [X] T011 [US1] Create `lib/features/search/domain/repositories/search_repository.dart` — abstract class `SearchRepository` with one method: `Future<Either<Failure, List<SearchResultItem>>> search({required FilterState filters, required SortOrder sort, SearchCursor? cursor, int limit = 20})`; no `package:supabase_flutter` import
- [X] T012 [US1] Create `lib/features/search/domain/usecases/search_listings_usecase.dart` — `@injectable` class wrapping `SearchRepository.search()`; returns `Either<Failure, List<SearchResultItem>>`; constructor injects `SearchRepository`

**Checkpoint**: `dart analyze lib/features/search/domain/` passes with zero errors. No `package:supabase_flutter` import anywhere in `lib/features/search/domain/`.

---

## Phase 3 — Sub-Phase C: ARB Keys (Wave 1)

**Goal**: Add all 34 bilingual ARB keys and regenerate `AppLocalizations`. Blocks all search UI widgets (localization lint guard rejects any widget referencing an absent key).

**Wave**: 1 — parallel with Phase 1 (SQL) and Phase 2 (Domain).

- [X] T013 [P] [US1][US2][US3] Add all 34 Phase 14 search/filter ARB keys to `lib/l10n/app_ar.arb` — four groups per `data-model.md §3`: Search Page Chrome (`search_placeholder`, `search_filters_button`, `search_sort_label`, `search_results_count` with `{count}` ICU param); Sort Options (`search_sort_newest`, `search_sort_price_asc`, `search_sort_price_desc`); Filter Sheet Chrome (`search_filter_sheet_title`, `search_filter_apply`, `search_filter_reset`); Filter Dimensions (17 keys from `search_filter_purpose_label` through `search_filter_area_size_label`); Empty/Error States (`search_empty_title`, `search_empty_subtitle`, `search_empty_clear_filters`, `search_arabic_hint` with `{suggestion}` param, `search_loading`, `search_error_message`, `search_error_retry`)
- [X] T014 [P] [US1][US2][US3] Add all 34 Phase 14 search/filter ARB keys to `lib/l10n/app_en.arb` — same 34 keys with English values from `data-model.md §3`
- [X] T015 [US1][US2][US3] Extend `lib/l10n/app_strings.dart` `_DebugAppLocalizations` subclass with concrete getters for all 34 new keys using the same pattern as Phase 13 additions — every abstract getter from `AppLocalizations` for a Phase 14 key must have a concrete implementation returning the English string
- [X] T016 [US1][US2][US3] Run `flutter gen-l10n` (or `flutter pub run intl_utils:generate` per project setup) to regenerate `AppLocalizations`; confirm zero errors; confirm `AppLocalizations.of(context).searchPlaceholder` (etc.) accessible

**Checkpoint**: `dart analyze lib/l10n/` passes. Running `grep -r "search_placeholder" lib/l10n/` finds the key in both ARB files and in the generated Dart output.

---

## Phase 4 — Sub-Phase D: Data Layer (Wave 2)

**Goal**: Supabase datasource (ONLY file importing `package:supabase_flutter` in the search feature), DTO, repository implementation, DI wiring. Depends on Phase 1 (RPC in DB) and Phase 2 (domain types).

**Wave**: 2 — after Wave 1 completes; parallel with Phase 5 (Filter Sheet Widget).

- [X] T017 [P] [US1] Create `lib/features/search/data/dtos/search_result_item_dto.dart` — `SearchResultItemDto` class with `fromJson(Map<String, dynamic> json)` factory matching the 12 columns returned by `search_result_row` composite type (`id` UUID→String, `title` text, `property_type` text→`PropertyType.values.byName()`, `purpose` text→`ListingPurpose.values.byName()`, `governorate_name_ar`, `governorate_name_en`, `city_name_ar`, `city_name_en`, `primary_amount` numeric→double, `primary_currency` text, `main_image_path` nullable text, `published_at` timestamptz→`DateTime.parse()`); `SearchResultItem toEntity()` method
- [X] T018 [US1][US2] Create `lib/features/search/data/datasources/supabase_search_datasource.dart` — `@injectable` class importing `package:supabase_flutter` (the ONLY such file in `lib/features/search/`); `fetchPage({required FilterState filters, required SortOrder sort, SearchCursor? cursor, int limit = 20})` method: (1) if `filters.priceCurrency` is set and not USD/SYP, call `client.rpc('latest_rates_for_base', params: {'p_base': filters.priceCurrency})` and compute `priceMinUsd`, `priceMaxUsd`, `priceMinSyp`, `priceMaxSyp` from the rate (R-75); if no rate available, throw `ServerFailure` with localized message; (2) build param map from `FilterState` and `SearchCursor` per full parameter table in `contracts/phase14-search-listings-rpc.md §Parameter Table`; map `SortOrder.newest` → `'newest'`, `priceAsc` → `'price_asc'`, `priceDesc` → `'price_desc'`; map `CountFilterMode.exactly` → `'exactly'`, `atLeast` → `'at_least'`; map `NewestCursor` → `p_cursor_published_at` + `p_cursor_id_newest`; map `PriceCursor` → `p_cursor_price_amount` + `p_cursor_id_price`; (3) call `await client.rpc('search_listings', params: paramMap)`; (4) parse result list via `SearchResultItemDto.fromJson`; (5) return `List<SearchResultItem>` or throw `ServerFailure`
- [X] T019 [US1] Create `lib/features/search/data/repositories/search_repository_impl.dart` — `@Injectable(as: SearchRepository)` class implementing `SearchRepository`; delegates to `SupabaseSearchDatasource.fetchPage()`; wraps any exception in `ServerFailure` using existing `lib/core/errors/failure.dart` pattern; returns `Either<Failure, List<SearchResultItem>>`
- [X] T020 [US1] Add `@injectable` annotations for `SupabaseSearchDatasource`, `SearchRepositoryImpl` (as `SearchRepository`), `SearchListingsUseCase` to `lib/core/di/injection.dart`; run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart`; verify `GetIt.I<SearchListingsUseCase>()` resolves without throwing

**Checkpoint**: Calling `GetIt.I<SearchRepository>().search(filters: FilterState.empty, sort: SortOrder.newest)` returns a non-empty `Right(List<SearchResultItem>)` on a device connected to the live Supabase project (requires at least one approved listing in DB).

---

## Phase 5 — Sub-Phase E: Filter Sheet Widget — US2 (Wave 2)

**Goal**: `PriceRangeInput` and `SearchFilterSheet` — the modal bottom sheet that surfaces all 9 filter dimensions to the user. Depends on Phase 2 (FilterState, CountFilterMode) and Phase 3 (ARB keys generated).

**Wave**: 2 — parallel with Phase 4 (Data Layer); no file conflicts (different directories).

- [X] T021 [US2] Create `lib/features/search/presentation/widgets/price_range_input.dart` — `PriceRangeInput extends StatelessWidget` with `TextEditingController minController`, `maxController`, `GlobalKey<FormState> formKey` as constructor params; two `TextFormField` widgets side-by-side, numeric keyboard, hints `search_filter_price_min_hint` / `search_filter_price_max_hint`; validator on max field: if both fields non-empty and `double.parse(min) > double.parse(max)` → return `AppLocalizations.of(context).searchFilterPriceMinMaxError`; all padding via `EdgeInsetsDirectional`; validation triggered by caller's `formKey.currentState!.validate()` per `contracts/phase14-filter-sheet.md §PriceRangeInput Contract`
- [X] T022 [US2] Create `lib/features/search/presentation/widgets/search_filter_sheet.dart` — `SearchFilterSheet extends StatefulWidget` with `FilterState initialFilters`, `ValueChanged<FilterState> onApply`; local state mirrors all `FilterState` fields; composition: `DraggableScrollableSheet(initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.4, expand: false)` wrapping `SingleChildScrollView` with `Padding(EdgeInsetsDirectional.all(16))` wrapping `Column([ _SheetHandle(), _SheetTitle(search_filter_sheet_title), _PurposeSection() (ChoiceChip per ListingPurpose, single-select or null), _PropertyTypeSection() (ChoiceChip per PropertyType, single-select or null), _LocationSection() (cascading DropdownButton for governorate→city→area via Phase 8 LocationRepository injected via GetIt; governorate list loaded once on initState; city list reloaded on governorate change; area list reloaded on city change; clearing governorate clears city + area), _PriceRangeSection() (PriceRangeInput + currency DropdownButton from Phase 9 CurrencyRepository; if no exchange rate for selected currency: disable price inputs + show search_filter_price_no_exchange_rate text), _RoomsSection() (SegmentedButton<CountFilterMode> with exactly/at_least + numeric stepper; stepper deactivates dimension when count reaches 0), _BathroomsSection() (same pattern), _AreaSizeSection() (two TextFormField min/max, numeric), _ActionRow(Apply: formKey.validate() → onApply(localState) + Navigator.pop; Reset: setState(FilterState.empty) no close) ]); all strings via AppLocalizations ARB keys from Phase 3; all padding via EdgeInsetsDirectional; TextAlign.start on all labels per `contracts/phase14-filter-sheet.md`

**Checkpoint**: Tapping Filters button opens the sheet; all 9 dimensions render; selecting Purpose + PropertyType + tapping Apply calls `onApply` with correct `FilterState`; tapping Reset clears all controls and sheet stays open; entering min > max and tapping Apply shows inline error without closing the sheet.

---

## Phase 6 — Sub-Phase F: SearchPage + SearchBloc + Routing — US1/US3/US4/US5 (Wave 3)

**Goal**: BLoC state machine, all search presentation files, `/search` route, and DI registration. Assembles the complete search experience. Depends on Phase 4 (DI + use case) and Phase 5 (SearchFilterSheet).

**Wave**: 3 — sequential after Wave 2 completes.

- [X] T023 [P] [US1][US3] Create `lib/features/search/presentation/bloc/search_event.dart` — `sealed class SearchEvent` with concrete events: `SearchQueryChanged({required String query})`, `SearchFiltersApplied({required FilterState filters})`, `SearchSortChanged({required SortOrder sort})`, `SearchNextPageRequested()` (const), `SearchRefreshRequested()` (const)
- [X] T024 [P] [US1][US4] Create `lib/features/search/presentation/bloc/search_state.dart` — `SearchState extends Equatable` with fields: `results: List<SearchResultItem>`, `filters: FilterState`, `sort: SortOrder`, `cursor: SearchCursor?`, `status: SearchStatus`, `failure: Failure?`, `hasNextPage: bool`; include `enum SearchStatus { initial, loading, success, failure }`; include `bool get isArabicQuery` (returns `filters.query != null && filters.query!.runes.any((r) => r >= 0x0600 && r <= 0x06FF)`); include `SearchCursor` sealed class with `NewestCursor({required DateTime publishedAt, required String id})` and `PriceCursor({required double priceAmount, required String id})` per `data-model.md §2.5`; `SearchState.initial()` factory
- [X] T025 [US1][US3][US4][US5] Create `lib/features/search/presentation/bloc/search_bloc.dart` — `@injectable SearchBloc extends Bloc<SearchEvent, SearchState>`; constructor receives `SearchListingsUseCase` from DI; handles events: `SearchFiltersApplied`: cancel `_debounce` timer if active; set `status=loading`, reset cursor to null, call `SearchListingsUseCase.execute(event.filters, state.sort, cursor: null, limit: 20)`, on success emit `status=success, results=list, hasNextPage=(list.length==20), cursor=_makeCursor(list.last, state.sort)`, on failure emit `status=failure`; `SearchSortChanged`: copy filters, reset cursor, re-fetch with new sort; `SearchQueryChanged`: debounce 400ms then dispatch `SearchFiltersApplied(state.filters.copyWith(query: event.query))` (use a Timer? _debounce field: on each SearchQueryChanged event call _debounce?.cancel() then _debounce = Timer(Duration(milliseconds: 400), () => add(SearchFiltersApplied(...))) — dart:async only, no new package; override close() to call _debounce?.cancel()); `SearchNextPageRequested`: if `state.status == SearchStatus.loading || !state.hasNextPage` skip; else fetch next page with current cursor, append results; `SearchRefreshRequested`: reset cursor, re-fetch current filters+sort; `_makeCursor`: returns `NewestCursor(publishedAt: item.publishedAt, id: item.id)` for `SortOrder.newest`, `PriceCursor(priceAmount: item.primaryAmount, id: item.id)` for price sorts
- [X] T026 [P] [US3] Create `lib/features/search/presentation/widgets/inline_sort_control.dart` — `InlineSortControl extends StatelessWidget`; `BlocBuilder<SearchBloc, SearchState>` inside; `DropdownButton<SortOrder>(value: state.sort, items: [DropdownMenuItem(SortOrder.newest, Text(l10n.searchSortNewest)), DropdownMenuItem(SortOrder.priceAsc, Text(l10n.searchSortPriceAsc)), DropdownMenuItem(SortOrder.priceDesc, Text(l10n.searchSortPriceDesc))], onChanged: (v) => context.read<SearchBloc>().add(SearchSortChanged(sort: v!)))` (R-84)
- [X] T027 [P] [US1] Create `lib/features/search/presentation/widgets/search_result_card.dart` — `SearchResultCard extends StatelessWidget` with `SearchResultItem item`; card layout mirrors Phase 13 `HomeListingCard` visual design (main image via `CachedNetworkImage(item.mainImagePath)`, title text, governorate/city name (locale-aware: `Localizations.localeOf(context).languageCode == 'ar' ? item.governorateNameAr : item.governorateNameEn`), primary price + currency, purpose/type chip); does NOT import anything from `lib/features/home/`; `onTap: () => context.go('${AppRoutes.listingDetails}/${item.id}')`
- [X] T028 [US1][US2][US3][US4][US5] Create `lib/features/search/presentation/pages/search_page.dart` — `SearchPage extends StatelessWidget` with `final PropertyType? initialPropertyType`; root widget is `BlocProvider<SearchBloc>(create: (_) => GetIt.I<SearchBloc>()..add(SearchFiltersApplied(filters: initialPropertyType != null ? FilterState(propertyType: initialPropertyType) : FilterState.empty)), child: Scaffold(appBar: AppBar(leading: Navigator.canPop(context) ? const BackButton() : IconButton(icon: Icon(Icons.home), onPressed: () => context.go(AppRoutes.home))), body: Column([_SearchBar(), _SortAndFiltersRow(), Expanded(BlocBuilder...)])))`: `_SearchBar`: `TextField(autofocus: initialPropertyType == null, hintText: l10n.searchPlaceholder, onSubmitted: (v) => bloc.add(SearchFiltersApplied(filters: state.filters.copyWith(query: v.isEmpty ? null : v))), onChanged: debounced via SearchQueryChanged)` + visible clear button (×) when text non-empty dispatching `SearchFiltersApplied(filters: state.filters.copyWith(clearQuery: true))`; `_SortAndFiltersRow`: `Row(mainAxisAlignment: spaceBetween, [Row([Text(l10n.searchSortLabel), InlineSortControl()]), FiltersButton(hasActiveFilters: !state.filters.isEmpty, onTap: () => showModalBottomSheet(isScrollControlled: true, builder: (_) => SearchFilterSheet(initialFilters: state.filters, onApply: (f) => bloc.add(SearchFiltersApplied(filters: f)))))])`; `BlocBuilder` switch: `initial` → `Center(Text(l10n.searchPlaceholder))`; `loading` → `Center(CircularProgressIndicator())`; `success` with `state.results.isEmpty` → empty-state column (`Icon(Icons.search_off)`, `Text(l10n.searchEmptyTitle)`, `Text(l10n.searchEmptySubtitle)`, `TextButton(l10n.searchEmptyClearFilters, onPressed: () => bloc.add(SearchFiltersApplied(filters: FilterState.empty)))`, if `state.isArabicQuery && state.results.length < 3` show `Text(l10n.searchArabicHint(suggestion: _buildSuggestion(state.filters.query!)))`); `success` with results → `_ResultsListView`: if `state.isArabicQuery && state.results.length < 3` prepend a `Container(color: Theme.of(context).colorScheme.surfaceVariant, padding: EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8), child: Text(l10n.searchArabicHint(suggestion: _buildSuggestion(state.filters.query!))))` banner above the ListView (covers FR-019 sparse case of 1-2 results); `ListView.builder(itemCount: state.results.length + (state.hasNextPage ? 1 : 0), itemBuilder: (_, i) { if (i == state.results.length) { bloc.add(const SearchNextPageRequested()); return const Center(CircularProgressIndicator()); } return SearchResultCard(item: state.results[i]); })`; `failure` → `Column([Text(l10n.searchErrorMessage), TextButton(l10n.searchErrorRetry, onPressed: () => bloc.add(const SearchRefreshRequested()))])`
- [X] T029 [US1] Add `static const String search = '/search'` to `AppRoutes` in `lib/core/routing/app_router.dart`; add `GoRoute(path: AppRoutes.search, builder: (context, state) => SearchPage(initialPropertyType: state.extra as PropertyType?))` to the router's routes list (place alongside existing Phase 13 routes)
- [X] T030 [US1] Add `@injectable` annotation for `SearchBloc` to `lib/core/di/injection.dart`; run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart`; run `flutter analyze` and confirm zero errors; run `flutter run --dart-define-from-file=.env.json` on device and verify app starts without DI errors

**Checkpoint**: Run `flutter run --dart-define-from-file=.env.json`; navigate to `/search`; type a keyword → results appear within 2 seconds; sort control reorders results; Filters button opens sheet; back from ListingDetailsPage restores filter state.

---

## Phase 7 — Sub-Phase G: Home Screen Rewiring — SC-011 (Wave 4)

**Goal**: Replace the two Phase 13 Coming-soon snackbar stubs with real navigation. Depends on Phase 6 (`AppRoutes.search` constant and `SearchPage` GoRoute must exist).

**Wave**: 4 — sequential after Wave 3 completes.

- [ ] T031 [US1] Update `lib/features/home/presentation/widgets/hero_search_bar.dart` — replace the `onTap` handler body `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.homeSearchComingSoon)));` with `context.go(AppRoutes.search);`; add `import 'package:alnujom/core/routing/app_router.dart';` if not already present; remove the `l10n.homeSearchComingSoon` reference from this file (the ARB key itself is NOT deleted from `app_ar.arb` / `app_en.arb`); no other structural changes per `contracts/phase14-home-rewiring.md §hero_search_bar.dart Change`
- [ ] T032 [US1] Update `lib/features/home/presentation/widgets/property_type_shortcut_row.dart` — for each chip's `onTap`, replace `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.homePropertyShortcutComingSoon)));` with `context.go(AppRoutes.search, extra: type);` where `type` is the chip's `PropertyType` enum value; add `AppRoutes` import if not already present; remove `l10n.homePropertyShortcutComingSoon` reference from this file (ARB key itself preserved); no structural changes per `contracts/phase14-home-rewiring.md §property_type_shortcut_row.dart Change`

**Checkpoint**: From Home screen: (1) tapping hero search bar opens `SearchPage` with keyboard focused and no filters pre-applied; (2) tapping "Apartments" chip opens `SearchPage` pre-filtered to `PropertyType.apartment`; (3) no snackbar appears for either entry point (SC-011).

---

## Phase 8 — QA & Polish

**Goal**: Code quality grep gates + manual two-device UI verification covering all 11 SCs. No new automated tests.

- [ ] T033 [P] Run grep gate 1 per `quickstart.md Step 4`: `grep -r "status.*approved" lib/features/search/ --include="*.dart"` — expected: zero matches (Constitution III: no app-layer approved filter)
- [ ] T034 [P] Run grep gate 2 per `quickstart.md Step 4`: `grep -rl "package:supabase_flutter" lib/features/search/ --include="*.dart"` — expected: exactly ONE file (`supabase_search_datasource.dart`)
- [ ] T035 [P] Run grep gate 3 per `quickstart.md Step 4`: `grep -r "#[0-9A-Fa-f]\{6\}" lib/features/search/presentation/ --include="*.dart"` — expected: zero matches (no hardcoded hex colors; design tokens only)
- [ ] T036 [P] Run grep gate 4 per `quickstart.md Step 4`: `grep -r '"[^"]\{3,\}"' lib/features/search/presentation/ --include="*.dart" | grep -v "//.*\"" | grep -v "l10n\." | grep -v "ARB\|key\|_\|test"` — expected: zero matches for user-visible strings not routed through `AppLocalizations`
- [ ] T037 Run `flutter run --dart-define-from-file=.env.json` on Infinix Note 8; execute `quickstart.md` steps 5–17 in full (SC-001 through SC-011); complete the SC Matrix in `quickstart.md Step 19` — mark each of the 11 SC rows Pass or Fail; all 11 must pass before declaring Phase 14 complete

**Checkpoint**: All 4 grep gates show zero violations AND all 11 SC rows in `quickstart.md Step 19` marked Pass.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Sub-Phase A — Backend SQL)**: No dependencies — starts immediately. T001–T003 are [P] (write files in parallel). T004→T005→T006 sequential (apply in order; each confirms the prior migration landed).
- **Phase 2 (Sub-Phase B — Domain Layer)**: No dependencies — starts immediately in parallel with Phase 1. T007, T008, T009 are [P]; T010 depends on T007 (imports `CountFilterMode`); T011 depends on T009, T010; T012 depends on T011.
- **Phase 3 (Sub-Phase C — ARB Keys)**: No dependencies — starts immediately in parallel with Phases 1+2. T013 and T014 are [P]; T015 depends on T013+T014; T016 depends on T015.
- **Phase 4 (Sub-Phase D — Data Layer)**: Depends on Phase 1 T006 (RPC in DB) AND Phase 2 T012 (domain types). T017 is [P] with T018; T019 depends on T017+T018; T020 depends on T019.
- **Phase 5 (Sub-Phase E — Filter Sheet)**: Depends on Phase 2 T010 (`FilterState`), T007 (`CountFilterMode`) AND Phase 3 T016 (`AppLocalizations` regenerated). T021 is [P] with T022 start (different files); T022 is the main task.
- **Phase 6 (Sub-Phase F — SearchPage + Bloc)**: Depends on Phase 4 T020 (DI registered) AND Phase 5 T022 (`SearchFilterSheet` available). T023 and T024 are [P]; T025 depends on T023+T024; T026 and T027 are [P] with each other and with T025 start; T028 depends on T025+T026+T027; T029 depends on T028; T030 depends on T029.
- **Phase 7 (Sub-Phase G — Home Rewiring)**: Depends on Phase 6 T029 (`AppRoutes.search` defined). T031 and T032 are [P].
- **Phase 8 (QA)**: Depends on Phase 7 (all implementation complete). T033–T036 are [P]; T037 sequential after grep gates pass.

### Parallel Opportunities

**Wave 1 (Phases 1+2+3)** — three agents run simultaneously with zero file conflicts:
- Agent A: Phase 1 — works exclusively in `supabase/migrations/`
- Agent B: Phase 2 — works exclusively in `lib/features/search/domain/`
- Agent C: Phase 3 — works exclusively in `lib/l10n/`

**Wave 2 (Phases 4+5)** — two agents run simultaneously:
- Agent D: Phase 4 — `lib/features/search/data/` + `lib/core/di/` (update + build_runner)
- Agent E: Phase 5 — `lib/features/search/presentation/widgets/` (price_range_input + filter_sheet only)

**Wave 3 (Phase 6 alone)** — single agent assembles all prior artifacts.

**Wave 4 (Phase 7 alone)** — single agent: two widget file updates.

**Wave 5 (Phase 8 alone)** — single agent: grep gates [P] then manual device verification.

---

## Touch-Fan Table

| Phase | Sub-Phase | Files Modified (CREATE or UPDATE) |
|-------|-----------|----------------------------------|
| Phase 1 | A — Backend SQL | `supabase/migrations/20260525120001_listings_search_vector.sql` (CREATE), `supabase/migrations/20260525120002_create_v_listings_public.sql` (CREATE), `supabase/migrations/20260525120003_create_search_listings_rpc.sql` (CREATE) |
| Phase 2 | B — Domain Layer | `lib/features/search/domain/entities/count_filter_mode.dart` (CREATE), `lib/features/search/domain/entities/sort_order.dart` (CREATE), `lib/features/search/domain/entities/search_result_item.dart` (CREATE), `lib/features/search/domain/entities/filter_state.dart` (CREATE), `lib/features/search/domain/repositories/search_repository.dart` (CREATE), `lib/features/search/domain/usecases/search_listings_usecase.dart` (CREATE) |
| Phase 3 | C — ARB Keys | `lib/l10n/app_ar.arb` (UPDATE), `lib/l10n/app_en.arb` (UPDATE), `lib/l10n/app_strings.dart` (UPDATE) |
| Phase 4 | D — Data Layer | `lib/features/search/data/dtos/search_result_item_dto.dart` (CREATE), `lib/features/search/data/datasources/supabase_search_datasource.dart` (CREATE), `lib/features/search/data/repositories/search_repository_impl.dart` (CREATE), `lib/core/di/injection.dart` (UPDATE — datasource/repo/usecase annotations), `lib/core/di/injection.config.dart` (REGENERATED) |
| Phase 5 | E — Filter Sheet | `lib/features/search/presentation/widgets/price_range_input.dart` (CREATE), `lib/features/search/presentation/widgets/search_filter_sheet.dart` (CREATE) |
| Phase 6 | F — SearchPage + Bloc + Routing | `lib/features/search/presentation/bloc/search_event.dart` (CREATE), `lib/features/search/presentation/bloc/search_state.dart` (CREATE), `lib/features/search/presentation/bloc/search_bloc.dart` (CREATE), `lib/features/search/presentation/widgets/inline_sort_control.dart` (CREATE), `lib/features/search/presentation/widgets/search_result_card.dart` (CREATE), `lib/features/search/presentation/pages/search_page.dart` (CREATE), `lib/core/routing/app_router.dart` (UPDATE — AppRoutes.search + GoRoute), `lib/core/di/injection.dart` (UPDATE — SearchBloc annotation), `lib/core/di/injection.config.dart` (REGENERATED) |
| Phase 7 | G — Home Rewiring | `lib/features/home/presentation/widgets/hero_search_bar.dart` (UPDATE), `lib/features/home/presentation/widgets/property_type_shortcut_row.dart` (UPDATE) |
| Phase 8 | QA | No source files — grep commands + manual device walkthrough |

**Conflict-prone shared files** (touched by multiple phases — wave ordering eliminates runtime conflicts):
- `lib/core/di/injection.dart` — updated in Phase 4 (Wave 2) and again in Phase 6 (Wave 3). Phase 4 agent finishes before Phase 6 starts. No merge conflict.
- `lib/core/di/injection.config.dart` — regenerated in Phase 4 (Wave 2) and Phase 6 (Wave 3). Same wave-ordering prevents conflict.

**Merge order recommendation for orchestrator**: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8. Within Wave 1: commit Phase 3 (ARB) last because `flutter gen-l10n` output is a generated file that the other Wave 1 agents do not touch.

---

## Dependency Audit

Re-reading the Phase Dependencies section above — every declared dependency names a specific file or exported symbol:

1. **Phase 4 depends on Phase 1**: `supabase_search_datasource.dart` calls `client.rpc('search_listings', ...)` — the `search_listings` SECURITY DEFINER function must exist in the remote Supabase DB, created by `supabase/migrations/20260525120003_create_search_listings_rpc.sql` (Phase 1 T006). ✓
2. **Phase 4 depends on Phase 2**: `SearchRepositoryImpl` implements abstract class `SearchRepository` from `lib/features/search/domain/repositories/search_repository.dart` (T011); `SupabaseSearchDatasource` maps JSON to `SearchResultItem` from `lib/features/search/domain/entities/search_result_item.dart` (T009); method signature accepts `FilterState` from `lib/features/search/domain/entities/filter_state.dart` (T010) and `SortOrder` from `lib/features/search/domain/entities/sort_order.dart` (T008). ✓
3. **Phase 5 depends on Phase 2**: `SearchFilterSheet` constructor `initialFilters: FilterState` typed from `lib/features/search/domain/entities/filter_state.dart` (T010); `SegmentedButton<CountFilterMode>` typed from `lib/features/search/domain/entities/count_filter_mode.dart` (T007). ✓
4. **Phase 5 depends on Phase 3**: `SearchFilterSheet` references `AppLocalizations.of(context).searchFilterApply` (and 30+ other keys) — keys added to `app_ar.arb` + `app_en.arb` (T013+T014) and `AppLocalizations` regenerated (T016). The Flutter localization lint guard rejects widget build if any referenced key is absent. ✓
5. **Phase 6 depends on Phase 4**: `SearchBloc` constructor receives `SearchListingsUseCase` via `GetIt.I<SearchBloc>()`; the use case is registered in `lib/core/di/injection.config.dart` only after Phase 4's `build_runner` run (T020). ✓
6. **Phase 6 depends on Phase 5**: `SearchPage` imports and opens `lib/features/search/presentation/widgets/search_filter_sheet.dart` (T022) as a `showModalBottomSheet` on `FiltersButton` tap (T028). ✓
7. **Phase 7 depends on Phase 6**: `hero_search_bar.dart` calls `context.go(AppRoutes.search)` — `AppRoutes.search` constant defined in `lib/core/routing/app_router.dart` by T029 (Phase 6). `property_type_shortcut_row.dart` calls `context.go(AppRoutes.search, extra: type)` — the GoRoute builder `SearchPage(initialPropertyType: state.extra as PropertyType?)` wired in Phase 6 T029 receives this `extra` value. ✓

**Self-audit**: All 7 declared dependencies name a specific file path or exported symbol. Zero dependency lines without a named consumer. ✓

---

## Wave Plan

| Wave | Phases | Count | Justification |
|------|--------|-------|---------------|
| Wave 1 | Phase 1 (Backend SQL), Phase 2 (Domain Layer), Phase 3 (ARB Keys) | 3 | Fully parallel — no shared files, each agent works in a distinct directory tree |
| Wave 2 | Phase 4 (Data Layer), Phase 5 (Filter Sheet Widget) | 2 | Parallel — Phase 4 in `search/data/` + `core/di/`; Phase 5 in `search/presentation/widgets/`; no file overlap |
| Wave 3 | Phase 6 (SearchPage + Bloc + Routing) | 1 | Sequential — assembles all prior artifacts; `app_router.dart` and `injection.dart` both updated here |
| Wave 4 | Phase 7 (Home Rewiring) | 1 | Sequential — two widget file updates; `AppRoutes.search` must already be defined |
| Wave 5 | Phase 8 (QA) | 1 | Sequential — grep gates then manual device verification; requires full implementation complete |

All wave caps (max 4 per wave unless docs-only) satisfied.

Execute via: `/wave all --auto` using this wave plan directly.

---

## Model Routing per Phase

- **Phase 1 (Backend SQL)**: **Opus** — SECURITY DEFINER function with cursor-pagination invariants (two cursor shapes, keyset-pagination correctness), composite type idempotency block, `EXPLAIN (ANALYZE, BUFFERS)` GIN index verification, approved-status + publish-window guard enforcement in SQL, anonymous role smoke test.
- **Phase 2 (Domain Layer)**: **Sonnet** — pure Dart entity scaffolding, enum declarations, abstract class, sentinel-copyWith pattern.
- **Phase 3 (ARB Keys)**: **Sonnet** — l10n key addition to two ARB files, debug subclass extension, `flutter gen-l10n` invocation.
- **Phase 4 (Data Layer)**: **Opus** — client-side FX rate conversion (R-75: two-RPC composition, rate fetch → bound conversion → per-currency param pairs), discriminated cursor union (`NewestCursor` vs `PriceCursor`) mapped to 4 distinct SQL parameters, `Either<Failure, T>` error boundary at Supabase system boundary.
- **Phase 5 (Filter Sheet Widget)**: **Sonnet** — stateful widget with local state management, `SegmentedButton<CountFilterMode>`, cascading location dropdowns, `DraggableScrollableSheet`, Apply/Reset flow wiring.
- **Phase 6 (SearchPage + Bloc + Routing)**: **Opus** — BLoC state machine with concurrency guard (`SearchNextPageRequested` skipped when `status==loading`), 400ms debounce event transformer, cursor-based pagination state transitions, BLoC lifetime invariant (R-77: scoped to route, not global), composable filter+sort+cursor state (FR-009), `GoRouterState.extra` type-casting for pre-filter entry.
- **Phase 7 (Home Rewiring)**: **Sonnet** — two-line tap-handler replacement in two files.
- **Phase 8 (QA)**: **Sonnet** — grep gate shell commands + manual device walkthrough documentation.

---

## Implementation Strategy

### MVP First (US1 Keyword Search Only)

1. Complete Wave 1 (Phases 1+2+3) → Foundation ready
2. Complete Phase 4 (Data Layer) → First data access available
3. Complete Phase 6 core tasks T023–T030 (SearchPage + BLoC + basic results list, without filter sheet wiring) → Keyword search functional
4. Complete Phase 7 (Home Rewiring) → Entry points connected
5. **STOP and VALIDATE**: SC-001 (Arabic keyword) + SC-002 (Latin keyword) + SC-011 (entry points)

### Full Delivery

1. Wave 1 (Phases 1+2+3) in parallel → All foundations
2. Wave 2 (Phases 4+5) in parallel → Data + Filter UI
3. Wave 3 (Phase 6) → Complete search experience
4. Wave 4 (Phase 7) → Home wired
5. Wave 5 (Phase 8) → QA passes, all 11 SCs confirmed

### Notes

- `- [ ]` checkboxes MUST be flipped to `- [X]` in the same commit as the implementation. No cleanup passes.
- Each checkpoint must be verified before marking the phase complete.
- The `injection.config.dart` file is regenerated (not manually edited) — run `build_runner` as specified in T020 and T030.
- Migrations: read the file before applying; do NOT re-apply a migration that already exists in the tracker (per `project_supabase_mcp_apply_migration.md`).
- All `flutter run` commands MUST include `--dart-define-from-file=.env.json` or Supabase.initialize is skipped and the app red-screens (per `project_dart_defines.md`).
