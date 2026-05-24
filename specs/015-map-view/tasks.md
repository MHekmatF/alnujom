---
description: "Phase 15 — Map View task list"
---

# Tasks: Map View

**Input**: Design documents from `specs/015-map-view/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: No new automated tests per project memory `feedback_no_new_tests.md`. Manual UI verification on Infinix Note 8 is the gate (per memory `user_test_device.md`). Quickstart.md captures the recipe.
**Organization**: Tasks are grouped by Sub-Phase (matching plan.md §Phase Dependencies). Story labels [US1]..[US6] tag tasks by the primary user story they enable; many tasks serve multiple stories where the MapPage surface is shared.

**Acceptance-criteria convention** (Constitution Principle X compliance, matches Phase 14 precedent): each implementation task's acceptance criteria is defined by the **linked contract file** or **data-model section** it references in its description. A task that says "Create X per contracts/phase15-Y.md §Z" is accepted when (a) the file exists at the specified path, (b) its content matches the contract's stated structure (signature, fields, behavior), and (c) `flutter analyze` returns zero new errors / `flutter build apk --debug` succeeds where applicable. The **Phase Checkpoint** line at the end of each sub-phase summarizes the cumulative acceptance gate for the whole phase — passing the checkpoint demonstrates that every task in the phase met its per-task criteria. Tasks that have explicit per-task acceptance criteria spell them out in an `**Acceptance**:` clause. Manual smoke tests (clearly labeled in each phase) carry their own pass/fail criteria inline.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Maps the task to one or more user stories from spec.md
- All file paths are repo-relative

---

## Phase 1: Sub-Phase A — Bootstrap (dependencies, route slot, sealed-class entry envelope)

**Purpose**: Add map-related dependencies, register the `/map` route, define the `MapEntryContext` sealed class, and scaffold the `lib/features/map/` skeleton.

**Goal**: Every later sub-phase imports something defined here. After Phase 1, `flutter pub get` succeeds, the app builds, and tapping the (yet-empty) map route opens a stub `MapPage`.

- [X] T001 Add `flutter_map: ^7.0.0`, `latlong2: ^0.9.1`, `flutter_map_marker_cluster: ^1.4.0`, `geolocator: ^13.0.0`, `permission_handler: ^11.3.0` to `pubspec.yaml` under `dependencies:`. Run `flutter pub get`. Verify zero version-resolution conflicts in `pubspec.lock`.
- [X] T002 Add `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />` and `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />` to `android/app/src/main/AndroidManifest.xml` (inside the `<manifest>` element, alongside the existing `INTERNET` permission).
- [X] T003 [P] Add `static const map = '/map';` to the `AppRoutes` class in `lib/core/routing/app_router.dart` (immediately after `static const search = '/search';` per the existing alphabetical/phase-grouped order). Add `static const map = 'map';` to the `AppRouteNames` class in the same file.
- [X] T004 [P] Create the `lib/features/map/` skeleton directories: `data/datasources/`, `data/models/`, `data/repositories/`, `domain/entities/`, `domain/repositories/`, `domain/usecases/`, `presentation/bloc/`, `presentation/pages/`, `presentation/widgets/`. (Use `New-Item -ItemType Directory -Force` for each.) Add a `.gitkeep` or single placeholder file in each so they commit.
- [X] T005 Create `lib/features/map/domain/entities/marker_coordinates.dart` defining the `MarkerCoordinates` value object per data-model.md §4.1 (Equatable, `latitude` + `longitude` doubles, domain-pure — no `latlong2` import).
- [X] T006 Create `lib/features/map/domain/entities/map_entry_context.dart` defining the `MapEntryContext` sealed class with cases `MapEntryFromHome` (empty), `MapEntryFromListing({listingId, position})`, `MapEntryFromSearch({filterState, showFilterAlert})` per data-model.md §4.3. Imports: `package:equatable/equatable.dart`, `package:alnujom/features/search/domain/entities/filter_state.dart`, `marker_coordinates.dart`.
- [X] T007 Create stub `lib/features/map/presentation/pages/map_page.dart` rendering an empty `Scaffold` with an `AppBar` (title from a yet-to-add ARB key — for the stub, use `Text('Map')` as a placeholder Sub-Phase F will replace) and an empty body. Stub class signature: `class MapPage extends StatelessWidget { const MapPage({super.key, this.entryContext}); final MapEntryContext? entryContext; ... }`.
- [X] T008 In `lib/core/routing/app_router.dart`, register a `GoRoute` for the new map route. Insert it after the existing `/search` route block (line ~388). Body: `GoRoute(path: AppRoutes.map, name: AppRouteNames.map, builder: (context, state) => MapPage(entryContext: state.extra as MapEntryContext?))`. Add the corresponding `import 'package:alnujom/features/map/presentation/pages/map_page.dart';` + `import 'package:alnujom/features/map/domain/entities/map_entry_context.dart';` at the top of the file.
- [X] T009 Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart` (picks up no new `@injectable` annotations yet — Sub-Phases D and E will). Run `flutter build apk --debug --dart-define-from-file=.env.json` to confirm the app builds end-to-end. Flip checkboxes T001–T009 to `[X]` in the same commit.

**Checkpoint**: `flutter run` launches the app; navigating to `/map` (e.g., via a temporary `context.go('/map')` from any debug surface) shows the stub MapPage. The build is green.

---

## Phase 2: Sub-Phase B — Extract `DeepLinkAwareBackButton` to `lib/core/widgets/`

**Purpose**: Realize the Phase 13 R-71 forward-stated extraction (Phase 15 is the third consumer per Phase 14 DEFERRED.md §D-001).

**Goal**: One shared widget replaces the inline `Navigator.canPop()` pattern in Phase 13's `ListingDetailsPage`, Phase 14's `SearchPage`, and Phase 15's `MapPage`.

- [X] T010 Create `lib/core/widgets/deep_link_aware_back_button.dart` per contracts/phase15-deep-link-back-button-extraction.md §Widget definition. The widget is an `IconButton` with `Icons.arrow_back`; `onPressed` reads `Navigator.canPop(context)` and either calls `Navigator.pop(context)` or `context.go(fallbackRoute)` (default `AppRoutes.home`). Imports: `flutter/material.dart`, `go_router/go_router.dart`, `../routing/app_router.dart`.
- [X] T011 Refactor `lib/features/listing_details/presentation/pages/listing_details_page.dart`: replace the `IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _handleBack(context))` in the AppBar `leading` slot with `const DeepLinkAwareBackButton()`. Preserve the `PopScope` wrapper but inline the same conditional pop/go logic inside its `onPopInvokedWithResult` callback (system-back gesture path). Add `import '../../../../core/widgets/deep_link_aware_back_button.dart';` at the top. The standalone `_handleBack` helper method MAY be removed if no other call sites remain.
- [X] T012 Refactor `lib/features/search/presentation/pages/search_page.dart`: replace the ternary `Navigator.canPop(context) ? const BackButton() : IconButton(icon: const Icon(Icons.home), onPressed: () => context.go(AppRoutes.home))` in the AppBar `leading` slot with `const DeepLinkAwareBackButton()`. Add `import '../../../../core/widgets/deep_link_aware_back_button.dart';` at the top.
- [ ] **PARTIAL** T013 Manual smoke test on Infinix Note 8 (per memory `user_test_device.md`): open ListingDetailsPage via deep-link (cold-launch with `/listings/:id` as initial route) -> press back -> confirm lands on home page. Open ListingDetailsPage via card tap from home -> press back -> confirm lands on home page. Open SearchPage via hero search bar -> press back -> confirm lands on home page. Open SearchPage via deep-link (cold-launch with `/search`) -> press back -> confirm lands on home page. Flip T010-T013 in the same commit. **Device unavailable in worktree at commit time; `flutter analyze` clean; behavior identical to pre-refactor pattern by inspection -- see `specs/015-map-view/DEFERRED.md section D-T013`.**

