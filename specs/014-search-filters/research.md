# Research Decisions: Search & Filters (Phase 14)

**Feature**: `014-search-filters`
**Created**: 2026-05-24
**Status**: Locked — do not change without updating `plan.md` and all downstream contracts.

All decisions below are **locked** for Phase 14. Each entry names the decision, the chosen option, the rationale, and the alternatives considered. Numbers continue the project-wide sequence (R-61..R-72 belong to Phase 13).

---

## R-73 — `search_vector` column scope: `title` + `address_text` only; `description` via ILIKE

**Decision**: The `tsvector GENERATED ALWAYS AS STORED` column added to `public.listings` covers only `title` and `address_text`:
```sql
to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(address_text,''))
```
The `description` field lives in `public.listing_details` (a separate table introduced in Phase 10). It is searched in the `search_listings` RPC via an additional `ILIKE '%' || p_query || '%'` predicate joined against `listing_details`.

**Rationale**: Generated columns must reference only columns in the same table (`public.listings`). `description` is in `listing_details` and cannot be included in a generated column on `listings` without a trigger-based approach. The ILIKE supplement is acceptable at Phase 14 data volumes; description searches are lower-frequency than title/address searches. The GIN-indexed `tsvector` handles the high-frequency keyword queries efficiently; the ILIKE on description is an ancillary supplement. If description full-text search becomes a performance concern in production, Phase 14's `contracts/phase14-search-listings-rpc.md` documents the path for promoting it to a separate GIN-indexed column on `listing_details`.

**Alternatives considered**:
- **Trigger-maintained denormalized column on `listings`**: Would keep all three fields in one `tsvector` but adds trigger maintenance complexity and violates the "no trigger side-effects without constitution review" convention. Deferred.
- **Full-text search on `listing_details` only**: Misses title/address matching, which are the primary search fields. Rejected.
- **Skip `description` search entirely**: Acceptable for Phase 14 given that most user intent is captured by title + address. Rejected because spec FR-002 explicitly names description as a search target.

---

## R-74 — SQL RPC (`search_listings`) rather than raw PostgREST for query composition

**Decision**: Phase 14 uses a `SECURITY DEFINER` SQL function `search_listings(...)` called via `client.rpc('search_listings', params: {...})` rather than chaining PostgREST filter parameters in the URL.

**Rationale**: Nine optional facet dimensions + full-text search + price-range currency conversion + dual-mode room/bathroom counting + cursor pagination across two cursor shapes (timestamp vs. price) would produce an unreadable and fragile PostgREST URL. A SQL function gives full control over query logic, cursor construction, and the approved-listing guard within a single transaction. The SECURITY DEFINER posture allows the function to run with a fixed role that has read access to the joined tables while the calling role (anon/authenticated) is restricted — matching the approved use of RPC for complex read queries per Constitution III's "Edge Functions or RPCs that re-check permissions server-side" provision.

**Alternatives considered**:
- **Raw PostgREST filter chains**: Readable for simple queries; becomes a URL-encoding nightmare for nine optional dimensions + full-text + cursor. Rejected.
- **Edge Function (TypeScript)**: Adds deployment overhead and cold-start latency for a pure read query. Rejected; SQL function is sufficient.
- **Client-side Dart filtering**: Fetches too many rows; violates the server-authoritative filter principle. Rejected.

---

## R-75 — Price-range currency conversion is client-side

**Decision**: The `SupabaseSearchDatasource` fetches the latest exchange rate via the existing `latest_rates_for_base` RPC (Phase 9 — `supabase/migrations/20260518120006_create_latest_rates_for_base_rpc.sql`). It converts the user's min/max price bounds from the chosen filter currency to each stored currency in the listing (USD and SYP are the primary two), then passes pre-converted `p_price_min_usd`, `p_price_max_usd`, `p_price_min_syp`, `p_price_max_syp` parameters directly to `search_listings`. The RPC compares listing prices in their native currency using the pre-converted bounds.

