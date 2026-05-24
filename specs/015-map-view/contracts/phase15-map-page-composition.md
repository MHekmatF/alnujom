# Contract: `MapPage` widget composition

**Phase**: 15 — Map View
**Owner**: Sub-Phase E (presentation)
**File**: `lib/features/map/presentation/pages/map_page.dart`
**Spec refs**: US1, US2, US4, FR-007, FR-008, FR-009, FR-010, FR-011, FR-012, FR-013, FR-014, FR-014a, FR-015, FR-015a, FR-015b, FR-016, FR-017, FR-018, SC-001, SC-004, SC-005, SC-006, SC-007, SC-008
**Research refs**: R-85, R-86, R-93, R-94, R-96

## Widget tree (top-level)

```
BlocProvider<MapBloc>(
  create: (_) => getIt<MapBloc>()..add(MapOpened(entryContext)),
  child: Scaffold(
    appBar: AppBar(
      leading: const DeepLinkAwareBackButton(),
      title: Text(l10n.map_page_title),
      actions: const [MapRefreshButton()],
    ),
    body: BlocConsumer<MapBloc, MapState>(
      listener: (context, state) {
        // Show FilterActiveAlertDialog on first MapLoaded where showFilterAlert is true
        if (state is MapLoaded && state.showFilterAlert && !_alertShown) {
          _alertShown = true;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => FilterActiveAlertDialog(filterState: state.activeFilter!),
          );
        }
      },
      builder: (context, state) {
        return switch (state) {
          MapInitial() => const SizedBox.shrink(),
          MapLoading() => const Center(child: CircularProgressIndicator()),
          MapError(failure: final f) => _ErrorBanner(failure: f),
          MapLoaded() => Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCameraFit: state.cameraFit,
                    minZoom: 6,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'app.alnujom.realestate',
                      maxZoom: 18,
                      errorTileCallback: (_, __, ___) {/* error tile widget */},
                    ),
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 80,
                        spiderfyClusterMaxZoom: 18,
                        zoomToBoundsOnClick: true,
                        markers: state.markers.map(_buildMarker).toList(),
                        builder: (context, markers) => _ClusterBadge(count: markers.length),
                      ),
                    ),
                  ],
                ),
                // Overlay chrome
                const Positioned(
                  top: 8, right: 8,
                  child: SizedBox.shrink(), // refresh moved to AppBar action
                ),
                const PositionedDirectional(
                  bottom: 80, end: 16,
                  child: CenterOnMyLocationFab(),
                ),
                const PositionedDirectional(
                  bottom: 8, start: 8,
                  child: OsmAttributionWidget(),
                ),
                if (state.selectedMarker != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: MarkerPreviewPopover(marker: state.selectedMarker!),
                  ),
              ],
            ),
        };
      },
    ),
  ),
)
```

## BLoC contract

**Events**:
- `MapOpened(MapEntryContext? context)` — fires on `BlocProvider`'s `create`. Determines initial camera + filter.
- `MarkersRefreshRequested` — fires from `MapRefreshButton` tap.
- `MarkerTapped(String listingId)` — fires from any marker tap.
- `PopoverDismissed` — fires when user taps elsewhere on the map.
- `CenterOnMyLocationRequested` — fires from `CenterOnMyLocationFab` tap.
- `GeolocationPermissionGranted(MarkerCoordinates devicePosition)` — fires from the FAB handler after a successful permission + location fix.
- `GeolocationPermissionDenied(bool permanentlyDenied)` — fires on user denial.
- `GeolocationFixFailed` — fires if permission was granted but no fix was obtained within a reasonable window (10s default; plan-time tunable).
- `FilterAlertDismissed` — fires on "Keep filters" tap or tap-outside.
- `FilterResetRequested` — fires on "Reset filters" tap.

