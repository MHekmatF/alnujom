# Research Decisions: Phase 15 — Map View

**Branch**: `015-map-view` | **Date**: 2026-05-24 | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

This document records the 12 plan-time decisions (R-85 through R-96) that shape the Phase 15 implementation. Each decision lists the chosen answer, the rationale, the alternatives considered with rejection reasons, and the spec/plan sections that reference it.

---

## R-85 — Map provider package

**Decision**: `flutter_map: ^7.0.0` over OpenStreetMap raster tiles.

**Rationale**: Constitutional pre-lock (see CLAUDE.md §Locked decisions and the project IMPLEMENTATION_PLAN §2). No Google Maps SDK (sanctions risk for Syrian users + Google Cloud billing requirement + Play Services dependency). No Mapbox (paid token, sanctions risk). `flutter_map` is the mature open-source choice — actively maintained, OpenStreetMap-compatible out of the box, no API key required, no billing account, works from Syrian IPs.

**Version pin**: `^7.0.0`. The `flutter_map` 7.x line is the current stable (as of 2026-05) and includes the breaking-API cleanup that v6 introduced; pinning to `^7.0.0` allows minor + patch updates within the v7 line.

**Alternatives considered**:
- `google_maps_flutter` — rejected (constitutional sanctions block; requires Play Services and billing).
- `mapbox_maps_flutter` — rejected (constitutional sanctions block; requires paid token).
- `flutter_osm_plugin` — rejected (smaller community, older API surface, less consistent platform support; `flutter_map` is the de-facto standard for OSM in Flutter).

**Referenced from**: plan.md §Primary Dependencies, plan.md §Sub-Phase A scope, FR-019, SC-009.

---

## R-86 — Marker clustering package

**Decision**: `flutter_map_marker_cluster: ^1.4.0`.

**Rationale**: Direct companion to `flutter_map`. Provides `MarkerClusterLayerWidget` (drop-in replacement for `MarkerLayer`) with built-in cluster-on-zoom-out + split-on-zoom-in + spiderfy-at-max-zoom (the exact behaviors FR-013 and Q3 of the clarify pass require). No need to author custom clustering logic.

**Alternatives considered**:
- Hand-rolled clustering (compute clusters in `MapBloc`, render plain markers) — rejected (re-implements a well-solved problem; would take 2× the sub-phase work for less-tested behavior).
- `supercluster` (port of the Mapbox clustering algorithm) — rejected (extra dependency, no `flutter_map` integration adapter ships out of the box).

**Referenced from**: plan.md §Primary Dependencies, plan.md §Sub-Phase E scope item 4.

---

## R-87 — Jitter algorithm for `approximate` listings

**Decision**: Deterministic SHA-256 hash of `listing_id || salt`, mapped to a 2D offset of `±0.0045°` (~500m at Syrian latitudes) clamped to the listing's area bounding box. If the listing's stored `latitude`/`longitude` is null, the function falls back to the area's `centroid_lat`/`centroid_lng` and jitters from there.

**Rationale**:
- **Deterministic per listing** (per Q4 of /speckit-clarify, A=A): same listing returns same jittered coords on every fetch and for every user. Multi-fetch averaging by an attacker cannot triangulate the true centroid AND the marker stays stable across user re-visits.
- **SHA-256 hash** for distribution uniformity. `pgcrypto`'s `digest()` is already enabled in `00000000000000_init_extensions.sql` (Phase 1 / Phase 4); no new extension.
- **`±0.0045°` radius** is ~500m at Syrian latitudes (`1° lat ≈ 111km`, `1° lng ≈ 91km` at 35°N). Chosen as a balance between privacy (large enough that the true coordinate cannot be inferred from the jittered position) and spatial honesty (small enough that the marker is in the same neighborhood as the true position). FR-003 requires only that jittered coords fall within the area region; ±500m is well within any Syrian area's bounds.
- **Clamping to area bounds** ensures the marker doesn't fall outside the publisher's declared area (e.g., a listing in Damascus Mezzeh whose jitter would push it into the Old City is clamped back into Mezzeh). Implementation uses the `public.areas.centroid_lat/_lng` columns (Phase 10 R-12) as the area's anchor; in v1 we approximate the area's bounds as a `±0.02°` square around the centroid (the seed areas are roughly this size); a future spec can switch to true polygon clamping if PostGIS adoption (R-90) lands.
- **Null lat/lng fallback** is defensive: Phase 10 Q2=A guarantees lat/lng are non-null on submit (auto-populated from area centroid), but if a legacy or admin-injected row has null coordinates the jitter function falls back to the area centroid + jitters from there.