**Checkpoint**: Two existing call sites consume the extracted widget; behavior is identical (no regression). Phase 5's `MapPage` will adopt the same widget from the start.

---

## Phase 3: Sub-Phase C — Backend (jitter function, map view, search_map RPC)

**Purpose**: Land the three Supabase migrations that constitute Phase 15's data layer.

**Goal**: After Phase 3, `SELECT * FROM public.v_listings_map_public` returns one jittered-or-passthrough row per approved+visible listing, and `SELECT * FROM public.search_map(p_purpose := 'sale')` honors the filter shape.

- [ ] T014 [US3] Create migration file `supabase/migrations/20260526120001_create_map_jitter_function.sql` with the full PL/pgSQL body per data-model.md §1. Function name: `public.map_jitter_coordinates(uuid, uuid, numeric, numeric)`. Includes: salt read via `current_setting('app.map_jitter_salt', true)` with raise-on-null; SHA-256 hash; area-centroid fallback; ±0.0045° radius offset; ±0.02° clamp around centroid; `REVOKE ALL FROM PUBLIC` + `GRANT EXECUTE TO authenticated, anon`; `COMMENT ON FUNCTION`.
- [ ] T015 [US3] Apply the jitter-function migration via Supabase MCP `apply_migration` tool: name `"create_map_jitter_function"`, query = contents of T014's file. Per memory `project_supabase_mcp_apply_migration.md`: re-applying re-runs SQL AND adds a duplicate tracker row — the migration uses `CREATE OR REPLACE FUNCTION` so re-application is safe.
- [ ] T016 [US3] One-time setup: generate a 256-bit salt via `openssl rand -hex 32`. Apply via Supabase MCP `execute_sql`: `ALTER DATABASE postgres SET app.map_jitter_salt = '<hex>';`. Verify with `SELECT current_setting('app.map_jitter_salt');`. Save the salt to the project password manager / secrets store per quickstart.md §2.
- [ ] T017 [US3] Verify jitter function determinism via Supabase MCP `execute_sql` per quickstart.md §6 — run the smoke-test SELECT pair on the same listing id twice; confirm identical `(jittered_lat, jittered_lng)` pairs. Confirm a NULL-lat/lng call falls back to area centroid.
- [ ] T018 [P] [US1,US3] Create migration file `supabase/migrations/20260526120002_create_v_listings_map_public.sql` with the full CREATE VIEW body per data-model.md §2. View name: `public.v_listings_map_public`. 13 columns. `WHERE l.status = 'approved' AND l.location_visibility IN ('exact', 'approximate') AND (l.expires_at IS NULL OR l.expires_at > now())`. `LATERAL` join to `map_jitter_coordinates`. `GRANT SELECT TO authenticated, anon`. `COMMENT ON VIEW`.
- [ ] T019 [US1,US3] Apply the view migration via Supabase MCP `apply_migration`: name `"create_v_listings_map_public"`, query = T018's file contents.
- [ ] T020 [US3] Wire-level verification per quickstart.md §4: run all 4 SQL leak checks (4a hidden/admin_only absent; 4b non-approved absent; 4c approximate jittered; 4d exact passthrough) + the SC-011 SET ROLE anon/authenticated parity check. Document any leaks as blockers; expected: all zero / parity match.
- [ ] T021 [P] [US6] Create migration file `supabase/migrations/20260526120003_create_search_map_rpc.sql` with the full SQL function body per data-model.md §3. RPC name: `public.search_map(...)`. 16 parameters mirroring Phase 14's `search_listings` minus sort/cursor/limit. `RETURNS SETOF public.v_listings_map_public`. `LANGUAGE sql`, `SECURITY DEFINER`, `SET search_path = public`. `REVOKE ALL FROM PUBLIC` + `GRANT EXECUTE TO authenticated, anon`.
- [ ] T022 [US6] Apply the RPC migration via Supabase MCP `apply_migration`: name `"create_search_map_rpc"`, query = T021's file contents.
- [ ] T023 [US6] RPC smoke tests per quickstart.md §5: confirm `search_map()` (all-null) returns same count as `SELECT count(*) FROM v_listings_map_public`; confirm `search_map(p_purpose := 'sale')` narrows; confirm visibility gate composes (no `location_visibility='hidden'` rows leak through any filter).
- [ ] T024 [P] [US3] Create `supabase/docs/map_jitter_coordinates.md` documenting: signature, behavioral contract, salt setup procedure, rotation procedure, smoke test queries (copy from contracts/phase15-map-jitter-function.md §Smoke test queries).
- [ ] T025 [P] [US1,US3] Create `supabase/docs/v_listings_map_public.md` documenting: 13-column projection table, WHERE gates, RLS posture (inherits from `public.listings`), EXPLAIN expectations, wire-level grep gates (copy from contracts/phase15-v-listings-map-public-view.md).
- [ ] T026 [US3,US6] EXPLAIN sanity check per quickstart.md §7: run `EXPLAIN SELECT * FROM public.v_listings_map_public` via Supabase MCP `execute_sql`. Confirm the plan uses `idx_listings_status_created` (Phase 13 R-61) or sequential scan acceptable at v1 scale. Flip T014–T026 in the same commit. (Caveat: T015, T019, T022 are migration applications — the migration FILE commits AND the apply log lives in Supabase project state.)

**Checkpoint**: The Phase 15 backend surface exists. An anonymous Supabase client can `select` from `v_listings_map_public` AND call `rpc('search_map', ...)`. Zero hidden/admin_only/non-approved rows leak.

---

## Phase 4: Sub-Phase F — Localization (ARB additions)

**Purpose**: Add ~22 new bilingual keys to `app_ar.arb` + `app_en.arb` so Sub-Phases E and G can consume them.

**Goal**: After Phase 4, `flutter gen-l10n` regenerates `AppLocalizations` with all map-related getters.

