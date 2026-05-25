# Implementation Plan: Map View

**Branch**: `015-map-view` | **Date**: 2026-05-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/015-map-view/spec.md`

## Summary

Phase 15 introduces the public geospatial discovery surface. The plan ships: (a) one new backend read surface — view `v_listings_map_public` plus a deterministic jitter SQL function — that enforces the visibility-tier gate at the data layer and guarantees the publisher's true coordinates never travel over the wire for `approximate` listings; (b) a new `lib/features/map/` Flutter feature implemented as a single full-screen `MapPage` composing `flutter_map` over OpenStreetMap raster tiles with marker clustering, a tile-attribution widget, a "center on my location" affordance gated by Android runtime geolocation permission, a marker preview popover that links into the existing Phase 13 `/listings/:id` route, and a filter-active alert dialog shown on entry from a filtered search; (c) entry-point wiring from THREE surfaces — a prominent map tile on the home page near the hero search bar, a "View on map" affordance on the existing Phase 13 `ListingDetailsPage`, and a "Show on map" affordance on the existing Phase 14 `SearchPage` results row; (d) the extraction of `DeepLinkAwareBackButton` to `lib/core/widgets/` (triggered by Phase 15 being the third consumer of the Phase 13 R-71 pattern, per the Phase 14 DEFERRED.md §D-001 extraction-trigger condition); (e) ARB-driven localization for ~25 new bilingual keys; (f) zero new contact / favorite / share / report wiring (Phase 16 owns those); (g) zero schema additions to `public.listings` (lat/lng/visibility columns already exist from Phase 10).

**Technical approach**: The map feature follows the same Clean Architecture pattern as Phase 14 (`presentation/bloc` → `domain/usecases` → `domain/repositories` → `data/repositories` → `data/datasources` → `core/network`). The visibility-tier gate (the constitutional Principle III boundary for this phase) is enforced inside the SQL view's `WHERE` predicate AND inside the jitter function's `SECURITY DEFINER` body — the Flutter `data/` layer queries the view directly and trusts what it returns. The jitter function uses a deterministic SHA-256 hash of `listing_id || salt` mapped to a fixed offset within a ~500m radius (R-87) so multi-fetch averaging by an attacker cannot triangulate the true centroid AND the marker stays stable across user re-visits (per Q4=A clarification). The map page is the second consumer of Phase 14's `FilterState` (Phase 15 G3 navigates from `SearchPage`'s `_SortAndFiltersRow` to `/map` carrying the active `FilterState` as `go_router` extra, mirroring Phase 14 R-80's `PropertyType` extra-passing pattern). The home tile is a single new `SliverToBoxAdapter`-hosted widget that slots between Phase 13's `PropertyTypeShortcutRow` and the "Latest listings" header. The "View on map" affordance on the listing details page is added as a CONSUMER concern wrapping the existing shared `ListingLocationBlock` widget (per Phase 12 Q8=A widget-purity contract — the shared widget itself is NOT modified). The geolocation affordance uses the Android-API-backed `geolocator` plugin and `permission_handler` for runtime permission (R-88) — neither depends on Google Play Services exclusively, so they work on Syrian Android devices distributed via the direct-APK channel.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase) / PL/pgSQL.

**Primary Dependencies** (added in Phase 15 Sub-Phase A):

- `flutter_map: ^7.0.0` (NEW — OpenStreetMap-compatible map renderer; pre-locked constitutional choice; no Google Maps / Mapbox / commercial-tile dependency)
- `latlong2: ^0.9.1` (NEW — peer dependency of `flutter_map` for coordinate value objects)
- `flutter_map_marker_cluster: ^1.4.0` (NEW — marker clustering on top of `flutter_map`, per FR-013)
- `geolocator: ^13.0.0` (NEW — Android-API-backed geolocation; no Google Play Services hard dependency, works on direct-APK distribution per R-88)
- `permission_handler: ^11.3.0` (NEW — Android runtime permission prompt for ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION, per FR-015b)

**Inherited dependencies** (already in `pubspec.yaml`, no version change): `flutter`, `flutter_localizations`, `supabase_flutter`, `flutter_bloc`, `go_router`, `get_it`, `injectable`, `intl`, `cached_network_image`, `flutter_secure_storage`, `equatable`, `url_launcher`.

**Storage**: Supabase Postgres `public.listings` table (existing — `latitude`, `longitude`, `location_visibility` columns ship in `20260519120002_create_listings.sql`), `public.areas` table (existing — `centroid_lat`, `centroid_lng` columns ship in `20260519120001_alter_areas_add_centroids.sql` with Syria bounds-check CHECK constraint), Supabase Storage `listing-images` bucket (existing — Phase 11). Phase 15 adds one new SQL function `public.map_jitter_coordinates(uuid, uuid, numeric, numeric)` and one new view `public.v_listings_map_public`. No new tables, no new columns on existing tables, no PostGIS extension (R-90 — Phase 15 v1 scale stays under PostGIS's pay-grade threshold; plain numeric arithmetic suffices for jitter and marker queries).

**Testing**: Per project convention (memory `feedback_no_new_tests.md`), no new automated tests are added in Phase 15. Existing tests remain. Manual UI verification on the reference Infinix Note 8 (per memory `user_test_device.md`) is the gate; quickstart.md captures the recipe.

**Target Platform**: Android only (Constitution Principle XI). Minimum SDK per existing Phase 1 baseline. Reference device: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11) for hands-on verification; Pixel 8 Pro emulator (Android 14, 412 dp width) for secondary checks per the standard project test matrix.

**Project Type**: Mobile app (Flutter) + Supabase backend — existing layout per `lib/features/<feature>/{presentation,domain,data}/` and `supabase/{migrations,functions,policies,seed}/`.

**Performance Goals**:

- OpenStreetMap basemap tiles render within 3 seconds of map page open on a standard Syrian 4G connection (SC-001).
- Marker pins paint within an additional 2 seconds after tiles (SC-001).
- Marker tap → preview popover appears within 500 ms (SC-004).
- Preview popover tap → `/listings/:id` page renders within an additional 1 second (SC-004).
- Filter-active alert appears within 500 ms of map render when entered from a filtered search (SC-013).
- "Center on my location" first tap triggers permission prompt; on grant, pan and zoom within 3 seconds (SC-014).
- Refresh button re-load completes and re-renders markers within 2 seconds (SC-012).

**Constraints**:

- The publisher's true `latitude` / `longitude` MUST NEVER appear in any wire-level response for a listing whose `location_visibility` is `approximate` (FR-003, SC-003) — enforced by the SQL view's jittered-coordinate projection.
- The map dataset MUST be filterable by the same parameter shape as Phase 14's `search_listings` RPC (purpose, type, governorate, city, area, price range with currency, rooms with exact/at-least mode, bathrooms with exact/at-least mode, area size, keyword) for the search→map handoff (FR-007a). Phase 15 introduces a sibling RPC `public.search_map(...)` rather than re-purposing `search_listings` because the return-shape composite differs (the map needs lat/lng/visibility; the search results don't).
- The `geolocator` plugin's Android implementation MUST NOT require Google Play Services as a hard dependency — Syrian direct-APK distribution channels often run on devices without current Play Services. Per `geolocator` 13.x release notes, the Android implementation uses the native `LocationManager` API and is Play-Services-free in default configuration; this is the deciding factor over `location` (which has a Play Services soft dep) per R-88.
- The map page MUST follow Constitution IX-clean: no `package:supabase_flutter` imports outside `lib/features/map/data/`. The `MapMarker` domain entity, `MapRepository` interface, and `LoadMapMarkers` use case all live in `domain/` and import zero Supabase types.
- The map page MUST follow Constitution V (Arabic-first localization) and VI (design tokens). All new strings flow through ARB; all new widgets read from `Theme.of(context)` / project token API.
- The Phase 12 Q8=A widget contract MUST be preserved: the shared `ListingLocationBlock` at `lib/shared/presentation/widgets/listing_display/listing_location_block.dart` MUST NOT be modified. The "View on map" affordance is added as a sibling widget wrapping the location block in the consumer (`ListingDetailsPage._SuccessBody`), NOT as a callback parameter on the shared widget.

**Scale/Scope**:

- 7 sub-phases (A through G) organized into 3 waves with parallel execution where dependency graph permits.
- 3 new Supabase migrations (1 SECURITY DEFINER PL/pgSQL jitter function, 1 view, 1 SQL RPC); 0 schema changes to existing tables.
- 1 new Flutter feature folder (`lib/features/map/`) with 16 new Dart files; 5 existing files updated (`app_router.dart`, `home_page.dart`, `listing_details_page.dart`, `search_page.dart`, and the Phase 14 `filter_state.dart` for the new `hasAnyActiveFilter` getter); 1 cross-cutting widget extraction to `lib/core/widgets/deep_link_aware_back_button.dart`.
- ~23 new bilingual ARB keys (Arabic + English) — final count locked in Sub-Phase F per tasks.md T027–T031.
- 12 plan-time research decisions (R-85 through R-96) resolved in `research.md`.
- 9 contract files in `contracts/` covering the jitter function, the public view, the search RPC, the MapPage composition, all three entry-point wiring patterns (home tile, listing-details "View on map", search "Show on map"), the back-button extraction, and the geolocation envelope.

---

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `specs/015-map-view/spec.md` exists with 6 user stories, 27 FRs (20 numbered FR-001..FR-020 plus 7 sub-numbered FR-001a, FR-003a, FR-007a, FR-014a, FR-015a, FR-015b, FR-015c), 15 SCs, 8 clarifications resolved (3 in `/speckit-specify`, 5 in `/speckit-clarify`). This plan + the data-model + contracts + quickstart land before any implementation. |
| II. Source-Controlled Backend | **Pass** | The two new backend artifacts (`map_jitter_coordinates` function migration + `v_listings_map_public` view migration) are checked in as files under `supabase/migrations/`. The Supabase MCP `apply_migration` is used to apply them, but the canonical source-of-truth is the migration files. Per-table docs under `supabase/docs/v_listings_map_public.md` + `supabase/docs/map_jitter_coordinates.md`. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | The `v_listings_map_public` view's `WHERE` predicate enforces both the approval gate (`status = 'approved'`) AND the visibility gate (`location_visibility IN ('exact', 'approximate')`) at the data layer; no application-layer post-filter is permitted (FR-005). For `approximate` listings, the view projects coordinates computed by the `SECURITY DEFINER` jitter function so the publisher's true coordinates never travel over the wire (FR-003). The view inherits RLS from `public.listings` (no RLS bypass); a grep gate in `quickstart.md` verifies no client code applies a `.eq('status', 'approved')` or `.neq('location_visibility', 'hidden')` filter. |
| IV. Clean Architecture Flutter | **Pass** | The new `lib/features/map/` feature follows the standard 3-layer structure: `presentation/{bloc,pages,widgets}/`, `domain/{entities,repositories,usecases}/`, `data/{datasources,models,repositories}/`. Business rules (visibility-tier gate, marker-cluster threshold, refresh trigger, geolocation envelope) live in `domain/` use cases. The `MapBloc` reads from `LoadMapMarkers` use case which calls `MapRepository`. State management is BLoC (`MapBloc` extends `Bloc<MapEvent, MapState>`) — no `StatefulWidget` deviations. |
| V. Arabic-First Localization | **Pass** | ~25 new strings (attribution wording, approximate-location label, center-on-my-location FAB, permission-denied message, refresh button, reset/keep filters labels, filter-active alert title + body, view-on-map / show-on-map affordance labels, empty/error states) land in both `app_ar.arb` AND `app_en.arb` in Sub-Phase F. No inline `Text('...')` string literals in any new feature code; grep gate in quickstart. The Arabic copy is Syrian-friendly (e.g., "موقع تقريبي" rather than stiffer MSA equivalents). |
| VI. Theme System & Design Tokens | **Pass** | All new map-feature widgets read colors / typography / spacing / radii / elevation from `Theme.of(context)` and the project's `AppSpacing` / `AppRadii` token APIs. The marker pin styling, cluster badge, preview popover container, filter-active alert dialog, refresh button, and "center on my location" FAB all consume Phase 2 tokens. OpenStreetMap tile imagery is exempt from this rule (tiles are network-sourced raster images, not styleable from the design-token surface). |
| VII. Dynamic Roles & Permissions | **Pass (N/A)** | The map page is anonymous-accessible (FR-006); there is no permission gate for reading the map dataset. No sensitive admin action originates from the map (no role mutation, no listing approval, no audit-emitting verb). The visibility-tier gate is a data-layer privacy boundary, NOT a permission-system boundary. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | The map dataset surfaces only `status = 'approved'` listings (FR-002), so the approval workflow is the gate for map presence — identical to Phase 13 / Phase 14. The publisher's identity is protected: the view projects no publisher private fields (no `legal_name`, no `national_id`, no `private_contact_methods` per ADR-0001), and the jittered coordinates for `approximate` listings protect publisher physical address. The "View on map" affordance on the listing details page is hidden for listings with `location_visibility` in (`hidden`, `admin_only`), so a publisher's choice to hide their location is honored end-to-end. |
| IX. Future Backend Portability | **Pass** | The `MapMarker` domain entity, `MapRepository` interface, `LoadMapMarkers` use case, and `MapEntryContext` sealed class all live in `lib/features/map/domain/` and import zero `package:supabase_flutter` / zero `package:postgrest` / zero Supabase types. Concrete Supabase access lives in `lib/features/map/data/datasources/supabase_map_datasource.dart` behind the `MapRepository` interface. A grep gate in quickstart verifies no Supabase imports under `lib/features/map/domain/` or `lib/features/map/presentation/`. |
| X. Testable AI Workflow | **Pass** | Every sub-phase task in Phase 2 (tasks.md) will carry explicit acceptance criteria derived from the FRs and SCs in `spec.md`. The quickstart.md captures end-to-end manual verification with one step per SC. Wire-level inspection commands for the jitter gate are spelled out. The `/wave` orchestrator uses the Touch-fan notes below to merge sub-phases in conflict-free order. |
| XI. Android-First MVP | **Pass** | All new dependencies (`flutter_map`, `latlong2`, `flutter_map_marker_cluster`, `geolocator`, `permission_handler`) ship Android support; none are iOS-only or Web-only. The `geolocator` selection over `location` (R-88) was driven by Syrian direct-APK distribution (no Google Play Services dependency). The Android-manifest permission entries (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) are added in `android/app/src/main/AndroidManifest.xml` only. No iOS `Info.plist` keys, no Flutter Web HTML, no desktop targets. |
| XII. No Hidden Product Decisions | **Pass** | All 8 product clarifications (3 from `/speckit-specify` + 5 from `/speckit-clarify`) are recorded in `spec.md`'s "Clarifications" section with rationale. The 12 plan-time research decisions (R-85..R-96) are recorded in `research.md`. Future-spec deferrals (PostGIS adoption, dark-mode tile source, bbox-bound dataset when catalog scales, in-app navigation directions, last-viewed-region persistence) are explicitly forward-stated in `spec.md` Assumptions + Clarifications. No silent product picks: the home-tile layout, the "Approximate location" indicator wording, the refresh affordance choice (button vs pull), the jitter radius, and the marker cluster threshold are all explicitly decided in `research.md`. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

---

## Project Structure

### Documentation (this feature)

```text
specs/015-map-view/
├── plan.md                     # This file (/speckit-plan output)
├── spec.md                     # /speckit-specify + /speckit-clarify output (committed)
├── research.md                 # Phase 0 output (R-85..R-96)
├── data-model.md               # Phase 1 output (SQL bodies + Dart entities + FR/SC verification map)
├── quickstart.md               # Phase 1 output (end-to-end manual recipe)
├── contracts/
│   ├── phase15-map-jitter-function.md      # SQL function signature, behavior, salt rotation
│   ├── phase15-v-listings-map-public-view.md  # View columns + WHERE + GRANT + idempotency
│   ├── phase15-search-map-rpc.md           # RPC parameter list + return shape + behavioral contracts
│   ├── phase15-map-page-composition.md     # MapPage widget tree, BLoC contract, popover behavior
│   ├── phase15-home-map-tile.md            # Home-page tile insertion + tap handler
│   ├── phase15-listing-details-view-on-map.md  # Listing details consumer wrap + visibility-tier predicate
│   ├── phase15-search-show-on-map.md       # SearchPage _SortAndFiltersRow addition + FilterState handoff
│   ├── phase15-deep-link-back-button-extraction.md  # Phase 14 R-71 forward-state realization
│   └── phase15-geolocation-envelope.md     # Permission flow + fix lifecycle + no-server-side-persistence rule
└── checklists/
    └── requirements.md         # /speckit-specify quality checklist (committed)