**Salt origin**: A 256-bit random hex string set via `ALTER DATABASE ... SET app.map_jitter_salt = '<hex>'`. See R-92 for storage decision.

**Alternatives considered**:
- Random offset per fetch — rejected (multi-fetch averaging exposes true centroid; marker jumps between sessions, confusing users).
- Deterministic per session (random across sessions) — rejected (still vulnerable to multi-session attack; marker still jumps for legitimate users).
- Snap to fixed grid (e.g., 100m grid centered on area centroid) — rejected (markers cluster on visible grid lines, visually unnatural).
- Use PostGIS `ST_AsText` + `ST_Translate` — rejected per R-90 (no PostGIS in Phase 15).

**Referenced from**: plan.md §Sub-Phase C scope item 1, FR-003, SC-002, SC-003, spec.md Assumptions.

---

## R-88 — Geolocation plugin choice

**Decision**: `geolocator: ^13.0.0` + `permission_handler: ^11.3.0`.

**Rationale**:
- **`geolocator` over `location`**: `geolocator` 13.x uses the native Android `LocationManager` API and does NOT require Google Play Services as a hard dependency. The `location` package, by contrast, has a Play Services soft dep that can fail on devices without current Play Services (common on Syrian Android devices distributed via direct-APK channels per Constitution §Critical Syria-specific notes). FR-019 requires Play-Services-free Android compatibility.
- **`permission_handler` for runtime permission**: Standard Flutter package for Android runtime permission prompts. `geolocator` exposes its own permission methods, but they delegate to the OS runtime layer — using `permission_handler` directly gives finer control over the "permanently denied" path (where we need to surface a settings-deep-link recovery option per FR-015b).
- **Version pins**: `geolocator: ^13.0.0` is current stable; `permission_handler: ^11.3.0` is current stable.

**Permission scope**: `Permission.locationWhenInUse` (Android: `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`). The map does NOT request `Permission.locationAlways` — there is no background-location use case in Phase 15.

**Alternatives considered**:
- `location: ^6.0.0` — rejected (Play Services soft dep risks failure on Syrian direct-APK devices).
- Native Android channel + custom Flutter wrapper — rejected (re-implements `geolocator`).
- Skip geolocation entirely in Phase 15 — rejected (Q3 of /speckit-clarify resolved that the "center on my location" affordance is in scope).

**Referenced from**: plan.md §Primary Dependencies, plan.md §Sub-Phase A scope, plan.md §Sub-Phase E scope item 6, FR-015b, FR-019, SC-014, SC-015.

---

## R-89 — Refresh affordance

**Decision**: Explicit `MapRefreshButton` (Material `IconButton` overlay), NOT pull-to-refresh.

**Rationale**: A pull-to-refresh gesture (the Phase 13 home pattern) conflicts with the map's pan gesture — a downward swipe at the top of the map could be interpreted as either "pan the map down" or "refresh." `flutter_map`'s `InteractiveFlag` controls would either disable pan in a top-edge zone (degrading map UX) or interpret all swipes as map pans (breaking refresh). An explicit button on the map chrome (top-end position) avoids the gesture conflict entirely and is the standard pattern in marketplace map UIs (Aqarmap, Bayut, Zillow all use a refresh icon button).

**Position**: Top-end (right in LTR, left in RTL) of the map overlay, beside the AppBar or anchored to the upper viewport edge. The exact pixel offset is a Phase 2 token consumption.

**Trigger**: Tap dispatches `MarkersRefreshRequested` to `MapBloc`. The bloc re-runs `LoadMapMarkers(filter: cachedFilter)` and replaces `MapLoaded.markers` on success.

