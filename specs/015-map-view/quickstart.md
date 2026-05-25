# Quickstart: Phase 15 — Map View

**Branch**: `015-map-view` | **Date**: 2026-05-24 | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md) | **Data Model**: [data-model.md](data-model.md)

End-to-end manual verification for Phase 15. Walks through backend setup, grep gates, and a two-device Flutter UI walk covering every SC and every entry point. Reference device: **Infinix Note 8** (per memory `user_test_device.md`); secondary device: Pixel 8 Pro AVD.

> **Pre-requisite**: All prior phases (1–14) merged. `.env.json` configured with `SUPABASE_URL` + `SUPABASE_ANON_KEY` per memory `project_dart_defines.md`.

---

## 1. Apply Phase 15 migrations

```powershell
# From the project root, via Supabase MCP apply_migration tool (preferred over
# direct psql to keep the tracker row in sync). Apply in dependency order:
mcp__supabase__apply_migration --name "create_map_jitter_function" --query (Get-Content supabase/migrations/20260526120001_create_map_jitter_function.sql -Raw)
mcp__supabase__apply_migration --name "create_v_listings_map_public" --query (Get-Content supabase/migrations/20260526120002_create_v_listings_map_public.sql -Raw)
mcp__supabase__apply_migration --name "create_search_map_rpc" --query (Get-Content supabase/migrations/20260526120003_create_search_map_rpc.sql -Raw)
```

> **Memory check** (`project_supabase_mcp_apply_migration.md`): Re-applying an existing migration name re-runs the SQL AND adds a duplicate tracker row. If you need to re-run, verify SQL-idempotency (all three Phase 15 migrations use `CREATE OR REPLACE`, so re-application is safe).

## 2. Set the jitter salt (one-time setup)

```powershell
$salt = (openssl rand -hex 32)
# Apply via Supabase MCP execute_sql:
mcp__supabase__execute_sql --query "ALTER DATABASE postgres SET app.map_jitter_salt = '$salt';"
# Verify:
mcp__supabase__execute_sql --query "SELECT current_setting('app.map_jitter_salt');"
# Expected: the hex string set above
```

> Save the salt securely (password manager / project secrets). Rotation requires re-running this step and re-jitters every approximate listing's marker.

## 3. Seed verification data

Need at least one approved listing of each visibility tier for the wire-level checks, plus ≥ 30 approved listings clustered in central Damascus for the cluster-UX check, plus a few in Aleppo / Latakia for the Syria-wide overview check.

```sql
-- Verify per-visibility listing counts (assuming prior phases seeded some data;
-- otherwise create test rows via the Phase 10 publisher flow + Phase 12 approve flow)
SELECT location_visibility, count(*)
FROM public.listings
WHERE status = 'approved'
GROUP BY location_visibility
ORDER BY location_visibility;
-- Expected: rows for at least 'exact' and 'approximate' (hidden / admin_only optional but recommended for SC-003)

-- Verify cluster coverage in Damascus
SELECT count(*)
FROM public.listings l
JOIN public.areas a ON a.id = l.area_id
JOIN public.cities c ON c.id = a.city_id
JOIN public.governorates g ON g.id = c.governorate_id
WHERE l.status = 'approved'
  AND g.display_name->>'en' = 'Damascus';
-- Expected: ≥ 30
```

If the counts are low, run the Phase 10 + Phase 11 + Phase 12 happy paths (or insert test rows via direct SQL) to populate.

## 4. Wire-level inspection of the visibility gate (SC-003)

```sql
-- 4a. Hidden + admin_only never appear in the public dataset
SELECT count(*) AS leak_count
FROM public.v_listings_map_public v
JOIN public.listings l ON l.id = v.id
WHERE l.location_visibility IN ('hidden', 'admin_only');
-- Expected: leak_count = 0

-- 4b. Non-approved never appear
SELECT count(*) AS non_approved_count
FROM public.v_listings_map_public v
JOIN public.listings l ON l.id = v.id
WHERE l.status != 'approved';
-- Expected: non_approved_count = 0

-- 4c. Approximate listings have jittered (not true) coords
SELECT count(*) AS approximate_leak_count
FROM public.v_listings_map_public v
JOIN public.listings l ON l.id = v.id
WHERE l.location_visibility = 'approximate'
  AND v.marker_lat = l.latitude
  AND v.marker_lng = l.longitude;
-- Expected: approximate_leak_count = 0

-- 4d. Exact listings have passthrough coords
SELECT count(*) AS exact_mismatch_count
FROM public.v_listings_map_public v
JOIN public.listings l ON l.id = v.id
WHERE l.location_visibility = 'exact'
  AND (v.marker_lat != l.latitude OR v.marker_lng != l.longitude);
-- Expected: exact_mismatch_count = 0

-- 4e. Same dataset for authenticated and anon (SC-011)
SET ROLE anon;
SELECT count(*) AS anon_count FROM public.v_listings_map_public;
SET ROLE authenticated;
SELECT count(*) AS auth_count FROM public.v_listings_map_public;
-- Expected: anon_count = auth_count
RESET ROLE;
```

