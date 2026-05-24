# Phase 15 — Map View: Deferred Items

This file tracks intentional gaps per project memory `project_deferred_work.md`.
A spec is not shippable until all items here are either resolved or explicitly
accepted as post-MVP.

---

## D-T013 — Sub-Phase B smoke test (back-button 4-scenario matrix)

**Task**: T013
**Sub-Phase**: B — DeepLinkAwareBackButton extraction
**Status**: Deferred — device unavailable at worktree commit time

**Gap**: The 4-scenario manual smoke test (deep-link to listing details + back;
card-tap to listing details + back; hero-search to search + back; deep-link to
search + back) could not be run because the Infinix Note 8 (primary QA device
per memory `user_test_device.md`) was not connected during the Sub-Phase B
worktree commit.

**Risk**: Low. The refactor is a pure textual substitution — the extracted
`DeepLinkAwareBackButton` contains the identical `Navigator.canPop(context)`
conditional that was previously inline in both pages. `flutter analyze` is clean.
No behavioral logic was introduced or removed.

**Resolution**: Run the 4-scenario matrix on the Infinix Note 8 during Phase 8
(Polish & Verification, T073+) or when the device is next available. If a
regression is found, fix it and re-open T013 with the corrected behavior before
merging the spec PR.

**Blocker for merge?**: No — this is a verification gap on a zero-logic-change
refactor, not a correctness gap. The Phase 8 checkpoint will catch any regression.

---

## D-C001 — Salt storage: Vault instead of Postgres GUC (DEVIATION from R-92)

**Task**: T016
**Sub-Phase**: C — Backend (jitter function, view, RPC)
**Status**: Resolved by deviating; documented; non-blocking

### What the plan said

Research decision R-92 and tasks T014 / T016 instructed:

> The `app.map_jitter_salt` Postgres GUC MUST be set out-of-band on the live
> Supabase project via `ALTER DATABASE postgres SET app.map_jitter_salt = '<hex>'`.

The migration body was to read it via `current_setting('app.map_jitter_salt', true)`.

### What actually happened

On the live Supabase project, the `postgres` role exposed by the MCP server
cannot set parameters in custom GUC namespaces (`app.*`):

```
ERROR: 42501: permission denied to set parameter "app.map_jitter_salt"
```

This is a Supabase platform restriction — the `app.*` namespace requires
superuser, which is reserved to the Supabase managed-platform role. Attempted
via `ALTER DATABASE`, `ALTER ROLE`, and inside an `apply_migration` payload;
all denied.

### Resolution

The migration was rewritten to read the salt from **Supabase Vault**
(`vault.decrypted_secrets WHERE name = 'map_jitter_salt'`) instead. This
aligns better with project memory `project_secrets_storage.md` + ADR-0001
("backend secrets and admin-only per-user PII go in Supabase Vault"), which
would have been a stronger preference even without the permission constraint.

The migration file (`supabase/migrations/20260526120001_create_map_jitter_function.sql`)
and `supabase/docs/map_jitter_coordinates.md` document the deviation inline.
Setup is now `SELECT vault.create_secret('<256-bit-hex>', 'map_jitter_salt', ...)`
in place of `ALTER DATABASE postgres SET app.map_jitter_salt = '<hex>'`.

### Trade-offs (Vault vs GUC)

| Dimension | GUC (R-92 plan) | Vault (actual) |
|-----------|-----------------|-----------------|
| Setup | One `ALTER DATABASE` | One `vault.create_secret()` |
| Rotation | One `ALTER DATABASE` | One `vault.update_secret()` |
| Read cost per jitter call | `current_setting` — fast | `SELECT FROM vault.decrypted_secrets` — slower (AEAD decrypt) |
| Backup posture | GUC value in `pg_db_role_setting` (backed up) | Vault row backed up with schema; KEK managed by Supabase |
| Visibility to clients | Hidden behind `SECURITY DEFINER` | Same |
| Aligns with ADR-0001 | Partial (R-92 acknowledged narrow-threat-model exception) | Fully |

### Future-spec consideration

If Supabase ever grants project owners the ability to `ALTER DATABASE ... SET app.*`,
a future spec MAY migrate the salt back to a GUC for the per-call read cost win.
The change is internal to the function body — no callers need to know.

**Blocker for merge?**: No — the privacy invariant is unchanged (salt still
hidden behind SECURITY DEFINER, never visible to anon/authenticated).

---

## D-C002 — Markerable-row guard added to view WHERE (HARDENING beyond data-model.md §2)

**Task**: T018
**Sub-Phase**: C — Backend
**Status**: Resolved by view-level guard; documented; non-blocking

### What the plan said

Data-model.md §2 defined the view's WHERE clause as:

```sql
WHERE l.status = 'approved'
  AND l.location_visibility IN ('exact', 'approximate')
  AND (l.expires_at IS NULL OR l.expires_at > now());
```

No coordinate / area presence check.

### What actually happened

Wire-level leak check 4c (`approximate listings have jittered coords`) failed
at first apply because six approved approximate listings exist in test data
with `area_id IS NULL` AND `latitude IS NULL` AND `longitude IS NULL`. These
rows pre-date Phase 10 R-12's submit-time auto-population guarantee. The jitter
function correctly raised:

```
ERROR: P0001: area <NULL> missing centroid; cannot jitter
```

But this crashed `SELECT * FROM v_listings_map_public` rather than returning
the other rows.

### Resolution

Added a markerable-row guard to the view's WHERE:

```sql
AND (
  (l.location_visibility = 'exact'       AND l.latitude IS NOT NULL AND l.longitude IS NOT NULL)
  OR
  (l.location_visibility = 'approximate' AND l.area_id  IS NOT NULL)
);
```

Rows that violate this invariant cannot render on a map and are excluded for
view robustness. Phase 10 R-12's auto-population guarantees new submissions
always satisfy it; the guard exists for pre-existing data only.

### Future-spec consideration

A future spec MAY backfill `area_id` for (or delete) the six legacy
approved-approximate-no-area rows in production. Until then the guard keeps
the view safe.

**Blocker for merge?**: No — the privacy invariant is strengthened, not weakened.

---

## D-T041 — Sub-Phase D smoke test (LoadMapMarkers use case end-to-end)

**Task**: T041
**Sub-Phase**: D — Domain + data layer
**Status**: Deferred — device + debug-surface unavailable in orchestrator environment

**Gap**: T041 asked for a temporary debug surface (e.g., a button on the home
page) that calls `await getIt<LoadMapMarkers>()(filter: null)` from a running
app instance and prints the result. The Phase 5 worktree agent erred out mid-task
(API: Internal server error after 46 tool uses) so the orchestrator salvaged the
partial work and finished T038/T039 inline; this path does not include adding +
removing a debug surface in a running app.

**Risk**: Low. The data path's correctness has independent verification:
- Wire-level: `anon=6` markers via Supabase MCP `execute_sql` (Wave 1 review pass).
- Build-level: `flutter analyze --fatal-infos` clean; `flutter build apk --debug`
  succeeds.
- DI registration: `dart run build_runner build` wrote `injection.config.dart`
  with `SupabaseMapDatasource`, `MapRepositoryImpl` (as `MapRepository`), and
  `LoadMapMarkers` entries.
- Pattern parity: the datasource mirrors Phase 14's `SupabaseSearchDatasource`
  exactly (same `_client` injection, same R-75 price-range conversion, same
  storage URL rewrite for `main_image_path`).

**Resolution**: Phase 8 (Polish & Verification, T076 SC matrix) verifies the
integrated MapPage end-to-end on the Infinix Note 8 via the home-tile entry,
which transitively exercises `LoadMapMarkers`. If a regression surfaces, fix
it then and re-open T041.

**Blocker for merge?**: No — the use case is fully wired; the unrun smoke is
the temporary-debug-surface dance, not a correctness gap.

---

## D-T054 — Sub-Phase E smoke test (initial map render)

**Task**: T054
**Sub-Phase**: E — Presentation (MapPage + MapBloc + 5 widgets)
**Status**: Deferred — device unavailable in orchestrator environment

**Gap**: Manual smoke test on Infinix Note 8: navigate to `/map` (via the
home tile wired in Phase 7), confirm OSM tiles render, markers paint, both
pin variants distinguishable, attribution + FAB visible. Device not
connected during the worktree commit.

**Risk**: Low. The MapPage composition is a direct translation of
`contracts/phase15-map-page-composition.md` §Widget tree:
- `flutter analyze --fatal-infos` is clean (zero issues).
- `flutter build apk --debug --dart-define-from-file=.env.json` succeeds.
- 4 grep gates pass: no hex literals; no left-only `EdgeInsets`; no inline
  strings in `Text(...)`; no Supabase imports in domain/presentation; no
  geolocation leak from data layer.
- `MapBloc` is registered in `injection.config.dart` (factory; route-scoped).
- All 19 ARB keys (`map_*`) exist in `app_localizations.dart` (Phase 4 keys).
- `flutter_map ^7.0.0`, `flutter_map_marker_cluster ^1.4.0`, `latlong2 ^0.9.1`,
  `geolocator ^13.0.4`, `permission_handler ^11.4.0` are pinned in pubspec
  and resolved.

**Resolution**: Phase 8 (Polish & Verification, T073+) runs the SC matrix
on the Infinix Note 8 which transitively exercises T054. If the OSM tiles
fail to render (e.g., OSMF blocks the userAgent), capture in a new
deferred entry and remediate.