- [ ] T027 Add the following keys to `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` in matched pairs. **Map page chrome** (6 keys): `map_page_title`, `map_osm_attribution`, `map_empty_state_no_listings`, `map_error_load_failed`, `map_error_retry_action`, `map_tiles_unavailable`.
- [ ] T028 Continue adding to both ARB files. **Marker preview popover** (3 keys): `map_marker_view_details_action`, `map_marker_approximate_location_label`, `map_marker_image_unavailable`.
- [ ] T029 Continue adding to both ARB files. **Center on my location FAB** (5 keys): `map_fab_center_on_me_tooltip`, `map_geolocation_permission_denied_message`, `map_geolocation_permission_permanently_denied_message`, `map_geolocation_open_settings_action`, `map_geolocation_fix_unavailable_message`.
- [ ] T030 Continue adding to both ARB files. **Filter-active alert dialog** (4 keys): `map_filter_alert_title`, `map_filter_alert_body_prefix`, `map_filter_alert_action_reset`, `map_filter_alert_action_keep`.
- [ ] T031 Continue adding to both ARB files. **Refresh button + entry-point labels** (5 keys): `map_refresh_button_tooltip`, `home_map_tile_title`, `home_map_tile_subtitle`, `listing_details_view_on_map_action`, `search_results_show_on_map_action`. Use Syrian-friendly Arabic copy (e.g., "تصفح على الخريطة" for `home_map_tile_title`, "اعرض على الخريطة" for `listing_details_view_on_map_action`, "موقع تقريبي" for `map_marker_approximate_location_label`) per Constitution V.
- [ ] T032 Run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`. Verify all ~23 new getters exist in the generated file. Run `flutter analyze` — expected: zero new analyzer warnings.
- [ ] T033 Manual smoke check: launch the app, confirm no runtime localization errors. (The new keys are not yet consumed; Phase 5 and Phase 6 will consume them.) Flip T027–T033 in the same commit.

**Checkpoint**: ARB files contain all needed keys; codegen succeeds; the app still builds and runs cleanly.

---

## Phase 5: Sub-Phase D — Domain + data layer for the map feature

**Purpose**: Define the `MapMarker` entity, `MapRepository` interface, `LoadMapMarkers` use case, DTO, datasource, and repository implementation.

**Goal**: After Phase 5, calling `getIt<LoadMapMarkers>()(filter: null)` returns a `Result<List<MapMarker>, Failure>` populated from `v_listings_map_public`.

- [ ] T034 [P] [US1,US2,US3,US4,US5,US6] Create `lib/features/map/domain/entities/map_marker.dart` per data-model.md §4.2. `MapMarker` extends `Equatable` with 11 fields: `id`, `position` (`MarkerCoordinates`), `title`, `primaryAmount` (`Decimal`), `primaryCurrencyCode`, `mainImagePath` (nullable), `propertyType` (re-exported `PropertyType` from Phase 10), `purpose` (re-exported `ListingPurpose`), `isApproximate`, `governorateNameAr`, `governorateNameEn`. Imports: `package:decimal/decimal.dart`, `package:equatable/equatable.dart`, `../../../listing_form/domain/entities/listing.dart` (for enums), `marker_coordinates.dart`.
- [ ] T035 [P] [US1,US2,US3,US4,US5,US6] Create `lib/features/map/domain/repositories/map_repository.dart` per data-model.md §4.4. Abstract class with single method `Future<Result<List<MapMarker>, Failure>> loadMarkers({FilterState? filter})`. Imports: `package:alnujom/features/search/domain/entities/filter_state.dart`, `package:alnujom/core/errors/failure.dart`, `package:alnujom/core/errors/result.dart`, `../entities/map_marker.dart`.
- [ ] T036 [US1,US2,US3,US4,US5,US6] Create `lib/features/map/domain/usecases/load_map_markers.dart` per data-model.md §4.5. `@injectable` annotated class `LoadMapMarkers(MapRepository _repository)`; `call({FilterState? filter})` delegates to `_repository.loadMarkers(filter: filter)`. (Depends on T035.)
- [ ] T037 [P] [US1,US2,US3,US4,US5,US6] Create `lib/features/map/data/models/map_marker_dto.dart` per data-model.md §5.1. DTO with all 12 fields matching the `v_listings_map_public` row shape; `MapMarkerDto.fromJson(Map<String,dynamic>)` factory; `toEntity()` method constructing `MapMarker` from the DTO + nested `MarkerCoordinates`. (Depends on T034.)
- [ ] T038 [US1,US2,US3,US4,US5,US6] Create `lib/features/map/data/datasources/supabase_map_datasource.dart` per data-model.md §5.2. `@injectable` class with constructor signature `SupabaseMapDatasource(SupabaseClientWrapper _client, CurrencyRepository _currencyRepository)` — `CurrencyRepository` (Phase 9) is injected via `@injectable`'s auto-resolution so the price-range currency conversion (R-75) is available without manual `getIt` lookup. Two methods: `Future<List<MapMarkerDto>> loadAll()` → `_client.raw.from('v_listings_map_public').select()`; `Future<List<MapMarkerDto>> loadFiltered(FilterState filter)` → `_client.raw.rpc('search_map', params: _filterToRpcParams(filter))`. Implement `_filterToRpcParams` mapper translating `FilterState` fields to the 16 RPC parameter names, calling `_currencyRepository.latestRatesForBase(...)` to pre-convert the price-range bounds into both USD and SYP per R-75. **Acceptance**: `flutter analyze` returns zero errors; the file compiles; `injection.config.dart` (regenerated in T040) registers `SupabaseMapDatasource` with both dependencies. (Depends on T037.)
- [ ] T039 [US1,US2,US3,US4,US5,US6] Create `lib/features/map/data/repositories/map_repository_impl.dart` per data-model.md §5.3. `@LazySingleton(as: MapRepository)` class implementing `MapRepository`. `loadMarkers({filter})` calls `_datasource.loadAll()` (when filter is null) or `_datasource.loadFiltered(filter)`; wraps in try/catch with `Failure.fromException`; returns `Result.success`/`Result.failure`. (Depends on T035, T038.)
- [ ] T040 [US1,US2,US3,US4,US5,US6] Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/injection.config.dart`. Verify the generated file registers `SupabaseMapDatasource`, `MapRepositoryImpl` (as `MapRepository`), and `LoadMapMarkers`. Run `flutter analyze` — zero new warnings expected.
- [ ] T041 [US1,US2,US3,US4] Manual smoke test: from a temporary debug surface (e.g., a button on the home page), call `await getIt<LoadMapMarkers>()(filter: null);`. Print the result. Expected: a non-empty `List<MapMarker>` matching the SC-011 count from quickstart.md §4. Remove the debug surface before commit. Flip T034–T041 in the same commit.

**Checkpoint**: The data path is wired end-to-end. `LoadMapMarkers` use case returns real markers from Supabase. The presentation layer (Phase 6) can consume it.

---

## Phase 6: Sub-Phase E — Presentation (MapPage + MapBloc + popover + FAB + filter alert + refresh)

**Purpose**: Build the full MapPage UX — the meat of US1, US2, US3 (visual indicator), and US4.

**Goal**: After Phase 6, the user can open the map (via the stub debug surface OR direct `context.go('/map')`), see markers, tap them, see popovers, tap to navigate, see clusters, refresh, and use "center on my location."

### Phase 6a — BLoC layer