## 5. RPC smoke tests (FR-007a, SC-012)

```sql
-- 5a. All-null returns full dataset
SELECT count(*) AS rpc_count FROM public.search_map();
SELECT count(*) AS view_count FROM public.v_listings_map_public;
-- Expected: rpc_count = view_count

-- 5b. Facet narrows
SELECT count(*) AS sale_count FROM public.search_map(p_purpose := 'sale');
SELECT count(*) AS all_count FROM public.search_map();
-- Expected: sale_count <= all_count

-- 5c. Visibility gate composes (hidden listing absent even with matching facet)
SELECT count(*) AS hidden_leak FROM public.search_map(p_purpose := 'sale') s
WHERE s.location_visibility = 'hidden';
-- Expected: 0
```

## 6. Jitter determinism check (R-87)

```sql
-- 6a. Same listing returns same jittered coords on every call
WITH calls AS (
  SELECT v.id, v.marker_lat, v.marker_lng FROM public.v_listings_map_public v
  WHERE v.is_approximate = true LIMIT 5
)
SELECT id, marker_lat AS first_lat, marker_lng AS first_lng,
       (SELECT marker_lat FROM public.v_listings_map_public WHERE id = calls.id) AS second_lat,
       (SELECT marker_lng FROM public.v_listings_map_public WHERE id = calls.id) AS second_lng
FROM calls;
-- Expected: first_lat = second_lat AND first_lng = second_lng for every row

-- 6b. Jittered coords fall within the area's ±0.02° clamp
SELECT count(*) AS clamp_violations
FROM public.v_listings_map_public v
JOIN public.listings l ON l.id = v.id
JOIN public.areas a ON a.id = l.area_id
WHERE v.is_approximate = true
  AND (v.marker_lat < a.centroid_lat - 0.02 OR v.marker_lat > a.centroid_lat + 0.02
       OR v.marker_lng < a.centroid_lng - 0.02 OR v.marker_lng > a.centroid_lng + 0.02);
-- Expected: clamp_violations = 0
```

## 7. EXPLAIN check (acceptable plan)

```sql
EXPLAIN SELECT * FROM public.v_listings_map_public;
```

Expected plan elements:
- Sequential scan or `idx_listings_status_created` index scan on `public.listings`
- `LATERAL` joins for prices, media, jitter function
- Hash/nested-loop join for governorates
- Cost dominated by the SHA-256 digest call for approximate listings (acceptable at v1 scale per R-90)

## 8. Source-code grep gates (FR-005, FR-018, FR-019, Constitution V/VI/IX)

```powershell
# 8a. FR-019 — no commercial-map dependency in pubspec
Select-String -Pattern "google_maps|mapbox|apple_maps" -Path pubspec.yaml pubspec.lock
# Expected: zero matches

# 8b. FR-005 + Constitution III — no app-layer status='approved' or visibility filter
Get-ChildItem -Recurse -Filter *.dart lib/features/map | Select-String -Pattern "\.eq\('status', 'approved'\)|\.neq\('location_visibility'"
# Expected: zero matches

# 8c. Constitution IX-clean — no Supabase imports under domain/ or presentation/ of the map feature
Get-ChildItem -Recurse -Filter *.dart lib/features/map/domain | Select-String -Pattern "package:supabase_flutter|package:postgrest"
Get-ChildItem -Recurse -Filter *.dart lib/features/map/presentation | Select-String -Pattern "package:supabase_flutter|package:postgrest"
# Expected: zero matches each

# 8d. FR-016 — no inline string literals in map feature
Get-ChildItem -Recurse -Filter *.dart lib/features/map | Select-String -Pattern "Text\(['""][^a-z_]"
# Expected: zero matches (every Text widget reads from AppLocalizations)

# 8e. FR-018 — no hex literals / raw left-padding in map feature
Get-ChildItem -Recurse -Filter *.dart lib/features/map | Select-String -Pattern "Color\(0xFF|EdgeInsets\.only\(left"
# Expected: zero matches

# 8f. FR-015c — geolocation data does not leak to Supabase
Get-ChildItem -Recurse -Filter *.dart lib/features/map/data | Select-String -Pattern "latitude|longitude" | Where-Object { $_.Line -notmatch "marker_lat|marker_lng|MapMarkerDto|MarkerCoordinates" }
# Expected: zero matches
```