**Alternatives considered**:
- Pull-to-refresh — rejected (gesture conflict).
- Auto-refresh on a timer (e.g., every 5 min) — rejected per Q4 of /speckit-clarify (matches Phase 13's no-auto-refresh decision).
- No refresh affordance at all — rejected (users have no way to see newly-approved listings without leaving and re-opening the map).

**Referenced from**: plan.md §Sub-Phase E scope item 8, FR-014a.

---

## R-90 — PostGIS adoption

**Decision**: Deferred. Phase 15 stays on plain `NUMERIC(9,6)` columns; no PostGIS extension is enabled.

**Rationale**: PostGIS adds: (a) an extension dependency (must be enabled in `init_extensions.sql`; Supabase supports it but it adds backup size and migration complexity); (b) a new column type (`geometry` or `geography`) that would require ALTERing existing tables; (c) operational complexity (spatial indexes, SRID management, vector-vs-raster choices). At Phase 15's v1 scale (hundreds to low thousands of approved listings), a plain `SELECT marker_lat, marker_lng FROM v_listings_map_public` returns the full dataset in one round-trip with no spatial query needed — the client-side `flutter_map_marker_cluster` handles render performance. PostGIS becomes relevant only when (i) the catalog scales past ~10k listings AND (ii) viewport-bound querying becomes necessary (per FR-001a's "future spec extends to bbox/pagination" forward statement). Neither condition holds in v1.

**Spatial query needs absent in Phase 15**:
- No bbox queries (FR-001a — return full country in one fetch).
- No "find nearest" queries (FR-007 has no "show 10 nearest to me" mode).
- No polygon-membership queries beyond the area-bounds clamp in the jitter function — and that clamp uses a simple `BETWEEN` predicate on `centroid_lat ± 0.02° AND centroid_lng ± 0.02°` (a rectangle, not a polygon).

**Alternatives considered**:
- Enable PostGIS in `init_extensions.sql` migration — rejected (over-engineering for v1; adds migration / backup cost).
- Use `cube` or `earthdistance` Postgres extensions — rejected (same over-engineering, no v1 use case).

**Forward-stated**: A future spec MAY enable PostGIS when (a) viewport-bound dataset filtering becomes necessary or (b) the catalog passes ~10k approved listings. The migration would: enable the extension, ALTER `public.listings` to add a `geom GEOGRAPHY(Point, 4326)` column populated from `(longitude, latitude)`, add a `gist(geom)` index, and convert `v_listings_map_public` to use spatial predicates.

**Referenced from**: plan.md §Storage, plan.md §Sub-Phase C scope, FR-001a, spec.md Assumptions.

---

## R-91 — Home tile insertion slot

**Decision**: Insert `MapEntryTile` `SliverToBoxAdapter` between Phase 13's `PropertyTypeShortcutRow` sliver and the "Latest listings" header sliver in `home_page.dart`.

**Rationale** (per Q8=B of /speckit-clarify which resolved the home entry shape to "prominent tile near hero search bar, NOT bottom-nav, NOT app-bar icon"):
- The hero search bar is sliver 1 (Phase 14 wires it).
- `PropertyTypeShortcutRow` is sliver 2 (Phase 13 ships it).
- A `MapEntryTile` sliver inserted at position 3 sits "near the hero search bar" (above-the-fold on Infinix Note 8 portrait without scrolling) per Q8=B.
- The "Latest listings" header is sliver 4; the feed slivers follow.

**Tile composition**: `Card`-styled tappable widget. Leading: `Icons.map` (or a custom map icon). Title: `l10n.home_map_tile_title` (e.g., "تصفح على الخريطة" / "Browse on map"). Subtitle: `l10n.home_map_tile_subtitle` (e.g., "اعرض العقارات الموافق عليها على الخريطة" / "View approved listings on the map"). Trailing: `Icons.arrow_forward_ios` (or directionally-aware variant for RTL). `onTap`: `context.go(AppRoutes.map, extra: const MapEntryFromHome())`.

**Token consumption**: `AppSpacing.lg` for outer padding, `AppRadii.md` for card corners, `Theme.of(context).colorScheme.surfaceVariant` for the card surface — same token surface other home cards use.

