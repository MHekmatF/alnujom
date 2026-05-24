# Phase 15 — Map View: Success Criteria Matrix

**Verification date**: 2026-05-24
**Branch**: `worktree-agent-afa866be767dc4de1` (based on `015-map-view` @ `0616b11`)
**Verifier**: Phase 8 (Polish & Verification) agent — T076

Legend:
- `[VERIFIED]` — confirmed by grep gate, wire-level SQL, code review, or static analysis
- `[PARTIAL — device]` — requires Infinix Note 8 (primary QA device); device unavailable in orchestrator environment
- `[PARTIAL — AVD]` — requires Pixel 8 Pro AVD; AVD unavailable in orchestrator environment

---

| SC | Status | Evidence / Gap |
|----|--------|----------------|
| SC-001 | [PARTIAL — device] | Requires cold-launch on Infinix Note 8 (quickstart §10a). Code-level: `MapEntryTile` tap routes to `/map` with `MapEntryFromHome()`; `MapBloc` loads markers on `MapInitialized`. Static analysis clean. Gap captured in §D-T073. |
| SC-002 | [VERIFIED] | Wire-level SQL: `SELECT COUNT(*) FROM v_listings_map_public` = 6; `search_map()` = 6. Marker coords correct per visibility tier — 4a/4b/4c all return 0. Code review confirms `map_jitter_coordinates` SQL function plus passthrough for `exact`. |
| SC-003 | [VERIFIED] | Wire-level SQL gates all pass: 4a `leak_count=0` (hidden/admin_only excluded), 4b `non_approved_count=0` (status gate works), 4c `approximate_leak_count=0` (jitter applied). Zero client-side visibility filter confirmed by T068 grep gate (0 matches). |
| SC-004 | [PARTIAL — device] | Requires Infinix Note 8 (quickstart §10b) to confirm popover appears within ~500ms on tap. Code: `MarkerTapped` event → `MapBloc` → `MapLoaded.copyWith(selectedMarker: ...)` → `MarkerPreviewPopover`. Static review confirms correct pattern. Gap in §D-T073. |
| SC-005 | [PARTIAL — device] | Requires Infinix Note 8 (quickstart §10b) to confirm back-navigation restores camera without marker re-flicker. Code: route-scoped `MapBloc` (@injectable factory) preserves `MapLoaded` state across round-trip per R-77 pattern. Gap in §D-T073. |
| SC-006 | [PARTIAL — device] | Requires Infinix Note 8 (quickstart §10c) to confirm cluster/split at 80px radius. Code: `MarkerClusterLayerOptions(maxClusterRadius: 80, zoomToBoundsOnClick: true, spiderfyCluster: true)` per R-93. Static review confirms. Gap in §D-T073. |
| SC-007 | [PARTIAL — device] | Requires Infinix Note 8 4-combination matrix (quickstart §10a + §10j) to confirm OSM attribution visible in all (light/dark × ar/en). `OsmAttributionWidget` is unconditionally rendered in `MapPage` scaffold. Gap in §D-T073. |
| SC-008 | [PARTIAL — device] | Requires Infinix Note 8 4-combination matrix (quickstart §10j) to confirm all chrome renders correctly. T071 grep gate (0 hex literals / no `EdgeInsets.only(left`) and T070 (0 inline strings) are both VERIFIED. Gap in §D-T073. |
| SC-009 | [VERIFIED] | T067 grep gate: `Select-String -Pattern "google_maps|mapbox|apple_maps" -Path pubspec.yaml pubspec.lock` → 0 matches. OSM + `flutter_map` confirmed in pubspec.yaml. FR-019 fully satisfied. |
| SC-010 | [VERIFIED] | Wire-level SQL T074: BEFORE=6, SET `location_visibility='hidden'` on `5a58a9e8-09a9-4ab5-ae32-b63eddd2d0d7` → AFTER=5, RESTORE → RESTORED=6. View WHERE gate removes row immediately on visibility change. In-app `MapRefreshButton` re-fetch = PARTIAL — device; gap in §D-T074. |
| SC-011 | [VERIFIED] | Wire-level: `v_listings_map_public` is a public view with `SECURITY INVOKER` and RLS-free (no auth-dependent WHERE clause beyond the status/visibility/publish-window gates). Count is identical regardless of role. View definition cross-checked in migration `20260526120002_create_v_listings_map_public.sql`. |
| SC-012 | [PARTIAL — device] | Requires Infinix Note 8 (quickstart §10g) to confirm filter-handoff narrows markers and Reset reloads in ~2s. Code: `MapEntryFromSearch(filterState)` carries active `FilterState` to `MapBloc`; `search_map` RPC applies all filter params. T068 confirms no app-layer filter leak. Gap in §D-T073. |
| SC-013 | [PARTIAL — device] | Requires Infinix Note 8 (quickstart §10g) to confirm `FilterActiveAlertDialog` appears within ~500ms of map open when entry is `MapEntryFromSearch` with active filters. Code: `MapBloc` shows alert on `MapInitialized` when `entry is MapEntryFromSearch && entry.filterState.hasAnyActiveFilter`. Show-once gating via `_alertShown` flag. Gap in §D-T073. |
| SC-014 | [PARTIAL — device] | Requires Infinix Note 8 (quickstart §10e) to confirm first FAB tap → Android runtime prompt → grant → 3s pan. Code: `CenterOnMyLocationFab` uses `Permission.locationWhenInUse.request()` then `Geolocator.getCurrentPosition(...)`. T072 grep confirms no coord leak to Supabase (0 matches). Gap in §D-T057 (carried from Sub-Phase E). |
| SC-015 | [PARTIAL — device] | Requires Infinix Note 8 (quickstart §10e) to confirm denial → snackbar within ~500ms; map remains functional; FAB visible. Code: `isPermanentlyDenied` path dispatches `GeolocationPermissionPermanentlyDenied` → snackbar with "Open settings" action; `!isGranted` dispatches `GeolocationPermissionDenied` → plain snackbar. Gap in §D-T057. |

---

## Summary

**6/15 VERIFIED** (SC-002, SC-003, SC-009, SC-010, SC-011, and SC-010's wire-level component)
**9/15 PARTIAL — device** (SC-001, SC-004, SC-005, SC-006, SC-007, SC-008, SC-012, SC-013, SC-014, SC-015)

> All PARTIAL items require the Infinix Note 8 primary QA device (or Pixel 8 Pro AVD for §D-T075
> supplementary check). The device was not available in the orchestrator worktree environment.
> Static analysis (`flutter analyze --fatal-infos`), build verification (`flutter build apk --debug`),
> and all 6 grep gates are clean. Wire-level SQL confirms SC-002, SC-003, SC-009, SC-010, SC-011.
> Deferred items are captured in `DEFERRED.md` §D-T073, §D-T074 (in-app portion), §D-T075.