## 9. Build the app

```powershell
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter build apk --debug --dart-define-from-file=.env.json
# Expected: successful build; no compilation errors
```

> Memory check (`project_dart_defines.md`): every `flutter run` / `flutter build` MUST include `--dart-define-from-file=.env.json` or `Supabase.initialize` is skipped and the app red-screens.

## 10. Two-device UI walk — Infinix Note 8 (primary)

### 10a. Cold-launch on home; tap map tile (US1, SC-001, SC-007, SC-008, Q8=B)

```powershell
flutter run --release --dart-define-from-file=.env.json
# (After app launch:)
```

- App opens to home page (anonymous, no sign-in).
- Confirm map tile is visible above the "Latest listings" header without scrolling.
- Confirm tile shows the map icon, title ("تصفح على الخريطة"), and subtitle.
- Tap the tile. Stopwatch start.
- Expected: map page opens fitted to a Syria-wide bounding box; OpenStreetMap tiles render within ~3 seconds (stopwatch); marker pins appear within +~2 seconds.
- Confirm OpenStreetMap attribution credit is visible bottom-start.
- Confirm marker count roughly matches the SQL `count(*) FROM v_listings_map_public` from step 3.

### 10b. Marker tap → popover → details navigation (US2, SC-004, SC-005)

- Tap any visible marker. Stopwatch start.
- Expected: preview popover appears within ~500ms anchored to the marker, showing image + title + price + property-type badge.
- Tap the popover. Stopwatch.
- Expected: `/listings/:id` page renders within ~1 second showing the full Phase 13 `ListingDetailsPage`.
- Tap back. Confirm return to map at the same zoom and pan position; marker dataset NOT re-loaded (no flicker).

### 10c. Cluster behavior (US4, SC-006)

- Zoom out to Syria-wide view.
- Confirm Damascus area shows one or more cluster markers (with numeric count badges) rather than 30+ overlapping pins.
- Tap a cluster (not at max zoom). Confirm map auto-zooms in (re-centered on the cluster) and the cluster splits.
- Continue zooming in past the clustering threshold. Confirm individual markers appear.
- Zoom out. Confirm markers re-cluster.
- At max zoom (street-level), if two listings share identical coords (seed if needed), tap their cluster — confirm spiderfy expansion.

### 10d. Approximate marker visual indicator (FR-003a)

- Find a marker for a listing with `location_visibility = 'approximate'` (query SQL to identify).
- Confirm the marker pin is visually distinct from `exact` markers (larger / has a halo / dashed accent).
- Tap it. Confirm popover includes "Approximate location" localized label.

### 10e. Center on my location (US1 scenarios 5–7, SC-014, SC-015)

> **Fresh-install permission state**: Clear app data first (`adb shell pm clear app.alnujom.realestate`) to reset the permission grant.

- Open map. Tap the "center on my location" FAB.
- Expected: Android runtime permission prompt appears.
- Tap "Allow." Stopwatch.
- Expected: map pans + zooms to your current device location within ~3 seconds at neighborhood-level zoom.
- Tap the FAB again. Stopwatch.
- Expected: no prompt; map re-pans to current location within ~1 second.
- Clear app data again. Open map. Tap FAB. Tap "Deny."
- Expected: localized snackbar "Location access is unavailable." Map remains at Syria-wide overview. FAB still present (NOT hidden).
- Tap FAB again. Tap "Don't ask again" on the prompt.
- Expected: localized snackbar with "Open settings" action.
- Tap "Open settings." Confirm Android settings app opens at AlNujom permission screen.

### 10f. Listing details → "View on map" (US5, FR-007 entry point b)