**Rationale**: Keeping conversion in the RPC SQL would require cross-referencing the `exchange_rates` table inside the search function body, adding a join and a potential race condition between the rate lookup and the price comparison. Client-side conversion is simpler, keeps the RPC SQL readable, and matches the Phase 9 pattern already in use for the home feed price display. If no exchange rate is available for the chosen filter currency, the datasource propagates a `ServerFailure` carrying a `noExchangeRateAvailable` flag; the UI disables the price-range filter for that currency with a localized message.

**Alternatives considered**:
- **Server-side conversion inside the RPC**: Adds a `exchange_rates` join to the search query; makes EXPLAIN harder to reason about. Deferred as a future optimization if cross-currency filtering becomes a performance bottleneck.
- **Convert all listing prices to a single canonical currency at write time**: Requires a background job and schema change. Out of scope for Phase 14.

---

## R-76 — Cursor pagination: two cursor shapes based on sort order

**Decision**: 
- **Newest sort** (`newest`): cursor is `(published_at DESC, id DESC)` — same as Phase 13 home feed (R-62). Encoded as two Dart fields: `cursorPublishedAt: DateTime`, `cursorId: String`.
- **Price sorts** (`priceAsc` / `priceDesc`): cursor is `(primary_amount ASC/DESC, id ASC/DESC)`. Encoded as two Dart fields: `cursorPriceAmount: num`, `cursorId: String`.

`SearchState.cursor` is a Dart sealed class (discriminated union) with two subtypes: `NewestCursor(publishedAt, id)` and `PriceCursor(priceAmount, id)`. When sort order changes, the cursor is reset to `null` (first page).

**Rationale**: Price-sorted results require a stable secondary sort key (`id`) for tie-breaking when multiple listings share the same price. Using only price as cursor would skip listings on page boundaries. The discriminated union in Dart ensures the correct cursor fields are passed to the RPC for each sort mode. Reusing the Phase 13 cursor shape for `newest` avoids new infrastructure.

**Alternatives considered**:
- **Offset pagination**: Non-stable under concurrent inserts/approvals. Rejected per Phase 13 precedent (R-62).
- **Single universal cursor with all possible fields**: Nullable fields create ambiguity. Rejected in favor of the sealed class discriminated union.

---

## R-77 — Filter state persistence via BLoC lifetime at route scope

**Decision**: `SearchBloc` is provided at `SearchPage` level via `BlocProvider` and is kept alive by `go_router`'s default page cache. When the user navigates to `ListingDetailsPage` and presses Back, `go_router` restores the `SearchPage` widget from its page cache, which means the `BlocProvider` subtree (and the live `SearchBloc` instance) is still alive. The BLoC's state (filters, sort, results, cursor) is automatically restored from the live instance. No `PageStorageKey`, `RestorableValue`, or serialization is required.

**Rationale**: `go_router`'s `Page` cache keeps the widget subtree alive on the navigation stack as long as the route is not fully popped. This matches the spec FR-012 requirement ("Filter state MUST be preserved when the user navigates from the search page to a listing detail via the Back navigation path") with minimal implementation complexity. The go_router page cache is an existing project behavior (Phase 13 uses it for `ListingDetailsPage`).

**Alternatives considered**:
- **`PageStorageKey` + `PageStorage` bucket**: Requires serializable state; `FilterState` contains enums and nested objects. More complex than the live-BLoC approach. Rejected.
- **`RestorableValue` with state restoration API**: Android system state restoration is not required by the spec (which scopes to "current session only"). Overkill. Rejected.
- **Riverpod/Provider keepAlive**: Not a project dependency. Rejected.

---

## R-78 — `SearchFilterSheet` uses `DraggableScrollableSheet`