- [ ] T042 [US1,US2,US3,US4] Create `lib/features/map/presentation/bloc/map_event.dart` per contracts/phase15-map-page-composition.md §BLoC contract. Sealed class `MapEvent` with cases: `MapOpened(MapEntryContext? context)`, `MarkersRefreshRequested`, `MarkerTapped(String listingId)`, `PopoverDismissed`, `CenterOnMyLocationRequested`, `GeolocationPermissionGranted(MarkerCoordinates devicePosition)`, `GeolocationPermissionDenied({required bool permanentlyDenied})`, `GeolocationFixFailed`, `FilterAlertDismissed`, `FilterResetRequested`.
- [ ] T043 [US1,US2,US3,US4,US6] Create `lib/features/map/presentation/bloc/map_state.dart` per contracts/phase15-map-page-composition.md §BLoC contract. Sealed class `MapState` with cases: `MapInitial`, `MapLoading`, `MapLoaded({required markers, required cameraFit, selectedMarker, activeFilter, required showFilterAlert, required geolocationStatus})`, `MapError({required failure})`. Define an enum `GeolocationStatus` (`unknown`, `granted`, `denied`, `permanentlyDenied`, `fixFailed`). Provide a `copyWith` on `MapLoaded` for partial updates.
- [ ] T044 [US1,US2,US3,US4,US6] Create `lib/features/map/presentation/bloc/map_bloc.dart` per contracts/phase15-map-page-composition.md §BLoC contract. `@injectable` class extending `Bloc<MapEvent, MapState>`. Constructor takes `LoadMapMarkers`. Implement all 10 event handlers per the transition table: `MapOpened` derives initial camera from the entry context (Syria-wide bbox for `FromHome`/`FromSearch`-no-results; centered+zoom-15 for `FromListing`; fit-to-results bbox for `FromSearch` with results); `MarkersRefreshRequested` re-fetches using cached filter; `MarkerTapped` updates `selectedMarker`; `FilterResetRequested` re-fetches with null filter and clears `activeFilter` + `showFilterAlert`. Use `flutter_map`'s `CameraFit.bounds()` and `CameraFit.coordinates()` for camera state. (Depends on T036, T042, T043.)
- [ ] T045 [US1,US2,US3,US4] Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate DI config including `MapBloc`. Verify generated file.

### Phase 6b — Widget primitives

- [ ] T046 [P] [US1] Create `lib/features/map/presentation/widgets/osm_attribution_widget.dart` per contracts/phase15-map-page-composition.md §Attribution widget. Container with `Text(l10n.map_osm_attribution)`; `Theme.of(context).colorScheme.surface.withOpacity(0.85)` background; `AppSpacing.xs` padding; `AppRadii.sm` corners.
- [ ] T047 [P] [US1,US4] Create `lib/features/map/presentation/widgets/map_refresh_button.dart` — `IconButton(icon: Icon(Icons.refresh), tooltip: l10n.map_refresh_button_tooltip, onPressed: () => context.read<MapBloc>().add(const MarkersRefreshRequested()))`.
- [ ] T048 [P] [US2,US3] Create `lib/features/map/presentation/widgets/marker_preview_popover.dart` per contracts/phase15-map-page-composition.md §Marker preview. Material `Card`; `CachedNetworkImage` via `_client.storage.from('listing-images').getPublicUrl(marker.mainImagePath!)` (handle null with placeholder); title + price (via Phase 9 `MoneyFormatter`) + property-type/purpose badge; conditional "Approximate location" `Text` when `marker.isApproximate`; tap handler navigates `context.go(AppRoutes.listingDetailsFor(marker.id))`. Reads Phase 9 `CurrencyRepository` via `getIt` for the user's display currency.
- [ ] T049 [P] [US1,US3] Create the marker pin widgets `_ApproximateMarkerPin` and `_ExactMarkerPin` as private widgets inside `map_page.dart` (or as a separate `marker_pins.dart` widget file). Exact pin: solid `Theme.colorScheme.primary` 40×40 icon. Approximate pin: 48×48 with a translucent halo (CustomPaint or stacked Container) using `colorScheme.primary.withOpacity(0.3)`. Both use Phase 2 design tokens — no hex literals.
- [ ] T050 [P] [US6] Create `lib/features/map/presentation/widgets/filter_active_alert_dialog.dart` per contracts/phase15-map-page-composition.md §Filter-active alert. Material `AlertDialog`; title `l10n.map_filter_alert_title`; body a `Wrap` of `Chip` widgets summarizing the active filter dimensions; actions: `TextButton(l10n.map_filter_alert_action_reset)` dispatching `FilterResetRequested` + `TextButton(l10n.map_filter_alert_action_keep)` dispatching `FilterAlertDismissed`. Constructor takes `FilterState filterState`.
- [ ] T051 [P] [US1] Create `lib/features/map/presentation/widgets/center_on_my_location_fab.dart` per contracts/phase15-geolocation-envelope.md §FAB widget. `FloatingActionButton(icon: Icons.my_location, tooltip: l10n.map_fab_center_on_me_tooltip, onPressed: ...)`. Handler: `Permission.locationWhenInUse.request()` → branch on `isPermanentlyDenied`/`!isGranted`/granted → `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 10))` → on `TimeoutException` dispatch `GeolocationFixFailed`. Dispatch corresponding BLoC events; show localized snackbars for denial paths. Imports `package:geolocator/geolocator.dart`, `package:permission_handler/permission_handler.dart`.

### Phase 6c — MapPage composition

- [ ] T052 [US1,US2,US3,US4,US6] Update `lib/features/map/presentation/pages/map_page.dart` (replace the Sub-Phase A stub) per contracts/phase15-map-page-composition.md §Widget tree. **Convert `MapPage` from `StatelessWidget` (Sub-Phase A T007 form) to `StatefulWidget` with a `_MapPageState` carrying a `bool _alertShown = false` flag** (needed for the filter-active alert show-once gating below). `BlocProvider<MapBloc>` wrapping a `Scaffold` with: AppBar (leading=`DeepLinkAwareBackButton`, title=`l10n.map_page_title`, actions=`[MapRefreshButton()]`); body = `BlocConsumer<MapBloc, MapState>` rendering switch over states; the `MapLoaded` branch renders a `Stack` containing `FlutterMap` (TileLayer at OSM URL with `userAgentPackageName: 'app.alnujom.realestate'` per R-94; `MarkerClusterLayerWidget` with `maxClusterRadius: 80`, `spiderfyClusterMaxZoom: 18`, `zoomToBoundsOnClick: true` per R-93), `PositionedDirectional` overlays for `OsmAttributionWidget` (bottom-start), `CenterOnMyLocationFab` (bottom-end above attribution), and conditional `MarkerPreviewPopover` (bottom-center when `selectedMarker != null`). `BlocConsumer.listener` shows `FilterActiveAlertDialog` on first `MapLoaded` with `showFilterAlert == true` AND `!_alertShown`, then sets `_alertShown = true`.
- [ ] T053 [US1,US3] Implement the marker builder helper `_buildMarker(MapMarker marker) → Marker` in `map_page.dart` per contracts/phase15-map-page-composition.md §Marker builder. Returns a `flutter_map` `Marker` whose `child` is `_ApproximateMarkerPin` (when `marker.isApproximate`) or `_ExactMarkerPin` (when not). Tap handler dispatches `MarkerTapped(marker.id)`.
- [ ] T054 [US1,US3] Manual smoke test on Infinix Note 8: navigate to `/map` via the home tile (Phase 7 wires it; for now, use a temporary debug button). Confirm map opens at Syria-wide bbox; OSM tiles render; markers paint; attribution visible; both pin variants distinguishable; FAB visible bottom-end.
- [ ] T055 [US2] Manual smoke test on Infinix Note 8: tap any marker. Confirm popover appears with image+title+price+badge. Tap popover. Confirm `/listings/:id` opens. Press back. Confirm map restores at same zoom/pan with no marker-dataset flicker (SC-005).
- [ ] T056 [US4] Manual smoke test on Infinix Note 8: zoom out to Syria-wide; confirm Damascus area clusters per R-93. Tap a cluster (not at max zoom); confirm auto-zoom + split. Zoom to max; tap a cluster of co-located markers; confirm spiderfy expansion.
- [ ] T057 [US1] Manual smoke test on Infinix Note 8: tap "center on my location" FAB. Confirm Android runtime prompt. Grant. Confirm pan/zoom to device location ≤3s. Tap again. Confirm no re-prompt, re-pan ≤1s. Clear app data; repeat tapping Deny. Confirm snackbar; map remains functional. Tap "Don't ask again" path; confirm "Open settings" snackbar action opens OS settings.
- [ ] T058 [US3] Manual smoke test on Infinix Note 8: tap a known-approximate marker. Confirm popover shows "Approximate location" / "موقع تقريبي" label per FR-003a. Flip T042–T058 in the same commit (or split into 6a/6b/6c commits if preferred).