```

### Source Code (repository root)

```text
H:\alnujom-project\
├── lib/
│   ├── core/
│   │   ├── routing/
│   │   │   └── app_router.dart                       # UPDATE — add AppRoutes.map + AppRouteNames.map + GoRoute
│   │   └── widgets/
│   │       └── deep_link_aware_back_button.dart      # CREATE — extracted from Phase 13 inline pattern
│   ├── features/
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   └── home_page.dart                # UPDATE — insert MapEntryTile sliver
│   │   │       └── widgets/
│   │   │           └── map_entry_tile.dart           # CREATE — home-tile entry point
│   │   ├── listing_details/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── listing_details_page.dart     # UPDATE — wrap ListingLocationBlock with View-on-map button
│   │   ├── search/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── search_page.dart              # UPDATE — add Show-on-map to _SortAndFiltersRow
│   │   └── map/                                      # CREATE — new feature folder
│   │       ├── data/
│   │       │   ├── datasources/
│   │       │   │   └── supabase_map_datasource.dart  # CREATE — calls v_listings_map_public + search_map RPC
│   │       │   ├── models/
│   │       │   │   └── map_marker_dto.dart           # CREATE — row → DTO → entity mapping
│   │       │   └── repositories/
│   │       │       └── map_repository_impl.dart      # CREATE — implements MapRepository
│   │       ├── domain/
│   │       │   ├── entities/
│   │       │   │   ├── map_marker.dart               # CREATE — id, coords, title, price, image, type/purpose, isApproximate
│   │       │   │   └── map_entry_context.dart        # CREATE — sealed class: FromHome, FromListing(id, lat, lng), FromSearch(FilterState)
│   │       │   ├── repositories/
│   │       │   │   └── map_repository.dart           # CREATE — abstract Dart interface
│   │       │   └── usecases/
│   │       │       └── load_map_markers.dart         # CREATE — single use case
│   │       └── presentation/
│   │           ├── bloc/
│   │           │   ├── map_bloc.dart                 # CREATE — orchestrates dataset + camera + popover + permission
│   │           │   ├── map_event.dart                # CREATE
│   │           │   └── map_state.dart                # CREATE
│   │           ├── pages/
│   │           │   └── map_page.dart                 # CREATE — FlutterMap + tile layer + cluster layer + chrome
│   │           └── widgets/
│   │               ├── marker_preview_popover.dart   # CREATE
│   │               ├── center_on_my_location_fab.dart # CREATE
│   │               ├── filter_active_alert_dialog.dart # CREATE
│   │               ├── map_refresh_button.dart       # CREATE
│   │               └── osm_attribution_widget.dart   # CREATE
│   └── l10n/
│       ├── app_ar.arb                                # UPDATE — add ~25 Arabic keys
│       └── app_en.arb                                # UPDATE — add same ~25 English keys
├── android/app/src/main/
│   └── AndroidManifest.xml                           # UPDATE — add ACCESS_FINE_LOCATION + ACCESS_COARSE_LOCATION
├── pubspec.yaml                                      # UPDATE — add flutter_map, latlong2, flutter_map_marker_cluster, geolocator, permission_handler
└── supabase/
    ├── migrations/
    │   ├── 20260526120001_create_map_jitter_function.sql  # CREATE — SECURITY DEFINER PL/pgSQL helper
    │   ├── 20260526120002_create_v_listings_map_public.sql # CREATE — view with WHERE gates
    │   └── 20260526120003_create_search_map_rpc.sql       # CREATE — Phase 14-shaped filter RPC sibling
    └── docs/
        ├── map_jitter_coordinates.md                 # CREATE — function contract + salt rotation
        └── v_listings_map_public.md                  # CREATE — view docs + grep gate