**Decision**: The filter bottom sheet is implemented as `DraggableScrollableSheet` (not `showModalBottomSheet`). It is displayed using `showModalBottomSheet(isScrollControlled: true, builder: (_) => DraggableScrollableSheet(...))`. Initial snap: 0.6 of screen height; max snap: 0.92. The sheet contains a `SingleChildScrollView` wrapping all filter dimensions.

**Rationale**: `DraggableScrollableSheet` allows the user to drag the sheet to see more filter options without a separate scroll gesture. It matches the spec "modal bottom sheet covering ~80% of the screen" description from Q3=A clarification, while giving the user control over how much of the screen to use. `showModalBottomSheet` without drag control would require the user to scroll inside a fixed-height sheet, which is awkward for nine filter dimensions.

**Alternatives considered**:
- **Full-screen modal page** (Navigator push): Loses the spatial context of the result list. Rejected — spec Q3=A explicitly chose bottom sheet.
- **Persistent bottom sheet** (`Scaffold.bottomSheet`): Cannot be modal (blocking back-button behavior). Rejected.
- **Fixed-height bottom sheet** (`showModalBottomSheet` default): Requires scrolling inside a rigid container; poor UX for 9 filter dimensions. Rejected in favor of `DraggableScrollableSheet`.

---

## R-79 — Rooms/bathrooms dual-mode: `SegmentedButton<CountFilterMode>` + stepper

**Decision**: Each of rooms and bathrooms has two UI components stacked vertically:
1. A `SegmentedButton<CountFilterMode>` with two segments: "تماماً / Exactly" and "على الأقل / At least" — sets the `CountFilterMode` for that dimension.
2. A numeric stepper (row of `–` button, count `Text`, `+` button) showing the current count (default: null / unset). When count is null, the dimension is inactive.

**Rationale**: `SegmentedButton` is Flutter's Material 3 native two-option toggle — minimal boilerplate, RTL-aware by default. The stepper (–/count/+) is the standard pattern for small integer selection in Arabic-first mobile UIs (avoids dropdown extra tap). The two components are vertically stacked to avoid horizontal crowding in RTL. This matches the spec Q2 custom answer: "either select 3 rooms or at least 3 rooms."

**Alternatives considered**:
- **Dropdown for count**: Requires extra tap to open. Rejected for small integer values (1–10).
- **Slider for count**: Poor precision for exact-N mode. Rejected.
- **Single radio group** (`Exactly 1 / Exactly 2 / ... / At least 3 / At least 4 / ...`): Too many options; hard to localize. Rejected.

---

## R-80 — Pre-filter from home chip via `GoRouterState.extra` (not URL query param)

**Decision**: When the user taps a property-type chip on the Home screen, `property_type_shortcut_row.dart` calls `context.go(AppRoutes.search, extra: type)` where `type` is a `PropertyType` enum value. `SearchPage`'s `GoRoute` builder reads `state.extra as PropertyType?`. If non-null, `SearchPage` initializes its `SearchBloc` with a `FilterState(propertyType: initialPropertyType)` and dispatches `SearchFiltersApplied` immediately on first render.

**Rationale**: Passing enum values via URL query parameters requires encoding/decoding and pollutes the URL. `GoRouterState.extra` is the go_router idiomatic channel for typed in-memory values that should not persist in the URL or browser history. Phase 13 already established this pattern (Q3=A forward-state convention). The extra value is used only at BLoC initialization; it is not stored or re-read after that.

**Alternatives considered**:
- **URL query parameter** (`/search?property_type=apartment`): Requires enum → string → enum round-trip; brittle if enum values change; visible in Android activity history. Rejected.
- **Shared Dart singleton/global state**: Fragile, not testable. Rejected.

---

## R-81 — `v_listings_public` view pre-joins price + main image + location names

**Decision**: `public.v_listings_public` is a `CREATE OR REPLACE VIEW` that selects from `public.listings` (status='approved', in-window) with three `LEFT JOIN LATERAL` sub-selects: primary price (from `listing_prices`), main image path (first row by position from `listing_media`), and governorate/city name columns (from the location tables). The `search_listings` RPC reads from this view rather than joining base tables directly.