**Checkpoint**: The MapPage is fully functional. US1, US2, US3, US4 are all reachable from the debug entry. Entry-point wiring (Phase 7) lights up US1's real path, US5, and US6.

---

## Phase 7: Sub-Phase G — Entry-point wiring (home / listing details / search)

**Purpose**: Add the three real entry points so the MapPage is reachable from the production UI.

**Goal**: After Phase 7, US1, US5, and US6 are fully wired end-to-end.

- [ ] T059 [P] [US1] Create `lib/features/home/presentation/widgets/map_entry_tile.dart` per contracts/phase15-home-map-tile.md. `Card`-styled tappable widget with `Icons.map_outlined`, title (`l10n.home_map_tile_title`), subtitle (`l10n.home_map_tile_subtitle`), and trailing chevron (directionally-aware). `onTap` calls `context.go(AppRoutes.map, extra: const MapEntryFromHome())`. Uses `AppSpacing` + `AppRadii` tokens — no hex literals.
- [ ] T060 [US1] Update `lib/features/home/presentation/pages/home_page.dart` to insert `const SliverToBoxAdapter(child: MapEntryTile())` between `const SliverToBoxAdapter(child: PropertyTypeShortcutRow())` and the existing "Latest listings" header `SliverToBoxAdapter` per R-91. Add `import '../widgets/map_entry_tile.dart';` at the top.
- [ ] T061 [P] [US5] Update `lib/features/listing_details/presentation/pages/listing_details_page.dart` (`_SuccessBody`) per contracts/phase15-listing-details-view-on-map.md. Add a `_canShowOnMap(Listing listing) → bool` helper (returns true when `locationVisibility` is `exact` or `approximate`). Below the existing `ListingLocationBlock` invocation (line ~178), insert a conditional `if (_canShowOnMap(aggregate.listing)) Padding(...)`-wrapped `TextButton.icon(Icon(Icons.map_outlined), label: Text(l10n.listing_details_view_on_map_action))` whose `onPressed` calls `context.go(AppRoutes.map, extra: MapEntryFromListing(listingId: aggregate.listing.id, position: MarkerCoordinates(latitude: aggregate.listing.latitude!, longitude: aggregate.listing.longitude!)))`. Add imports for `MapEntryFromListing`, `MapEntryFromListing`-namespace, `MarkerCoordinates`, `AppRoutes`. **MUST NOT** modify the shared `ListingLocationBlock` widget per Phase 12 Q8=A purity.
- [ ] T062 [P] [US6] Update `lib/features/search/domain/entities/filter_state.dart` (Phase 14) to add a `bool get hasAnyActiveFilter` getter per contracts/phase15-search-show-on-map.md §FilterState getter. Returns true when any of `purpose`, `propertyType`, `governorateId`, `cityId`, `areaId`, `priceRange`, `roomsFilter`, `bathroomsFilter`, `areaSizeRange`, or non-empty `keyword` is non-null. If a similar getter already exists, reuse it and skip this task.
- [ ] T063 [US6] Update `lib/features/search/presentation/pages/search_page.dart` (`_SortAndFiltersRow`) per contracts/phase15-search-show-on-map.md. Replace the end-side `TextButton.icon` ("Filters") with a `Row` containing two children: the new "Show on map" `TextButton.icon(Icon(Icons.map_outlined), label: Text(l10n.search_results_show_on_map_action), onPressed: () => _openMap(context))` AND the existing Filters button. Add the `_openMap(context)` method: reads `context.read<SearchBloc>().state.filters` and calls `context.go(AppRoutes.map, extra: MapEntryFromSearch(filterState: filters, showFilterAlert: filters.hasAnyActiveFilter))`. Add necessary imports.
- [ ] T064 [US1] Manual smoke test on Infinix Note 8: cold-launch app in `ar` + light. Confirm `MapEntryTile` is visible above "Latest listings" header without scrolling. Tap tile (stopwatch start). Confirm map opens at Syria-wide overview per FR-015a; OpenStreetMap basemap tiles render within 3 seconds and marker pins paint within an additional 2 seconds per **SC-001** (stopwatch stop at first marker paint, not at image-fill). Confirm OSM attribution visible bottom-start. Press back. Confirm return to home page (`DeepLinkAwareBackButton` falls back to home per R-96 path).
- [ ] T065 [US5] Manual smoke test: navigate to a listing details page for an approved exact-visibility listing. Confirm "View on map" button appears below location block. Tap. Confirm map opens centered on listing's marker (camera position derived from `MapEntryFromListing`). Press back. Confirm return to listing details page. Repeat for an approximate-visibility listing (button visible; map opens centered on jittered marker). Repeat for a hidden-visibility listing (button NOT present in the tree).
- [ ] T066 [US6] Manual smoke test: open search page; apply at least two filters (e.g., purpose=sale + governorate=Damascus). Tap "Show on map." Confirm: map opens with restricted marker set; filter-active alert appears within 500ms with chip-list summary + Reset+Keep actions. Tap "Reset filters." Confirm dialog dismisses, map reloads with full unfiltered set within 2s. Re-enter the flow; tap "Keep filters" instead. Confirm dialog dismisses; map stays filtered. Press back. Confirm return to search page with filters intact (Phase 14 R-77 BLoC lifetime preserved). Flip T059–T066 in the same commit.

**Checkpoint**: All three entry points wired. Phase 15's user-facing surface is complete. Remaining work is verification + polish.

---

## Phase 8: Polish & Verification (cross-cutting)

**Purpose**: Run the full quickstart verification matrix, exercise grep gates, capture any blockers.