```

**Structure Decision**: Phase 15 adds one new feature folder (`lib/features/map/`) following the established Clean Architecture pattern from Phases 5–14. Three existing feature pages receive entry-point additions (home, listing_details, search) — minimal patches per page. One cross-cutting widget (`DeepLinkAwareBackButton`) is extracted to `lib/core/widgets/` and Phase 13 + Phase 14 are refactored to consume it. Three new Supabase migrations land under `supabase/migrations/`. No new packages outside `lib/features/map/{data,domain,presentation}/` — same isolation pattern Phase 14 used for the search feature.

---

## Phase Dependencies

> **User-mandated discipline (per /speckit-plan invocation)**: Every "Sub-Phase B depends on Sub-Phase A" line below names the specific file path OR exported symbol that B consumes from A. Lines like "easier in sequence" or "uses concepts from" are FORBIDDEN. Self-audit count is at the end of this section.

### Sub-Phase A — Bootstrap: dependencies, route slot, sealed-class entry envelope

**Scope**:

1. Add `flutter_map: ^7.0.0`, `latlong2: ^0.9.1`, `flutter_map_marker_cluster: ^1.4.0`, `geolocator: ^13.0.0`, `permission_handler: ^11.3.0` to `pubspec.yaml`; run `flutter pub get`.
2. Add `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>` and `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>` to `android/app/src/main/AndroidManifest.xml`.
3. Add `AppRoutes.map = '/map'` and `AppRouteNames.map = 'map'` constants to `lib/core/routing/app_router.dart` and register a `GoRoute` whose `builder` returns the stub `MapPage` (filled in Sub-Phase E). The route's `state.extra` is typed as `MapEntryContext?` (null for cold-launch / deep-link entry; non-null when the caller passes a context envelope).
4. Create skeleton directories under `lib/features/map/` for `data/{datasources,models,repositories}/`, `domain/{entities,repositories,usecases}/`, `presentation/{bloc,pages,widgets}/`.
5. Create `lib/features/map/domain/entities/map_entry_context.dart` defining the sealed class hierarchy: `MapEntryContext` (abstract); `MapEntryFromHome` (no payload); `MapEntryFromListing` (listing id + lat + lng to center on); `MapEntryFromSearch` (the active `FilterState` from Phase 14 carried forward, plus `bool showFilterAlert` defaulting to `true`).
6. Create stub `lib/features/map/presentation/pages/map_page.dart` rendering an empty `Scaffold` with an `AppBar` and a placeholder body — wired to the route so the dependency graph is testable end-to-end before Sub-Phase E fills it.

**In-spec deps**: none.

**Cross-phase deps**:

- A imports `package:alnujom/features/search/domain/entities/filter_state.dart` (Phase 14 `FilterState` is the payload of `MapEntryFromSearch`). The Phase 14 file already exists; no churn.

**Touch fan**: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `lib/core/routing/app_router.dart`, `lib/features/map/domain/entities/map_entry_context.dart` (CREATE), `lib/features/map/presentation/pages/map_page.dart` (CREATE stub).

---

### Sub-Phase B — Extract `DeepLinkAwareBackButton` to `lib/core/widgets/`

**Scope**:

1. Create `lib/core/widgets/deep_link_aware_back_button.dart` exporting a `DeepLinkAwareBackButton` widget that wraps the Phase 13 R-71 pattern: an `IconButton` whose `onPressed` calls `Navigator.canPop(context) ? Navigator.pop(context) : context.go(AppRoutes.home)`. The widget accepts an optional `homeRoute` parameter (defaulting to `AppRoutes.home`) for testability.
2. Refactor `lib/features/listing_details/presentation/pages/listing_details_page.dart` to consume the extracted widget — replace the inline `_handleBack(context)` helper + `IconButton(...)` with `DeepLinkAwareBackButton()`. Preserve the `PopScope` wrapper (the back-button widget owns the `IconButton` only; the `PopScope` system-back gesture handler remains in the page).
3. Refactor `lib/features/search/presentation/pages/search_page.dart` to consume the extracted widget — replace the inline `Navigator.canPop(context) ? const BackButton() : IconButton(...)` ternary in the AppBar `leading` slot with `DeepLinkAwareBackButton()`.
4. Phase 15's `MapPage` (Sub-Phase E) will consume the same widget from the start — no inline pattern in the new code.

**In-spec deps**: none.

**Cross-phase deps**:

- B's refactor of `listing_details_page.dart` is the realization of Phase 13's R-71 forward-stated extraction-on-third-consumer condition. Per the Phase 14 DEFERRED.md §D-001 trigger ("Phase 15 IS the third consumer"), Phase 15 is the natural extraction point.
- B's refactor of `search_page.dart` removes the inline ternary Phase 14 introduced as a second consumer — no behavior change, just consolidation.

**Touch fan**: `lib/core/widgets/deep_link_aware_back_button.dart` (CREATE), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE), `lib/features/search/presentation/pages/search_page.dart` (UPDATE).

---

### Sub-Phase C — Backend: jitter function + map view + map-search RPC

**Scope**:

1. Create migration `supabase/migrations/20260526120001_create_map_jitter_function.sql` defining `public.map_jitter_coordinates(p_listing_id uuid, p_area_id uuid, p_original_lat numeric, p_original_lng numeric) RETURNS TABLE(jittered_lat numeric, jittered_lng numeric)` as `SECURITY DEFINER` PL/pgSQL. The body computes a deterministic offset using `digest(p_listing_id::text || current_setting('app.map_jitter_salt'), 'sha256')` (the salt is set via `ALTER DATABASE ... SET app.map_jitter_salt = '<random-256-bit-hex>'` in a one-time setup step recorded in `data-model.md`; rotation is documented). The offset is bounded by ~500m radius at Syrian latitudes (R-87: `±0.0045°` lat, `±0.0045°` lng, scaled by salt-derived bytes). If the computed jitter would push the marker outside the area's bounds, the function clamps to within the area's bounds; if `p_original_lat`/`p_original_lng` are null, the function falls back to the area's `centroid_lat`/`centroid_lng` and jitters from there.
2. Create migration `supabase/migrations/20260526120002_create_v_listings_map_public.sql` defining `public.v_listings_map_public` with this projection:
   - `id`, `title`, `primary_amount`, `primary_currency`, `main_image_path`, `property_type`, `purpose`, `governorate_name_ar`, `governorate_name_en` (reused from `v_listings_public` join shape)
   - `location_visibility` (passthrough)
   - `marker_lat`, `marker_lng` (computed: for `exact` visibility → original `l.latitude`/`l.longitude`; for `approximate` → result of `map_jitter_coordinates` call)
   - `is_approximate` boolean (true when `location_visibility = 'approximate'`)
   - `WHERE l.status = 'approved' AND l.location_visibility IN ('exact', 'approximate') AND (l.expires_at IS NULL OR l.expires_at > now())`
   - `GRANT SELECT ON public.v_listings_map_public TO authenticated, anon`.
3. Create migration `supabase/migrations/20260526120003_create_search_map_rpc.sql` defining `public.search_map(...)` — a 17-parameter `SECURITY DEFINER` function returning `SETOF v_listings_map_public` rows, accepting the same filter parameter shape as Phase 14's `search_listings` (purpose, type, governorate, city, area, price ranges in USD + SYP, rooms + mode, bathrooms + mode, area size, keyword — but NO sort, NO cursor, NO limit because the map dataset is one-shot per FR-001a). When all filter parameters are null, the RPC behaves identically to a `SELECT * FROM v_listings_map_public`. `GRANT EXECUTE ON FUNCTION public.search_map TO authenticated, anon`.
4. Create `supabase/docs/map_jitter_coordinates.md` and `supabase/docs/v_listings_map_public.md` documenting columns, RLS posture, salt rotation procedure, EXPLAIN expectations, and the contract that the publisher's true lat/lng never appears in any wire response for an `approximate` listing.

**In-spec deps**: none.

**Cross-phase deps**:

- C's `v_listings_map_public` view JOINs to `public.listings` (Phase 10), `public.listing_prices`, `public.listing_media`, `public.governorates`, `public.cities` — all existing.
- C's `map_jitter_coordinates` function reads `public.areas.centroid_lat` and `public.areas.centroid_lng` (Phase 10 R-12, columns shipped in `20260519120001_alter_areas_add_centroids.sql`).
- C's `search_map` RPC parameter shape mirrors Phase 14's `search_listings` (signature documented at `supabase/migrations/20260525120003_create_search_listings_rpc.sql`) — the param list is copied verbatim with sort/cursor/limit removed.

**Touch fan**: `supabase/migrations/20260526120001_create_map_jitter_function.sql` (CREATE), `supabase/migrations/20260526120002_create_v_listings_map_public.sql` (CREATE), `supabase/migrations/20260526120003_create_search_map_rpc.sql` (CREATE), `supabase/docs/map_jitter_coordinates.md` (CREATE), `supabase/docs/v_listings_map_public.md` (CREATE).

---

### Sub-Phase D — Domain + data layer for the map feature

**Scope**:

1. Define `MapMarker` domain entity at `lib/features/map/domain/entities/map_marker.dart` with `Equatable` fields: `id` (String, the listing UUID), `position` (LatLng — but typed as a domain-side `MarkerCoordinates` value object to keep `package:latlong2` out of `domain/`), `title` (String), `primaryAmount` (Decimal), `primaryCurrencyCode` (String), `mainImagePath` (String?), `propertyType` (PropertyType — re-exported from Phase 10), `purpose` (ListingPurpose), `isApproximate` (bool), `governorateNameAr` (String), `governorateNameEn` (String).
2. Define `MarkerCoordinates` value object at `lib/features/map/domain/entities/marker_coordinates.dart` — a domain-pure `(latitude, longitude)` pair. The `data/` layer maps it to/from `package:latlong2`'s `LatLng` at the data-source boundary.
3. Define `MapRepository` abstract interface at `lib/features/map/domain/repositories/map_repository.dart` with one method: `Future<Result<List<MapMarker>, Failure>> loadMarkers({FilterState? filter})`.
4. Define `LoadMapMarkers` use case at `lib/features/map/domain/usecases/load_map_markers.dart` — calls `MapRepository.loadMarkers(filter: ...)`; returns the result unchanged. (Single-method use case is consistent with Phase 14's `SearchListings` use case shape.)
5. Define `MapMarkerDto` at `lib/features/map/data/models/map_marker_dto.dart` — mirrors the `v_listings_map_public` row shape; `fromJson` factory + `toEntity()` method maps DTO → `MapMarker` (constructs `MarkerCoordinates` from `marker_lat` + `marker_lng`).
6. Implement `SupabaseMapDatasource` at `lib/features/map/data/datasources/supabase_map_datasource.dart` — when `filter` is null, queries `public.v_listings_map_public` directly; when `filter` is non-null, calls `public.search_map(...)` RPC with mapped parameters. Returns `List<MapMarkerDto>`.
7. Implement `MapRepositoryImpl` at `lib/features/map/data/repositories/map_repository_impl.dart` — calls the datasource, maps DTOs to entities, wraps errors in `Failure` per project convention.
8. Register all six new classes with `@injectable` annotations; regenerate `lib/core/di/injection.config.dart` via `build_runner`.

**In-spec deps**:

- D depends on Sub-Phase C — `SupabaseMapDatasource.loadAll()` issues a `select()` against `public.v_listings_map_public` (column names `id`, `title`, `marker_lat`, `marker_lng`, `is_approximate`, `primary_amount`, `primary_currency`, `main_image_path`, `property_type`, `purpose`, `governorate_name_ar`, `governorate_name_en`, `location_visibility` defined in `supabase/migrations/20260526120002_create_v_listings_map_public.sql`).
- D depends on Sub-Phase C — `SupabaseMapDatasource.loadFiltered(filter)` invokes the `public.search_map(...)` RPC defined in `supabase/migrations/20260526120003_create_search_map_rpc.sql` and consumes the same column projection.

**Cross-phase deps**:

- D imports `package:alnujom/features/search/domain/entities/filter_state.dart` (Phase 14) as the parameter type on `MapRepository.loadMarkers`. The Phase 14 `FilterState` already includes all fields (`purpose`, `propertyType`, `governorateId`, `cityId`, `areaId`, `priceRange`, `roomsFilter`, `bathroomsFilter`, `areaSizeRange`, `keyword`) needed.
- D imports `package:alnujom/features/listing_form/domain/entities/listing.dart` for the `PropertyType` and `ListingPurpose` enums (Phase 10, same import Phase 14 already uses).
- D imports `package:alnujom/core/errors/{failure,result}.dart` (Phase 1) for the `Result<T, Failure>` return type.
- D imports `package:decimal/decimal.dart` for `primaryAmount` typing — consistent with Phase 9's `MoneyFormatter` input shape.

**Touch fan**: `lib/features/map/domain/entities/map_marker.dart` (CREATE), `lib/features/map/domain/entities/marker_coordinates.dart` (CREATE), `lib/features/map/domain/repositories/map_repository.dart` (CREATE), `lib/features/map/domain/usecases/load_map_markers.dart` (CREATE), `lib/features/map/data/models/map_marker_dto.dart` (CREATE), `lib/features/map/data/datasources/supabase_map_datasource.dart` (CREATE), `lib/features/map/data/repositories/map_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase E — Presentation: MapPage + MapBloc + popover + FAB + filter alert + refresh