**Rationale**: Centralizing the approved-listing projection in a view keeps the RPC SQL clean. The view enforces the `status='approved'` + publish-window guard at the view level, so the RPC query planner can use the view as a filtered relation. The same projection shape is needed by both full-text keyword queries and facet-only queries — the view avoids duplicating the join logic. The view is read-only (`SELECT` only); no `WITH CHECK OPTION` is needed.

**Alternatives considered**:
- **Inline joins in the RPC SQL body**: Readable for a simple query; becomes unwieldy when nine optional filter conditions + cursor predicates + sort branches are added. Rejected in favor of the view for cleanliness.
- **Materialized view**: Phase 14 data volumes don't justify materialization refresh overhead. Deferred.

---

## R-82 — `app_strings.dart` `_DebugAppLocalizations` extended with ~30 new Phase 14 getters

**Decision**: `lib/l10n/app_strings.dart` contains a hand-maintained `_DebugAppLocalizations` subclass used as a fallback during development. Phase 14 extends it with concrete getters for all ~30 new search/filter ARB keys, returning the Arabic value (same pattern as Phase 11/13). The `flutter gen-l10n` tool generates `AppLocalizations`; `app_strings.dart` is the only hand-maintained file.

**Rationale**: This is the project convention established in Phase 11 and reinforced in Phase 13 (R-82 forward-stated). No change to the pattern.

**Alternatives considered**: None — project convention is locked.

---

## R-83 — Location data for filter sheet loaded lazily on sheet open

**Decision**: When the user opens the filter sheet, `SearchFilterSheet` uses Phase 8's existing `LocationRepository` (injected via GetIt) to load governorates once on sheet open. Cities for the selected governorate are fetched when the user picks a governorate. Areas for the selected city are fetched when the user picks a city. Results are cached in the sheet's `_SearchFilterSheetState` local state (`List<Governorate>? _governorates`, `List<City>? _cities`, `List<Area>? _areas`). The location data is not pre-fetched on `SearchPage` mount to avoid unnecessary network calls when the user never opens the filter sheet.

**Rationale**: Governorate + city + area data is small and loads fast. Lazy loading on sheet open keeps `SearchPage` initialization lean and avoids loading location data for users who never open the filter sheet. The local state cache is sufficient for a single filter sheet session; when the sheet is dismissed and re-opened, a re-fetch is acceptable (data rarely changes).

**Alternatives considered**:
- **Pre-fetch on SearchPage mount**: Wastes resources when user doesn't open filter sheet. Rejected.
- **Global cache via BLoC/Cubit**: Adds a new BLoC for location data that already has its own repository. Over-engineered for Phase 14. Deferred.

---

## R-84 — Inline sort control uses `DropdownButton<SortOrder>` (not `SegmentedButton`)

**Decision**: `InlineSortControl` is a `DropdownButton<SortOrder>` showing the active sort option label. It sits in the row next to the Filters button, above the results list. Default value: `SortOrder.newest`.

**Rationale**: Three sort options in a `SegmentedButton` would require too much horizontal space, especially in RTL layout where the "Price: Low to High" label is even longer in Arabic ("السعر: من الأقل إلى الأعلى"). `DropdownButton` collapses to a single row showing the active option and expands on tap — standard compact sort control pattern in mobile list views.

**Alternatives considered**:
- **`SegmentedButton` with three segments**: Would overflow horizontally in RTL on typical phone widths. Rejected per horizontal-space analysis.
- **`PopupMenuButton` with sort icons**: Good for icon-only UIs; harder to localize labels for Arabic. Rejected for complexity.
- **Modal bottom sheet for sort**: Two taps instead of one. Rejected — spec explicitly called for a one-tap inline control (FR-008, US3 SC-1).