- Navigate to a listing details page for an approved listing with `location_visibility = 'exact'`.
- Confirm "View on map" button appears below the location block.
- Tap it. Expected: map opens centered on the listing's marker; the marker is selected (popover open).
- Tap back. Expected: return to listing details page (NOT to home).
- Navigate to a listing with `location_visibility = 'hidden'` (admin path: change a listing's visibility via SQL).
- Confirm "View on map" button is NOT present in the tree.

### 10g. Search → "Show on map" with filter handoff (US6, SC-012, SC-013)

- Open search page. Apply at least two filters: e.g., property_type = apartment AND governorate = Damascus.
- Confirm "Show on map" button visible in `_SortAndFiltersRow`.
- Tap "Show on map." Stopwatch (for SC-013 alert appearance).
- Expected: map opens with markers restricted to apartment-for-sale-in-Damascus listings; filter-active alert dialog appears within ~500ms showing a chip-list summary + "Reset filters" + "Keep filters" actions.
- Tap "Reset filters." Stopwatch (for SC-012 reload).
- Expected: dialog dismisses, map reloads with the full unfiltered approved set within ~2 seconds.
- Repeat the flow, tapping "Keep filters" instead.
- Expected: dialog dismisses; map remains filtered; alert does NOT re-appear unless re-entering from a new filtered search.
- Press back from map. Expected: return to search page with filters intact.

### 10h. Empty / error states (Edge cases)

- (Optional) Seed a state with zero approved listings (set status='paused' on every approved row via SQL; revert after). Open map. Confirm localized empty-state hint near attribution credit.
- Apply impossibly-narrow filters via search (e.g., area_size = 99999, all other filters cleared). Tap "Show on map." Expected: zero markers + filter-active alert + zero-results hint.

### 10i. Admin visibility flip (SC-010)

- Note a visible exact marker on the map. Capture its listing id.
- Via SQL: `UPDATE public.listings SET location_visibility = 'hidden' WHERE id = '<id>';`
- Return to app. Tap the `MapRefreshButton`.
- Expected: marker disappears within ~2 seconds.

### 10j. 4-combination matrix (SC-007, SC-008, FR-017)

For each of (light, dark) × (ar, en):
- Toggle theme + locale in the profile/settings page.
- Reopen map. Confirm:
  - All chrome (back button, refresh button, popover, FAB, attribution, filter alert) renders correctly with no visual defects, no clipped text, no inverted direction.
  - Attribution is always visible.
  - In RTL, the back-arrow icon mirrors automatically (Material's Directionality).

## 11. Two-device UI walk — Pixel 8 Pro AVD (secondary)

> Memory check (`project_android_emulator_window_offscreen.md`): if the AVD window launches off-screen, apply the SetWindowPos recipe from `docs/dev/android-emulator-windows.md`.

Repeat steps 10a, 10c, 10g, 10j on the Pixel 8 Pro AVD (Android 14, 412 dp width). Differences expected:
- Geolocation may use the emulator's set location (Extended controls → Location).
- Performance is faster (no Syrian-4G simulation; behavior is the same).
- 412 dp width may differ slightly in tile sizing vs 480 dp Infinix.

## 12. Final SC matrix

| SC | Verified | Notes |
|----|----------|-------|
| SC-001 | ✅ Step 10a | Cold-launch map open within 3+2s on Infinix Note 8 |
| SC-002 | ✅ Step 4 + Step 10a | SQL verifies coord projection per visibility tier |
| SC-003 | ✅ Step 4 (4a, 4c) | Zero wire-level leaks for hidden/admin_only/approximate-true-coords |
| SC-004 | ✅ Step 10b | Marker tap → popover → nav stopwatch |
| SC-005 | ✅ Step 10b | Back from details restores camera, no marker re-flicker |
| SC-006 | ✅ Step 10c | Cluster at country zoom; split at city zoom |
| SC-007 | ✅ Step 10a + 10j | Attribution visible in all 4 combinations |
| SC-008 | ✅ Step 10j | All 4 combinations render correctly on Infinix |
| SC-009 | ✅ Step 8a | Zero matches for google_maps/mapbox |
| SC-010 | ✅ Step 10i | Admin SQL flip + refresh removes marker |
| SC-011 | ✅ Step 4e | Anonymous + authenticated identical counts |
| SC-012 | ✅ Step 10g | Filter handoff narrows; Reset reloads in 2s |
| SC-013 | ✅ Step 10g | Alert in 500ms when filtered; absent when not |
| SC-014 | ✅ Step 10e | First tap → prompt; grant → 3s pan; subsequent → 1s |
| SC-015 | ✅ Step 10e | Denial → snackbar 500ms; map remains functional |

If all 15 SCs are checked, Phase 15 is shippable. Run the auto-commit hook per the project git-workflow contract (memory `feedback_git_workflow.md`) and open a PR.