**Scope**:

1. Define `MapEvent` (sealed class) at `lib/features/map/presentation/bloc/map_event.dart` with cases: `MapOpened(MapEntryContext? context)`, `MarkersRefreshRequested`, `MarkerTapped(String listingId)`, `PopoverDismissed`, `CenterOnMyLocationRequested`, `GeolocationPermissionGranted(MarkerCoordinates devicePosition)`, `GeolocationPermissionDenied(bool permanentlyDenied)`, `GeolocationFixFailed`, `FilterAlertDismissed`, `FilterResetRequested`.
2. Define `MapState` at `lib/features/map/presentation/bloc/map_state.dart` (sealed class) with cases: `MapInitial`, `MapLoading`, `MapLoaded(markers, cameraPosition, selectedMarker?, isFilterActive, showFilterAlert, geolocationStatus)`, `MapError(failure)`.
3. Implement `MapBloc` at `lib/features/map/presentation/bloc/map_bloc.dart` extending `Bloc<MapEvent, MapState>`. Behavior:
   - On `MapOpened(context)`: emit `MapLoading`; call `LoadMapMarkers(filter: context is MapEntryFromSearch ? context.filterState : null)`; on success emit `MapLoaded` with camera position derived from context (Syria-wide for `FromHome` / `FromSearch`; centered on `(context.lat, context.lng)` at neighborhood zoom for `FromListing`; bounding-box-fit-to-results for `FromSearch` when results are non-empty); set `isFilterActive` and `showFilterAlert` based on context.
   - On `MarkersRefreshRequested`: re-run the same load using the cached filter state.
   - On `MarkerTapped`: update `MapLoaded.selectedMarker`.
   - On `CenterOnMyLocationRequested`: trigger the geolocation envelope (see contract `phase15-geolocation-envelope.md`).