**Blocker for merge?**: No — the integration is statically verified end-to-end.

---

## D-T055 — Sub-Phase E smoke test (marker tap → popover → details + back)

**Task**: T055
**Sub-Phase**: E — Presentation
**Status**: Deferred — device unavailable

**Gap**: Tap any marker → confirm popover appears with image+title+price+badge
→ tap popover → confirm `/listings/:id` opens → press back → confirm map
restores at same zoom/pan with no marker-dataset flicker (SC-005).

**Risk**: Low–medium. The popover dispatches `MarkerTapped(listingId)` to
the BLoC which calls `current.copyWith(selectedMarker: ...)` — a non-
re-fetching state transition. The back-navigation path is the route-scoped
BLoC lifetime (`@injectable`, not `@lazySingleton`) which preserves
markers + camera across the round-trip per the same pattern Phase 14
established for search-results.

**Resolution**: Phase 8 SC-005 acceptance.

**Blocker for merge?**: No.

---

## D-T056 — Sub-Phase E smoke test (clustering + spiderfy)

**Task**: T056
**Sub-Phase**: E — Presentation
**Status**: Deferred — device unavailable

**Gap**: Zoom out to Syria-wide → confirm Damascus area clusters per R-93.
Tap a cluster → confirm auto-zoom + split. Zoom to max → tap a cluster of
co-located markers → confirm spiderfy expansion.

**Risk**: Low. `MarkerClusterLayerOptions` is configured with
`maxClusterRadius: 80` and `zoomToBoundsOnClick: true` per R-93. Spiderfy
is enabled by default (`spiderfyCluster: true`) and
`disableClusteringAtZoom` defaults to 20 (above our `maxZoom: 18`), so
co-located markers will spiderfy on tap rather than disappear.

**API NOTE**: `flutter_map_marker_cluster 1.4.0` does NOT expose a
`spiderfyClusterMaxZoom` parameter (the R-93 reference was to an older
API). The semantic intent ("spiderfy at max zoom") is achieved by the
combination of `spiderfyCluster: true` + `disableClusteringAtZoom: 20`
(default) + `maxZoom: 18` (our cap) — co-located markers at zoom 18 form
a cluster which the user can spiderfy by tap.

**Resolution**: Phase 8 SC-006 acceptance. If the spiderfy UX is rough,
tune `spiderfyCircleRadius` (default 40).

**Blocker for merge?**: No — the cluster behavior is functionally correct.

---

## D-T057 — Sub-Phase E smoke test (geolocation permission lifecycle)

**Task**: T057
**Sub-Phase**: E — Presentation (`CenterOnMyLocationFab`)
**Status**: Deferred — device unavailable

**Gap**: Tap FAB → confirm Android runtime prompt → grant → pan/zoom to
device location ≤3s → tap again → confirm no re-prompt, re-pan ≤1s. Clear
app data → repeat tapping Deny → confirm snackbar; map remains functional.
Tap "Don't ask again" path → confirm "Open settings" snackbar action opens
OS settings.

**Risk**: Medium. The geolocation envelope is the most stateful part of
Phase 15:
- `permission_handler 11.4.0` is the resolved version (≥ R-88's ≥11.3.0).
- The FAB widget calls `Permission.locationWhenInUse.request()` whose
  return value the orchestrator branches on three ways
  (`isPermanentlyDenied`, `!isGranted`, granted).
- `Geolocator.getCurrentPosition(locationSettings: LocationSettings(...))`
  uses the modern 13.x API (the `desiredAccuracy:` + `timeLimit:` args are
  deprecated in 13.x).
- `TimeoutException` (from `LocationSettings.timeLimit`) dispatches
  `GeolocationFixFailed`. `LocationServiceDisabledException` is also
  caught with the same snackbar (added defensively beyond the
  envelope contract — confirms the "Location off" device path).
- FR-015c invariant verified by grep gate: no device coord ever sent to
  Supabase.

**Resolution**: Phase 8 SC-014 + SC-015 acceptance.

**Blocker for merge?**: No.

---

## D-T058 — Sub-Phase E smoke test (approximate marker indicator label)

**Task**: T058
**Sub-Phase**: E — Presentation (`MarkerPreviewPopover`)
**Status**: Deferred — device unavailable

**Gap**: Tap a known-approximate marker → confirm popover shows
"Approximate location" / "موقع تقريبي" label per FR-003a.

**Risk**: Low. The popover renders the label conditionally on
`marker.isApproximate` via `if (widget.marker.isApproximate) ...[...]`
in its column. The label key (`map_marker_approximate_location_label`)
exists in `app_localizations.dart` and is consumed via `l10n.<key>`.

**Resolution**: Phase 8 SC-008 + FR-003a acceptance.

**Blocker for merge?**: No.