- [ ] T067 [P] Run grep gate per quickstart.md §8a: `Select-String -Pattern "google_maps|mapbox|apple_maps" -Path pubspec.yaml pubspec.lock`. Expected: zero matches. Documents FR-019 / SC-009 compliance.
- [ ] T068 [P] Run grep gate per quickstart.md §8b (FR-005 + Constitution III): `Get-ChildItem -Recurse -Filter *.dart lib/features/map | Select-String -Pattern "\.eq\('status', 'approved'\)|\.neq\('location_visibility'"`. Expected: zero matches.
- [ ] T069 [P] Run grep gate per quickstart.md §8c (Constitution IX-clean): `Get-ChildItem -Recurse -Filter *.dart lib/features/map/domain | Select-String -Pattern "package:supabase_flutter|package:postgrest"` AND the same against `lib/features/map/presentation`. Expected: zero matches each.
- [ ] T070 [P] Run grep gate per quickstart.md §8d (FR-016): `Get-ChildItem -Recurse -Filter *.dart lib/features/map | Select-String -Pattern "Text\(['\""][^a-z_]"`. Expected: zero matches (every Text consumes AppLocalizations).
- [ ] T071 [P] Run grep gate per quickstart.md §8e (FR-018): `Get-ChildItem -Recurse -Filter *.dart lib/features/map | Select-String -Pattern "Color\(0xFF|EdgeInsets\.only\(left"`. Expected: zero matches.
- [ ] T072 [P] [US3] Run grep gate per quickstart.md §8f (FR-015c — geolocation no-leak): `Get-ChildItem -Recurse -Filter *.dart lib/features/map/data | Select-String -Pattern "latitude|longitude" | Where-Object { $_.Line -notmatch "marker_lat|marker_lng|MapMarkerDto|MarkerCoordinates" }`. Expected: zero matches.
- [ ] T073 4-combination matrix per quickstart.md §10j: on Infinix Note 8, toggle (light, dark) × (ar, en) and re-open MapPage. Confirm all chrome renders correctly in each combination (attribution, back button, refresh button, popover, FAB, filter alert, marker indicator). Capture screenshots if any visual defect appears.
- [ ] T074 [US3] Admin visibility flip per quickstart.md §10i: pick an `exact` marker; via Supabase MCP `execute_sql` run `UPDATE public.listings SET location_visibility = 'hidden' WHERE id = '<id>';`. Return to app; tap refresh. Confirm marker disappears within ~2s (SC-010). Restore the visibility.
- [ ] T075 [P] Secondary device check per quickstart.md §11: launch on Pixel 8 Pro AVD. Repeat steps 10a (home tile → Syria-wide open), 10c (cluster behavior), 10g (search → show on map → reset), 10j (4-combination). Per memory `project_android_emulator_window_offscreen.md`: if the emulator window launches off-screen, apply the SetWindowPos recipe from `docs/dev/android-emulator-windows.md`.
- [ ] T076 Final SC matrix per quickstart.md §12: tick off each of SC-001 through SC-015 against the manual verification record. Any failure becomes a blocker; document in a `DEFERRED.md` file under `specs/015-map-view/` if not blocking-but-tracked, OR fix and re-run.
- [ ] T077 Per project memory `feedback_git_workflow.md`: ensure all changes are committed (split commits per sub-phase or one squashed commit per the contract); push the branch; open one PR for the spec covering all sub-phases (NOT one PR per phase). The PR description references this tasks.md, the spec, the plan, and the quickstart final SC matrix. Flip T067–T077 in the same commit.

**Checkpoint**: Phase 15 is shippable. All 15 SCs verified. PR opened.

---

## Dependencies & Execution Order

### Phase Dependencies (sub-phase level — see plan.md §Phase Dependencies for full named-symbol detail)

- **Phase 1 (Sub-Phase A — Bootstrap)**: No deps. Can start immediately.
- **Phase 2 (Sub-Phase B — DeepLinkAwareBackButton extraction)**: No deps. Can run in parallel with Phase 1, 3, 4.
- **Phase 3 (Sub-Phase C — Backend)**: No deps. Can run in parallel with Phase 1, 2, 4.
- **Phase 4 (Sub-Phase F — Localization)**: No deps. Can run in parallel with Phase 1, 2, 3.
- **Phase 5 (Sub-Phase D — Domain + data)**: Depends on Phase 3 (Sub-Phase C — view + RPC must exist for the datasource to query).
- **Phase 6 (Sub-Phase E — Presentation)**: Depends on Phase 1 (route + MapEntryContext), Phase 2 (DeepLinkAwareBackButton), Phase 4 (ARB getters), Phase 5 (MapMarker + LoadMapMarkers).
- **Phase 7 (Sub-Phase G — Entry points)**: Depends on Phase 1 (AppRoutes.map + MapEntryContext) and Phase 4 (ARB getters). NOT on Phase 5 or Phase 6 (entry points just navigate to the route — the target page can be a stub at the moment the entry-point widget runs).
- **Phase 8 (Polish & verification)**: Depends on Phases 5, 6, 7 being complete (verifies the integrated surface).

### Parallel Opportunities

- **Wave 1 (parallel-4)**: Phases 1, 2, 3, 4 — all four can run simultaneously, no inter-deps.
- **Wave 2 (parallel-2)**: Phases 5, 7 — both wait only on Wave 1 phases.
- **Wave 3 (1)**: Phase 6 — waits on Phases 1, 2, 4, 5.
- **Wave 4 (1)**: Phase 8 — waits on Phases 5, 6, 7.

### Within Each Sub-Phase

- Tasks marked `[P]` can run in parallel (different files, no inter-task deps).
- Tasks without `[P]` must run after the previous task in the same sub-phase completes.
- Manual smoke tests (e.g., T013, T041, T054–T058, T064–T066, T073–T076) must run on the Infinix Note 8 (memory `user_test_device.md`) and require the app to be built + installed.

---

## Implementation Strategy

### MVP-First (US1 + US2 + US3 + US4)

The "map exists and works for anonymous browsing" MVP = Phases 1+2+3+4+5+6 + Phase 7's T059–T060 (home tile only). After this point:
- US1 (open map from home) ✅
- US2 (marker tap → preview → details) ✅
- US3 (visibility gate honored) ✅
- US4 (clustering) ✅
- US5, US6 still pending entry-point wiring (T061–T063).

### Incremental Delivery

1. Wave 1: Sub-Phases A+B+C+F land in parallel. App still functions (back-button widget extracted with no behavior change; ARBs ready; backend view+RPC live; map route registered with stub page).
2. Wave 2: Sub-Phase D lands (domain+data); Sub-Phase G partially lands (entry-point widgets exist but target a stub MapPage).
3. Wave 3: Sub-Phase E lands (real MapPage). MVP unlocks.
4. Wave 4: Phase 8 verification. Phase 15 ships.

### Parallel Team Strategy

With multiple sub-agents running concurrently (per `/wave` orchestrator):

- **Wave 1**: 4 agents in parallel — one per sub-phase A/B/C/F.
- **Wave 2**: 2 agents in parallel — one for D, one for G.
- **Wave 3**: 1 agent for E.
- **Wave 4**: 1 agent for Phase 8.

Total wall-clock parallelism: ~4×/2×/1×/1× across the four waves versus an 8-phase sequential chain — saves ~50% of sequential time.

---

## Touch-Fan Table

For each phase, the shared files modified. Used by the orchestrator to (a) warn each sub-agent up front about expected merge conflicts and (b) pick least-touch merge order.