**Alternatives considered**:
- Insert at position 4 (after "Latest listings" header, before feed) — rejected (visually breaks the header→feed connection).
- Insert at position 1 (before hero search bar) — rejected (the hero search bar is the primary discovery surface; map is a peer discovery surface but search is more general).
- Replace the `PropertyTypeShortcutRow` with map + chip row combined — rejected (over-couples two unrelated features; chip row is Phase 13's contract).

**Referenced from**: plan.md §Sub-Phase G scope item 1, FR-007.

---

## R-92 — Salt storage for jitter function

**Decision**: Set via `ALTER DATABASE postgres SET app.map_jitter_salt = '<256-bit-hex>'` in a one-time setup step. The function reads `current_setting('app.map_jitter_salt')` at call time. Rotation is a documented manual procedure (re-set the GUC, re-run `REFRESH MATERIALIZED VIEW` if any materialized view depends on jittered coords — none in v1).

**Rationale**:
- **Simpler than Vault**: Vault (ADR-0001) is the canonical store for backend secrets, but the jitter salt's threat model is narrow — it protects against multi-fetch averaging by an attacker who has the live wire-level data. A leaked salt does NOT directly expose any publisher's coordinates (it would let an attacker reproduce the deterministic offsets, but they still need to know the original coords AND the listing IDs). The salt is closer to a "constant" than a "secret"; storing it in a Postgres GUC is sufficient for v1.
- **Simpler than `app_settings`**: The `public.app_settings` table is forward-stated to Phase 23 — using it pre-Phase-23 would require landing a separate migration. The GUC approach needs only the `ALTER DATABASE` statement.
- **Simpler than hardcoded literal**: Hardcoding the salt in the migration file would commit it to git, making rotation a code change. The GUC approach keeps the salt out of source.

**Setup procedure** (documented in `data-model.md`): During Phase 15 deployment, an admin runs `openssl rand -hex 32` → captures the result → runs `ALTER DATABASE postgres SET app.map_jitter_salt = '<hex>';` against the Supabase project's Postgres. The setting persists across restarts. Verification: `SELECT current_setting('app.map_jitter_salt');` returns the hex value.

**Rotation procedure**: Re-run `openssl rand -hex 32` → re-run `ALTER DATABASE` with the new value. Every approximate listing's marker moves to a new jittered position; this is acceptable per FR-003 ("the marker was always approximate"). No data migration is required.

**Alternatives considered**:
- Vault secret — rejected (overhead for a narrow-threat constant; can migrate to Vault in a future spec if threat model changes).
- `public.app_settings` row — rejected (table doesn't exist yet; Phase 23 owns it).
- Hardcoded literal in the migration — rejected (git-committed salt; rotation is a code change).

**Referenced from**: plan.md §Sub-Phase C scope item 1, R-87.

---

## R-93 — Marker cluster threshold

**Decision**: `flutter_map_marker_cluster` `MarkerClusterLayerOptions` config:
- `maxClusterRadius: 80` pixels (default).
- `spiderfyClusterMaxZoom`: set to the map's max zoom (so spiderfy only fires when zoom-in cannot further split the cluster, per FR-013 conditional rule).
- `zoomToBoundsOnClick: true` (when below max zoom, tap zooms to fit the cluster's bounding box — this is the auto-zoom branch of FR-013).
- `disableClusteringAtZoom`: not set (all zoom levels cluster overlapping markers).

**Rationale**: The `flutter_map_marker_cluster` defaults closely match FR-013's conditional rule. The `spiderfyClusterMaxZoom` is the only override needed — by default the package may spiderfy at lower zoom levels, but FR-013 requires auto-zoom at non-max zoom and spiderfy only at max zoom. Setting `spiderfyClusterMaxZoom` equal to the map's `MapOptions.maxZoom` (typically 18 for OSM tiles) achieves this.

**Alternatives considered**:
- Always spiderfy (set `spiderfyClusterMaxZoom: 18` AND `zoomToBoundsOnClick: false`) — rejected (FR-013 requires auto-zoom at non-max zoom).
- Always auto-zoom (set `zoomToBoundsOnClick: true` AND `spiderfyClusterMaxZoom: 1`) — rejected (FR-013 requires spiderfy at max zoom).
- Tune `maxClusterRadius` lower (e.g., 50px) for tighter clusters — deferred (default 80 is fine for v1; if user testing shows excessive clustering, a follow-up tweak is trivial).

**Referenced from**: plan.md §Sub-Phase E scope item 4, FR-013, US4.

---

## R-94 — OSM tile URL

**Decision**: `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (OpenStreetMap Foundation's public tile servers).

**Rationale**: The OSMF public tile servers are free for non-commercial use within the OSMF tile usage policy (https://operations.osmfoundation.org/policies/tiles/). Phase 15's v1 scale (a Syrian-market app with low-thousands of users in early deployment) is well within policy. Attribution to OpenStreetMap is required and rendered via `OsmAttributionWidget` per FR-008 / SC-007.

**`User-Agent` header**: `flutter_map` sets a default `User-Agent` for tile requests. Per OSMF policy, this SHOULD identify the app — Sub-Phase A will configure `flutter_map`'s `userAgentPackageName` to `'app.alnujom.realestate'` (or whichever package name the project's `pubspec.yaml` resolves to). This is a one-line config; documented in `contracts/phase15-map-page-composition.md`.

**Tile zoom range**: `minZoom: 6` (Syria-wide overview), `maxZoom: 18` (street-level detail) — `flutter_map` defaults for OSM tile compatibility.

**Alternatives considered**:
- Self-hosted OSM tile mirror — deferred (not needed at v1 scale; documented as future spec in spec.md Assumptions).
- Paid OSM-licensed tile provider (e.g., MapTiler in their OSM-compatible mode) — rejected (paid; v1 budget is zero for tiles).
- Mapbox OSM-styled tiles — rejected (Mapbox is a commercial-map provider; constitutional sanctions block).

**Referenced from**: plan.md §Sub-Phase E scope item 4, FR-008, FR-019, spec.md Assumptions.

---

## R-95 — `MapEntryContext` location in the source tree

**Decision**: `lib/features/map/domain/entities/map_entry_context.dart` — defined as part of Sub-Phase A (the bootstrap).

**Rationale**: `MapEntryContext` is a navigation envelope consumed by:
- Sub-Phase G entry-point widgets (constructing instances of `MapEntryFromHome`, `MapEntryFromListing`, `MapEntryFromSearch`).
- Sub-Phase E's `MapBloc` (pattern-matching on the sealed-class cases in `MapOpened` handler).

Defining it in Sub-Phase A (the bootstrap) unblocks both E and G in the dependency graph — without it, E and G would both need Sub-Phase D to land first (since Sub-Phase D defines the rest of `domain/entities/`). Putting `MapEntryContext` in A lets G ship in Wave 2 (parallel with D) instead of Wave 3.

**Constitution IX-clean**: The file imports `package:alnujom/features/search/domain/entities/filter_state.dart` (Phase 14, also a domain entity — pure Dart, no Supabase types) and `package:equatable/equatable.dart`. No `package:supabase_flutter` imports.

**Alternatives considered**:
- Put it in Sub-Phase D (with the rest of `domain/entities/`) — rejected (forces G to Wave 3 instead of Wave 2; halves G's parallelism with no benefit).
- Put it in Sub-Phase E (presentation) — rejected (a navigation envelope is a domain concept, not a presentation concept; presentation widgets shouldn't define the navigation contract).
- Put it in `lib/core/routing/` — rejected (`MapEntryContext` is map-feature-specific; cluttering `core/routing/` with feature-specific types is anti-pattern).

**Referenced from**: plan.md §Sub-Phase A scope item 5, plan.md §Sub-Phase D, plan.md §Sub-Phase E, plan.md §Sub-Phase G.

---

## R-96 — `DeepLinkAwareBackButton` extraction trigger

**Decision**: Phase 15 IS the third consumer of the Phase 13 R-71 pattern → extraction lands in Sub-Phase B per Phase 14 DEFERRED.md §D-001 trigger condition.

**Rationale**: The Phase 13 R-71 contract reads "extract to `lib/core/widgets/deep_link_aware_back_button.dart` when the SECOND consumer arrives." Phase 14 became the second consumer (the `SearchPage` AppBar `leading`) but elected to inline the pattern again rather than extract — the extraction was deferred via Phase 14 DEFERRED.md §D-001 with the trigger condition "extract when the third consumer arrives." Phase 15's `MapPage` is unambiguously the third consumer (a new full-screen page that's deep-linkable via `/map` and needs the same conditional back-button behavior). Extracting now is the natural realization.

**Refactor scope**: Sub-Phase B (a Wave 1 sub-phase) replaces the inline pattern in both `listing_details_page.dart` and `search_page.dart` with the new shared widget. The behavior is identical; only the call site is consolidated. No spec changes to Phase 13 or Phase 14.

**Future consumers**: Any future page that's deep-linkable AND needs a back button (Phase 22 push-notification deep-link targets are the most likely next case) uses `DeepLinkAwareBackButton` directly from the start — no further extraction needed.

**Alternatives considered**:
- Defer extraction to Phase 22 (the fourth consumer) — rejected (Phase 15 IS the trigger condition per DEFERRED.md; defering further would violate the documented contract).
- Don't extract; inline the pattern a third time in `MapPage` — rejected (would necessitate a Phase 22 cleanup PR to extract from four call sites; deferring the cleanup makes it bigger).
- Extract to `lib/features/map/` (feature-local) — rejected (the widget is cross-feature; belongs in `lib/core/widgets/`).

**Referenced from**: plan.md §Sub-Phase B scope, plan.md §Sub-Phase E scope item 4, FR-015.