4. Implement `MapPage` at `lib/features/map/presentation/pages/map_page.dart` — `BlocProvider<MapBloc>` wraps a `Scaffold` whose body is a `FlutterMap` widget with: an OpenStreetMap raster tile layer (URL template `https://tile.openstreetmap.org/{z}/{x}/{y}.png`); a `MarkerClusterLayerWidget` from `flutter_map_marker_cluster` rendering markers from `MapLoaded.markers`; the `OsmAttributionWidget`; a `Stack`-overlaid `CenterOnMyLocationFab` (bottom-end positioned); a conditional `MapRefreshButton` (top-end positioned); a conditional `MarkerPreviewPopover` anchored to `selectedMarker`. The `AppBar` `leading` slot uses `DeepLinkAwareBackButton` (from Sub-Phase B). On first `MapLoaded` emission where `showFilterAlert` is true, show `FilterActiveAlertDialog` non-blocking.
5. Implement `MarkerPreviewPopover` at `lib/features/map/presentation/widgets/marker_preview_popover.dart` — Material `Card` with `CachedNetworkImage` (Phase 11 image URL pattern via `getPublicUrl(main_image_path)`); `Text` for title; `MoneyFormatter` (Phase 9) for price; `Chip`-style badges for property type + purpose; conditional `Text` for "Approximate location" localized label when `marker.isApproximate`. Tap navigates to `AppRoutes.listingDetails` via `context.go('${listingDetailsPath}/$id'.replaceFirst(':id', id))` — or use the `AppRoutes.listingDetailsFor(id)` helper Phase 13 introduced.
6. Implement `CenterOnMyLocationFab` at `lib/features/map/presentation/widgets/center_on_my_location_fab.dart` — `FloatingActionButton` whose `onPressed` calls `permission_handler.Permission.locationWhenInUse.request()` on first tap; on grant, `geolocator.Geolocator.getCurrentPosition()` and dispatch `GeolocationPermissionGranted`; on denial, dispatch `GeolocationPermissionDenied` and show localized snackbar. Subsequent taps after grant skip the prompt and re-call `getCurrentPosition`.
7. Implement `FilterActiveAlertDialog` at `lib/features/map/presentation/widgets/filter_active_alert_dialog.dart` — Material `AlertDialog` with title (`l10n.map_filter_alert_title`), body summarizing active filters (`Wrap` of `Chip`-style filter labels derived from the `FilterState`), and two `TextButton` actions: "Reset filters" (dispatches `FilterResetRequested`) and "Keep filters" (dispatches `FilterAlertDismissed`).
8. Implement `MapRefreshButton` at `lib/features/map/presentation/widgets/map_refresh_button.dart` — `IconButton` with `Icons.refresh` that dispatches `MarkersRefreshRequested`. Chosen over pull-to-refresh per R-89 (map-pan gesture conflict).
9. Implement `OsmAttributionWidget` at `lib/features/map/presentation/widgets/osm_attribution_widget.dart` — small `Container` overlay (bottom-start positioned) with `Text` reading `l10n.map_osm_attribution` ("© OpenStreetMap contributors" / "© مساهمو OpenStreetMap").
10. Register `MapBloc` with `@injectable`; regenerate DI config.