- **Phase 1 (Sub-Phase A)**: `pubspec.yaml`, `pubspec.lock` (regenerated), `android/app/src/main/AndroidManifest.xml`, `lib/core/routing/app_router.dart`, `lib/features/map/domain/entities/marker_coordinates.dart` (CREATE), `lib/features/map/domain/entities/map_entry_context.dart` (CREATE), `lib/features/map/presentation/pages/map_page.dart` (CREATE stub), `lib/core/di/injection.config.dart` (REGENERATED).
- **Phase 2 (Sub-Phase B)**: `lib/core/widgets/deep_link_aware_back_button.dart` (CREATE), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — AppBar `leading` only), `lib/features/search/presentation/pages/search_page.dart` (UPDATE — AppBar `leading` only).
- **Phase 3 (Sub-Phase C)**: `supabase/migrations/20260526120001_create_map_jitter_function.sql` (CREATE), `supabase/migrations/20260526120002_create_v_listings_map_public.sql` (CREATE), `supabase/migrations/20260526120003_create_search_map_rpc.sql` (CREATE), `supabase/docs/map_jitter_coordinates.md` (CREATE), `supabase/docs/v_listings_map_public.md` (CREATE). Also touches live Supabase project state (migration applications + `ALTER DATABASE` for the salt GUC).
- **Phase 4 (Sub-Phase F)**: `lib/l10n/app_ar.arb` (UPDATE — +23 keys), `lib/l10n/app_en.arb` (UPDATE — +23 keys), `lib/l10n/app_localizations.dart` (REGENERATED), `lib/l10n/app_localizations_ar.dart` (REGENERATED), `lib/l10n/app_localizations_en.dart` (REGENERATED).
- **Phase 5 (Sub-Phase D)**: `lib/features/map/data/datasources/supabase_map_datasource.dart` (CREATE), `lib/features/map/data/models/map_marker_dto.dart` (CREATE), `lib/features/map/data/repositories/map_repository_impl.dart` (CREATE), `lib/features/map/domain/entities/map_marker.dart` (CREATE), `lib/features/map/domain/repositories/map_repository.dart` (CREATE), `lib/features/map/domain/usecases/load_map_markers.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).
- **Phase 6 (Sub-Phase E)**: `lib/features/map/presentation/bloc/map_bloc.dart` (CREATE), `lib/features/map/presentation/bloc/map_event.dart` (CREATE), `lib/features/map/presentation/bloc/map_state.dart` (CREATE), `lib/features/map/presentation/pages/map_page.dart` (UPDATE — replaces Phase 1 stub body), `lib/features/map/presentation/widgets/marker_preview_popover.dart` (CREATE), `lib/features/map/presentation/widgets/center_on_my_location_fab.dart` (CREATE), `lib/features/map/presentation/widgets/filter_active_alert_dialog.dart` (CREATE), `lib/features/map/presentation/widgets/map_refresh_button.dart` (CREATE), `lib/features/map/presentation/widgets/osm_attribution_widget.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).
- **Phase 7 (Sub-Phase G)**: `lib/features/home/presentation/widgets/map_entry_tile.dart` (CREATE), `lib/features/home/presentation/pages/home_page.dart` (UPDATE — sliver insert), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — wrap below ListingLocationBlock; **same file Phase 2 touched but in a different region**), `lib/features/search/presentation/pages/search_page.dart` (UPDATE — `_SortAndFiltersRow` body; **same file Phase 2 touched but in a different region**), `lib/features/search/domain/entities/filter_state.dart` (UPDATE — add `hasAnyActiveFilter` getter).
- **Phase 8 (Polish)**: No source-file mutations expected. Only quickstart.md verification + grep gate executions + optional `specs/015-map-view/DEFERRED.md` (CREATE) if any SC fails are tracked-but-not-blocking.

**Merge-order recommendation for the orchestrator** (least-touch-first to minimize rebase work):
- Phase 3 (backend, isolated) → Phase 4 (ARB, isolated) → Phase 1 (bootstrap, includes pubspec + manifest + route + new map skeleton files) → Phase 2 (back-button refactor, touches Phase 13 + 14 page files) → Phase 5 (domain + data, all new files) → Phase 7 (entry points; rebases on Phase 2's edits to listing_details_page.dart and search_page.dart) → Phase 6 (presentation, replaces Phase 1's stub map_page.dart) → Phase 8 (polish).

---

## Dependency Audit

Re-statement of plan.md §Phase Dependencies with the named-consumer rule re-applied. **Every line below names the specific file or exported symbol the dependent phase needs.**

- **Phase 5 (Sub-Phase D) depends on Phase 3 (Sub-Phase C)** — Phase 5's `SupabaseMapDatasource.loadAll()` (file `lib/features/map/data/datasources/supabase_map_datasource.dart`) issues a `_client.raw.from('v_listings_map_public').select()` consuming the view's 13-column projection (`id`, `title`, `marker_lat`, `marker_lng`, `is_approximate`, `location_visibility`, `primary_amount`, `primary_currency`, `main_image_path`, `property_type`, `purpose`, `governorate_name_ar`, `governorate_name_en`) defined in `supabase/migrations/20260526120002_create_v_listings_map_public.sql`. Phase 5's `loadFiltered(filter)` invokes the `public.search_map(...)` RPC defined in `supabase/migrations/20260526120003_create_search_map_rpc.sql`.
- **Phase 6 (Sub-Phase E) depends on Phase 1 (Sub-Phase A)** — Phase 6's `MapPage` is registered at `AppRoutes.map` (defined in `lib/core/routing/app_router.dart` by Phase 1); `MapBloc.add(MapOpened(context))` pattern-matches on `MapEntryContext` cases (`MapEntryFromHome`, `MapEntryFromListing`, `MapEntryFromSearch`) defined in `lib/features/map/domain/entities/map_entry_context.dart` by Phase 1.
- **Phase 6 (Sub-Phase E) depends on Phase 2 (Sub-Phase B)** — Phase 6's `MapPage` AppBar `leading` slot uses `DeepLinkAwareBackButton` exported from `lib/core/widgets/deep_link_aware_back_button.dart` by Phase 2.
- **Phase 6 (Sub-Phase E) depends on Phase 4 (Sub-Phase F)** — Phase 6's `MarkerPreviewPopover`, `FilterActiveAlertDialog`, `CenterOnMyLocationFab`, `MapRefreshButton`, `OsmAttributionWidget` widgets and `MapPage` AppBar consume 17 getters from `lib/l10n/app_localizations.dart` (regenerated by Phase 4): `map_page_title`, `map_osm_attribution`, `map_empty_state_no_listings`, `map_error_load_failed`, `map_error_retry_action`, `map_tiles_unavailable`, `map_marker_view_details_action`, `map_marker_approximate_location_label`, `map_marker_image_unavailable`, `map_fab_center_on_me_tooltip`, `map_geolocation_permission_denied_message`, `map_geolocation_permission_permanently_denied_message`, `map_geolocation_open_settings_action`, `map_geolocation_fix_unavailable_message`, `map_filter_alert_title`, `map_filter_alert_body_prefix`, `map_filter_alert_action_reset`, `map_filter_alert_action_keep`, `map_refresh_button_tooltip`.
- **Phase 6 (Sub-Phase E) depends on Phase 5 (Sub-Phase D)** — Phase 6's `MapBloc` constructor takes a `LoadMapMarkers` use case (`lib/features/map/domain/usecases/load_map_markers.dart`); `MapLoaded.markers` is typed as `List<MapMarker>` (`lib/features/map/domain/entities/map_marker.dart`); marker `Marker` widgets read `marker.position.latitude` and `marker.position.longitude` from `MarkerCoordinates` (`lib/features/map/domain/entities/marker_coordinates.dart`).
- **Phase 7 (Sub-Phase G) depends on Phase 1 (Sub-Phase A)** — Phase 7's three entry-point widgets (`MapEntryTile`, the listing-details "View on map" button, the search "Show on map" button) all call `context.go(AppRoutes.map, extra: ...)`. `AppRoutes.map` is defined in `lib/core/routing/app_router.dart` by Phase 1. The `extra` argument is one of `MapEntryFromHome`, `MapEntryFromListing(listingId, position)`, `MapEntryFromSearch(filterState, showFilterAlert)` — all defined in `lib/features/map/domain/entities/map_entry_context.dart` by Phase 1.
- **Phase 7 (Sub-Phase G) depends on Phase 4 (Sub-Phase F)** — Phase 7's three entry-point widgets consume 4 getters from `lib/l10n/app_localizations.dart` (regenerated by Phase 4): `home_map_tile_title`, `home_map_tile_subtitle`, `listing_details_view_on_map_action`, `search_results_show_on_map_action`.
- **Phase 8 (Polish) depends on Phases 5, 6, 7** — Phase 8 runs end-to-end manual verification of the integrated MapPage + entry points + backend. The grep gates verify the files Phases 5/6/7 created. The 4-combination matrix exercises the integrated UI. Phase 8 has no source-code dependency; the dependency is "the artifact being verified must exist."