**States** (sealed):
- `MapInitial` — pre-first-load.
- `MapLoading` — fetch in flight.
- `MapLoaded({markers, cameraFit, selectedMarker?, activeFilter?, showFilterAlert, geolocationStatus})` — the main success state.
- `MapError({failure})` — fetch failed.

**Transitions**:
- `MapOpened(FromHome)` → `MapLoading` → `MapLoaded(markers=full, cameraFit=Syria-wide, activeFilter=null, showFilterAlert=false)`.
- `MapOpened(FromListing(id, position))` → `MapLoading` → `MapLoaded(markers=full, cameraFit=centered-on-position, selectedMarker=marker-for-id, activeFilter=null, showFilterAlert=false)`.
- `MapOpened(FromSearch(filter, showAlert))` → `MapLoading` → `MapLoaded(markers=filtered, cameraFit=fit-to-results, activeFilter=filter, showFilterAlert=showAlert)`.
- `MarkersRefreshRequested` → `MapLoading` → `MapLoaded(markers=re-fetched-with-cached-filter, ...same camera...)`.
- `MarkerTapped(id)` → `MapLoaded(...same..., selectedMarker=markers.firstWhere(.id==id))`.
- `PopoverDismissed` → `MapLoaded(...same..., selectedMarker=null)`.
- `FilterResetRequested` → `MapLoading` → `MapLoaded(markers=full, activeFilter=null, showFilterAlert=false)`.

## Marker builder

```dart
Marker _buildMarker(MapMarker marker) => Marker(
  point: LatLng(marker.position.latitude, marker.position.longitude),
  width: marker.isApproximate ? 48 : 40,
  height: marker.isApproximate ? 48 : 40,
  child: marker.isApproximate
    ? _ApproximateMarkerPin()  // distinct pin: halo + dashed accent + theme.primary
    : _ExactMarkerPin(),       // standard pin: solid theme.primary
  onTap: () => context.read<MapBloc>().add(MarkerTapped(marker.id)),
);
```

**Visual indicator for approximate markers** (FR-003a): a dashed halo or a 20%-larger pin with translucent ring distinguishes `is_approximate` markers from `exact` markers without using map-tile real estate. The exact visual treatment uses Phase 2 design tokens (`Theme.of(context).colorScheme.primary` for the pin fill; `withOpacity(0.3)` for the halo).

## Tile layer (FR-008, FR-019, R-94)

- `urlTemplate`: `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (OSMF public tiles).
- `userAgentPackageName`: `'app.alnujom.realestate'` — required by OSMF tile usage policy.
- `maxZoom`: 18, `minZoom`: 6.
- `errorTileCallback`: render a grey placeholder tile when fetch fails (per edge case in spec.md).

## Attribution widget (FR-008, SC-007)

A `Container` with `Text(l10n.map_osm_attribution)` (e.g., "© OpenStreetMap contributors" / "© مساهمو OpenStreetMap"), positioned bottom-start of the map overlay. Always visible. Uses `Theme.of(context).colorScheme.surface.withOpacity(0.85)` for the background so it reads on both light and dark tile sets.

## Filter-active alert (FR-007a, SC-013)

Shown via `showDialog` immediately after the first `MapLoaded` emission where `showFilterAlert` is true. Tracked via a `bool _alertShown` flag in the page's `State` to prevent re-showing within the same session. The dialog dispatches `FilterResetRequested` or `FilterAlertDismissed` based on user choice.

## Acceptance tests (manual)

- SC-001: Map renders Syria-wide tiles within 3s on Infinix Note 8 over Syrian 4G.
- SC-004: Tap any marker → popover appears within 500ms; tap popover → `/listings/:id` renders within +1s.
- SC-005: Tap marker → tap popover → details page → press back → camera position is identical to pre-tap.
- SC-006: At Syria-wide zoom with ≥30 seeded Damascus listings, see one cluster (not 30 pins); zoom in, see cluster split.
- SC-007: Attribution visible in light+ar, light+en, dark+ar, dark+en.