**In-spec deps**:

- E depends on Sub-Phase A — `MapPage` is registered at `AppRoutes.map` (defined in `lib/core/routing/app_router.dart` by A); `MapBloc.add(MapOpened(context))` consumes `MapEntryContext` types defined at `lib/features/map/domain/entities/map_entry_context.dart` by A.
- E depends on Sub-Phase B — `MapPage`'s `AppBar.leading` uses `DeepLinkAwareBackButton` exported from `lib/core/widgets/deep_link_aware_back_button.dart` by B.
- E depends on Sub-Phase D — `MapBloc` constructor takes a `LoadMapMarkers` use case (`lib/features/map/domain/usecases/load_map_markers.dart`); `MapLoaded.markers` is a `List<MapMarker>` (`lib/features/map/domain/entities/map_marker.dart`); the marker `Marker` widget reads `marker.position.latitude` and `marker.position.longitude` from `MarkerCoordinates` (`lib/features/map/domain/entities/marker_coordinates.dart`).
- E depends on Sub-Phase F — `MarkerPreviewPopover`, `FilterActiveAlertDialog`, `CenterOnMyLocationFab`, `MapRefreshButton`, `OsmAttributionWidget`, and the `MapPage` AppBar all read getters from `lib/l10n/app_localizations.dart` (regenerated by F when ARB keys land).