**Total declared deps**: 8 lines. **Every line names a specific file path + exported symbol(s)**. Zero "easier in sequence" / "uses concepts from" wording. **Zero deps removed during audit** — the original plan.md §Self-audit count of 8 stands.

---

## Wave Plan

Topological sort over the dependency graph (Wave N = phases whose deps are all in Waves 1..N-1). Wave size cap = 4 phases (no exception triggered — no test-only/docs-only wave exceeds 4).

- **Wave 1**: Phase 1 (Bootstrap), Phase 2 (BackButton extraction), Phase 3 (Backend), Phase 4 (Localization) — **4 phases, at cap, all parallel**.
- **Wave 2**: Phase 5 (Domain + data), Phase 7 (Entry points) — **2 phases, parallel**. (Phase 5 ⇐ Phase 3; Phase 7 ⇐ Phase 1 + Phase 4 — all Wave 1.)
- **Wave 3**: Phase 6 (Presentation) — **1 phase, alone**. (Phase 6 ⇐ Phase 1 + Phase 2 + Phase 4 + Phase 5 — Phase 5 is Wave 2 so Phase 6 must wait.)
- **Wave 4**: Phase 8 (Polish & verification) — **1 phase, alone**. (Phase 8 ⇐ Phases 5, 6, 7 — Phase 6 is Wave 3.)

Orchestrator command: `/wave all --auto` executes this plan without re-derivation.

---

## Model Routing per Phase

Heuristic: **Opus** for atomic transactions / rollback / invariants / state machines / cross-currency / FX / posting / ledger / GL / RLS / concurrency / cryptographic invariants. **Sonnet** for scaffolding, l10n, DAO CRUD, widgets, tests, docs.

- **Phase 1 (Sub-Phase A — Bootstrap)**: **Sonnet** (mechanical scaffolding — pubspec edit, manifest edit, route constant, sealed-class definition, stub page).
- **Phase 2 (Sub-Phase B — DeepLinkAwareBackButton extraction)**: **Sonnet** (textual refactor extracting an inline pattern to a shared widget; no logic change).
- **Phase 3 (Sub-Phase C — Backend)**: **Opus** (SECURITY DEFINER PL/pgSQL with `pgcrypto`-based deterministic jitter algorithm; visibility-tier RLS-equivalent gate at the view layer with privacy-critical invariants — the "publisher's true coords never on the wire for approximate" guarantee is the highest-stakes invariant in the whole phase; multi-table RPC with 16 parameters mirroring Phase 14's filter shape).
- **Phase 4 (Sub-Phase F — Localization)**: **Sonnet** (ARB key additions in matched pairs; codegen).
- **Phase 5 (Sub-Phase D — Domain + data)**: **Sonnet** (entity definitions, DTO mapping, datasource SELECT/RPC plumbing — straightforward Clean Architecture wiring with no novel invariants beyond what Phase 3's backend already enforces).
- **Phase 6 (Sub-Phase E — Presentation)**: **Opus** (non-trivial state machine — `MapBloc` orchestrates 10 events × 4 states with a permission-flow sub-state-machine for geolocation that has multi-branch grant/deny/permanently-denied/fix-failed paths; `flutter_map` API surface is large; the filter-active alert show-once gating + camera fit derivation per `MapEntryContext` case + popover anchoring are all stateful concerns that benefit from Opus-level reasoning).
- **Phase 7 (Sub-Phase G — Entry points)**: **Sonnet** (three small widget additions + a one-line getter on Phase 14's FilterState — all mechanical).
- **Phase 8 (Polish & verification)**: **Sonnet** (grep gates + manual smoke tests + SC matrix tick-off — pattern matching + reporting, no novel logic).

**Format string for orchestrator**: `Phase 1: Sonnet (scaffolding + route + sealed class). Phase 2: Sonnet (back-button widget extraction refactor). Phase 3: Opus (PL/pgSQL crypto jitter + visibility-gate view + 16-param RPC — privacy-critical invariants). Phase 4: Sonnet (ARB additions + codegen). Phase 5: Sonnet (DTO + datasource + repo Clean Architecture wiring). Phase 6: Opus (10-event MapBloc + geolocation permission state machine + flutter_map composition). Phase 7: Sonnet (three entry-point widget additions). Phase 8: Sonnet (verification gates + manual smoke matrix).`

---

## Checkbox Discipline (per memory `feedback_strict_task_completion.md`)

Each sub-agent dispatched against this tasks.md MUST flip its `- [ ] T<id>` checkboxes to `- [X] T<id>` in the SAME commit as the implementation. Do NOT leave checkbox-flipping for a "cleanup pass" — it never happens. Partial / caveat / substitute-device verification stays as `- [ ]` with a `**⚠️ PARTIAL —**` prefix on the description; the gap is captured in `specs/015-map-view/DEFERRED.md` (CREATE on first deferral).

---

## Notes

- `[P]` tasks = different files, no dependencies — safe for parallel agent dispatch.
- `[Story]` label maps a task to one or more user stories from spec.md for traceability.
- Many Phase 5–6 tasks are tagged with multiple user stories because the MapPage surface is shared (US1–US4 all consume the same widget tree).
- Manual smoke tests are the verification gate per memory `feedback_no_new_tests.md` — no new automated tests are added.
- The Supabase migration applications (T015, T019, T022) execute against the live project and are NOT reversible by git revert — verify each migration's SQL is correct before applying.
- The jitter salt (T016) MUST be saved to the project secrets store — losing it means every approximate listing's marker position resets when a new salt is generated (acceptable but disruptive).
- Per memory `project_dart_defines.md`: every `flutter run`/`flutter build` MUST include `--dart-define-from-file=.env.json` or Supabase.initialize is skipped and the app red-screens.