**Cross-phase deps**:

- E imports `package:flutter_map/flutter_map.dart` and `package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart` and `package:latlong2/latlong.dart` (added by Sub-Phase A's `pubspec.yaml` update).
- E imports `package:geolocator/geolocator.dart` and `package:permission_handler/permission_handler.dart` (added by Sub-Phase A's `pubspec.yaml` update).
- E imports `package:cached_network_image/cached_network_image.dart` (existing Phase 1 dep, actively consumed since Phase 13).
- E imports `lib/shared/domain/value_objects/money.dart` and the `MoneyFormatter` utility (Phase 9) for price formatting in the popover.
- E imports Phase 9's `CurrencyRepository` (via `getIt`) to resolve the user's display currency.

**Touch fan**: `lib/features/map/presentation/bloc/map_bloc.dart` (CREATE), `lib/features/map/presentation/bloc/map_event.dart` (CREATE), `lib/features/map/presentation/bloc/map_state.dart` (CREATE), `lib/features/map/presentation/pages/map_page.dart` (UPDATE — replaces Sub-Phase A's stub), `lib/features/map/presentation/widgets/marker_preview_popover.dart` (CREATE), `lib/features/map/presentation/widgets/center_on_my_location_fab.dart` (CREATE), `lib/features/map/presentation/widgets/filter_active_alert_dialog.dart` (CREATE), `lib/features/map/presentation/widgets/map_refresh_button.dart` (CREATE), `lib/features/map/presentation/widgets/osm_attribution_widget.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase F — Localization: add ~25 bilingual ARB keys

**Scope**:

Add the following keys to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb`:

- Map page chrome: `map_page_title`, `map_osm_attribution`, `map_empty_state_no_listings`, `map_error_load_failed`, `map_error_retry_action`, `map_tiles_unavailable`.
- Marker preview popover: `map_marker_view_details_action`, `map_marker_approximate_location_label`, `map_marker_image_unavailable`.
- Center on my location FAB: `map_fab_center_on_me_tooltip`, `map_geolocation_permission_denied_message`, `map_geolocation_permission_permanently_denied_message`, `map_geolocation_fix_unavailable_message`.
- Filter-active alert dialog: `map_filter_alert_title`, `map_filter_alert_body_prefix`, `map_filter_alert_action_reset`, `map_filter_alert_action_keep`.
- Refresh button: `map_refresh_button_tooltip`.
- Home tile entry: `home_map_tile_title`, `home_map_tile_subtitle`.
- Listing details entry: `listing_details_view_on_map_action`.
- Search results entry: `search_results_show_on_map_action`.

Total: ~22 keys (final count locked when copy is finalized). After ARB updates, run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations.dart` and the per-locale getter classes.

**In-spec deps**: none.

**Cross-phase deps**:

- F runs `flutter gen-l10n` which regenerates `lib/l10n/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`. The generated file is consumed by Sub-Phase E and G widgets.

**Touch fan**: `lib/l10n/app_ar.arb` (UPDATE), `lib/l10n/app_en.arb` (UPDATE), `lib/l10n/app_localizations.dart` (REGENERATED), `lib/l10n/app_localizations_ar.dart` (REGENERATED), `lib/l10n/app_localizations_en.dart` (REGENERATED).

---

### Sub-Phase G — Entry-point wiring (home / listing details / search)

**Scope**:

1. **G1 — Home tile**: Create `lib/features/home/presentation/widgets/map_entry_tile.dart` — a `Card`-styled tappable widget showing a map icon + title (`l10n.home_map_tile_title`, e.g., "تصفح على الخريطة") + subtitle (`l10n.home_map_tile_subtitle`, e.g., "اعرض العقارات على الخريطة"). `onTap` calls `context.go(AppRoutes.map, extra: const MapEntryFromHome())`. Update `lib/features/home/presentation/pages/home_page.dart` to insert `const SliverToBoxAdapter(child: MapEntryTile())` between the existing `PropertyTypeShortcutRow` sliver and the "Latest listings" header sliver (per R-91 — the slot decision).
2. **G2 — Listing details "View on map"**: Update `lib/features/listing_details/presentation/pages/listing_details_page.dart` (`_SuccessBody`) — wrap the existing `ListingLocationBlock` widget in a `Column` that adds, BELOW the location block, a `TextButton.icon` with `Icons.map` and label `l10n.listing_details_view_on_map_action`. The button is rendered ONLY when `aggregate.listing.locationVisibility` is in `('exact', 'approximate')`; otherwise the button is omitted from the tree entirely (FR-007 condition; preserves the shared widget per Phase 12 Q8=A purity contract — no callback parameter is added to `ListingLocationBlock`). `onPressed` calls `context.go(AppRoutes.map, extra: MapEntryFromListing(listingId: aggregate.listing.id, lat: aggregate.listing.latitude!, lng: aggregate.listing.longitude!))` (the null-bang assertions are safe because the visibility check above guarantees lat/lng are non-null per Phase 10 Q2 area-centroid auto-fill).
3. **G3 — Search "Show on map"**: Update `lib/features/search/presentation/pages/search_page.dart` (`_SortAndFiltersRow` at lines 176–233) — add a third element to the row: a `TextButton.icon` with `Icons.map` and label `l10n.search_results_show_on_map_action`, positioned between the existing sort dropdown (start side) and Filters button (end side) using `MainAxisAlignment.spaceBetween` with three children OR by placing the new button immediately before the Filters button. `onPressed` reads the current `FilterState` from `context.read<SearchBloc>().state.filters` and calls `context.go(AppRoutes.map, extra: MapEntryFromSearch(filterState: filters, showFilterAlert: filters.hasAnyActiveFilter))` (the `hasAnyActiveFilter` getter is added in this sub-phase to `FilterState` if not already present; Phase 14's `FilterState` already exposes per-dimension non-null checks so a one-line getter suffices).

**In-spec deps**:

- G1 + G2 + G3 all depend on Sub-Phase A — `AppRoutes.map` constant (defined in `lib/core/routing/app_router.dart`) is the navigation target; `MapEntryFromHome`, `MapEntryFromListing`, `MapEntryFromSearch` are the sealed-class cases defined in `lib/features/map/domain/entities/map_entry_context.dart` by A.
- G1 + G2 + G3 depend on Sub-Phase F — `l10n.home_map_tile_title`, `l10n.home_map_tile_subtitle`, `l10n.listing_details_view_on_map_action`, `l10n.search_results_show_on_map_action` are getters generated from `app_ar.arb` / `app_en.arb` by F.

**Cross-phase deps**:

- G2 imports `package:alnujom/features/listing_details/domain/entities/listing_details_aggregate.dart` (Phase 13) to read `aggregate.listing.latitude`, `aggregate.listing.longitude`, `aggregate.listing.locationVisibility`. The aggregate's `Listing` entity already exposes these per Phase 10.
- G3 imports `package:alnujom/features/search/presentation/bloc/search_bloc.dart` (Phase 14) to read the current filter state — same pattern Phase 14's `InlineSortControl` and `SearchFilterSheet` use.
- G3 imports `package:alnujom/features/search/domain/entities/filter_state.dart` (Phase 14) for the `FilterState` type carried as `go_router` extra.

**Touch fan**: `lib/features/home/presentation/widgets/map_entry_tile.dart` (CREATE), `lib/features/home/presentation/pages/home_page.dart` (UPDATE), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE), `lib/features/search/presentation/pages/search_page.dart` (UPDATE), `lib/features/search/domain/entities/filter_state.dart` (UPDATE — add `hasAnyActiveFilter` getter if not already present).

---

### Self-audit — undeclared consumer check

Total declared "Sub-Phase B depends on Sub-Phase A" lines in the section above: **8** (A→none; B→none; C→none; D→C(1); E→A(2 symbols), B(1), D(3), F(1); F→none; G→A(2), F(1)). Every line names the specific symbol or file path consumed. **Zero deps lack a named consumer.** No "easier in sequence" or "uses concepts from" wording. Cross-phase deps (to predecessor Phase 1–14 artifacts) are listed separately under each sub-phase's "Cross-phase deps" subsection and similarly name the consumed file or symbol.

### Wave summary

| Wave | Sub-Phases | Parallelism |
|------|------------|-------------|
| 1 | A, B, C, F | 4 sub-phases run in parallel (no inter-deps). File-touch split: A touches `lib/core/routing/app_router.dart` + new `lib/features/map/` skeleton + `pubspec.yaml` + `AndroidManifest.xml`; B touches `lib/features/{listing_details,search}/presentation/pages/*.dart` (AppBar `leading` slots only); C touches `supabase/migrations/` + `supabase/docs/`; F touches `lib/l10n/app_{ar,en}.arb`. No two Wave 1 sub-phases share any file → zero merge conflict within the wave. G (Wave 2) re-touches the listing-details + search page files but in different regions of those files (AppBar regions are B's; `_SuccessBody` and `_SortAndFiltersRow` regions are G's) — the `/wave` orchestrator rebases G on top of B's Wave 1 edits before applying G's diff. |
| 2 | D, G | 2 sub-phases in parallel. D depends only on C (Wave 1); G depends only on A + F (Wave 1). G's `listing_details_page.dart` + `search_page.dart` updates rebase on top of B's Wave 1 refactor (which extracted the back-button widget) — the textual conflict is in different regions of the same files (B touches the AppBar `leading` slot; G touches the `_SuccessBody` body / `_SortAndFiltersRow` body) so the rebase is mechanical. |
| 3 | E | Runs alone. Depends on A (Wave 1), B (Wave 1), D (Wave 2), F (Wave 1). E's only file conflicts are with A's `lib/features/map/presentation/pages/map_page.dart` (A creates the stub; E replaces the stub body — full rewrite, no surrounding-context conflict) and with D's `lib/core/di/injection.config.dart` (regenerated by both — `build_runner` regenerates from scratch, no manual merge). |

Total wall-clock parallelism: ~4× in Wave 1, ~2× in Wave 2, 1× in Wave 3 — versus a naive sequential 7-step chain. The leaner dependency graph saves ~50% of sequential wall-clock time on a parallel-capable executor.

---

## Research Decisions (R-85..R-96)

See [research.md](research.md) for full per-decision rationale + rejected alternatives.

| ID | Decision area | Locked answer |
|----|--------------|--------------|
| R-85 | Map provider package | `flutter_map: ^7.0.0` over OpenStreetMap raster tiles (constitutional pre-lock) |
| R-86 | Marker clustering package | `flutter_map_marker_cluster: ^1.4.0` |
| R-87 | Jitter algorithm | Deterministic SHA-256 hash of `listing_id \|\| salt`; offset bounded to ±0.0045° (~500m at Syrian latitudes); clamped to area bounds; falls back to area centroid when stored lat/lng is null |
| R-88 | Geolocation plugin | `geolocator: ^13.0.0` (no Google Play Services hard dep, works on direct-APK) + `permission_handler: ^11.3.0` for runtime prompt |
| R-89 | Refresh affordance | Explicit `MapRefreshButton` (Material `IconButton`), NOT pull-to-refresh (map-pan gesture conflict) |
| R-90 | PostGIS adoption | Deferred — Phase 15 stays on plain `NUMERIC(9,6)` columns; PostGIS adoption is a future-spec decision when catalog scales |
| R-91 | Home tile slot | Between Phase 13's `PropertyTypeShortcutRow` sliver and the "Latest listings" header sliver |
| R-92 | Salt storage | `current_setting('app.map_jitter_salt')` set via `ALTER DATABASE ... SET app.map_jitter_salt = '<hex>'` one-time setup; rotation is a documented manual procedure in `data-model.md` |
| R-93 | Cluster threshold | `maxClusterRadius: 80` pixels (`flutter_map_marker_cluster` default); `spiderfyClusterMaxZoom` set to the map's max zoom (so spiderfy only at max zoom per FR-013 / Q3 of clarify pass) |
| R-94 | OSM tile URL | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (public OSM Foundation tile servers; usage policy compliant at v1 scale) |
| R-95 | MapEntryContext location | `lib/features/map/domain/entities/map_entry_context.dart` (Sub-Phase A) — sealed class with three cases; consumed by E (`MapBloc`) and G (entry-point widgets) |
| R-96 | DeepLinkAwareBackButton extraction trigger | Phase 15 IS the third consumer of the Phase 13 R-71 pattern → extraction lands in Sub-Phase B per Phase 14 DEFERRED.md §D-001 trigger |

## Complexity Tracking

*Empty. All 12 Constitution principles pass. No violations require justification.*
