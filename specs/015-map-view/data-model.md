# Data Model: Phase 15 — Map View

**Branch**: `015-map-view` | **Date**: 2026-05-24 | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

This document captures the full backend artifact bodies (jitter function, view, RPC) and the Flutter domain entity definitions that Phase 15 introduces. It closes with a per-FR / per-SC verification map.

---

## 1. SQL migration — `map_jitter_coordinates` function

**File**: `supabase/migrations/20260526120001_create_map_jitter_function.sql`

```sql
-- Phase 15 R-87 + R-92: Deterministic per-listing coordinate jitter for
-- listings whose location_visibility = 'approximate'.
--
-- Strategy:
--   1. Hash listing_id concatenated with the GUC-stored salt via SHA-256.
--   2. Extract two 4-byte windows from the hash → two unsigned 32-bit ints.
--   3. Normalize each to [-1, +1] then scale by 0.0045° (~500m at Syrian
--      latitudes) to produce a deterministic (lat_offset, lng_offset) pair.
--   4. Add the offset to the listing's stored (lat, lng); if those are null,
--      fall back to the listing's area's centroid (Phase 10 R-12).
--   5. Clamp the result to a ±0.02° rectangle around the area's centroid
--      so the marker stays within the publisher's declared area.
--
-- The salt is set OUT OF BAND via:
--   ALTER DATABASE postgres SET app.map_jitter_salt = '<256-bit-hex>';
-- See supabase/docs/map_jitter_coordinates.md for setup + rotation procedure.

CREATE OR REPLACE FUNCTION public.map_jitter_coordinates(
  p_listing_id   uuid,
  p_area_id      uuid,
  p_original_lat numeric,
  p_original_lng numeric
)
RETURNS TABLE(jittered_lat numeric, jittered_lng numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salt           text;
  v_hash           bytea;
  v_byte_lat       integer;
  v_byte_lng       integer;
  v_offset_lat     numeric;
  v_offset_lng     numeric;
  v_anchor_lat     numeric;
  v_anchor_lng     numeric;
  v_centroid_lat   numeric;
  v_centroid_lng   numeric;
  v_jitter_radius  CONSTANT numeric := 0.0045;  -- ~500m at Syrian latitudes
  v_clamp_radius   CONSTANT numeric := 0.02;    -- ~2.2km — area-bounds clamp
BEGIN
  -- Read the salt from the database-scoped GUC.
  -- If unset, raise (deployment misconfiguration).
  v_salt := current_setting('app.map_jitter_salt', true);
  IF v_salt IS NULL OR v_salt = '' THEN
    RAISE EXCEPTION 'app.map_jitter_salt is not set; Phase 15 setup incomplete';
  END IF;

  -- Look up the area centroid (Phase 10 R-12 — guaranteed non-null + bounds-checked).
  SELECT centroid_lat, centroid_lng
    INTO v_centroid_lat, v_centroid_lng
  FROM public.areas
  WHERE id = p_area_id;
  IF v_centroid_lat IS NULL OR v_centroid_lng IS NULL THEN
    RAISE EXCEPTION 'area % missing centroid; cannot jitter', p_area_id;
  END IF;

  -- Anchor: use the listing's stored coords if non-null, else the area centroid.
  v_anchor_lat := COALESCE(p_original_lat, v_centroid_lat);
  v_anchor_lng := COALESCE(p_original_lng, v_centroid_lng);

  -- Deterministic offset derivation.
  v_hash := digest(p_listing_id::text || v_salt, 'sha256');
  -- Bytes 0–3 → lat offset signed; bytes 4–7 → lng offset signed.
  v_byte_lat := get_byte(v_hash, 0) * 256 + get_byte(v_hash, 1)
              + get_byte(v_hash, 2) * 65536 + get_byte(v_hash, 3) * 16777216;
  v_byte_lng := get_byte(v_hash, 4) * 256 + get_byte(v_hash, 5)
              + get_byte(v_hash, 6) * 65536 + get_byte(v_hash, 7) * 16777216;

  -- Normalize to [-1, +1] then scale to jitter radius.
  v_offset_lat := ((v_byte_lat::numeric / 2147483647.0) - 1.0) * v_jitter_radius;
  v_offset_lng := ((v_byte_lng::numeric / 2147483647.0) - 1.0) * v_jitter_radius;

  jittered_lat := v_anchor_lat + v_offset_lat;
  jittered_lng := v_anchor_lng + v_offset_lng;

  -- Clamp to ±v_clamp_radius around the area centroid.
  jittered_lat := GREATEST(v_centroid_lat - v_clamp_radius,
                  LEAST(v_centroid_lat + v_clamp_radius, jittered_lat));
  jittered_lng := GREATEST(v_centroid_lng - v_clamp_radius,
                  LEAST(v_centroid_lng + v_clamp_radius, jittered_lng));

  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) TO authenticated, anon;

COMMENT ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) IS
  'Phase 15 R-87: deterministic per-listing coordinate jitter for approximate listings. '
  'Reads salt from app.map_jitter_salt GUC. Anchored on listing coords with area-centroid fallback. '
  'Clamped to ±0.02° around area centroid. Result is stable across fetches for a given (listing_id, salt) pair.';
```

**Idempotency**: The migration uses `CREATE OR REPLACE FUNCTION` so re-applying it overwrites the function body. The `REVOKE` + `GRANT` statements are also idempotent (revoking from PUBLIC then granting to specific roles is safe to re-run).

**Salt setup** (one-time, captured in `supabase/docs/map_jitter_coordinates.md`):

```bash
# Generate a 256-bit hex salt
SALT=$(openssl rand -hex 32)

# Set the GUC at database scope (persists across restarts)
psql "$SUPABASE_DB_URL" -c "ALTER DATABASE postgres SET app.map_jitter_salt = '$SALT';"

# Verify
psql "$SUPABASE_DB_URL" -c "SELECT current_setting('app.map_jitter_salt');"
# Expected output: the hex string set above
```

---

## 2. SQL migration — `v_listings_map_public` view

**File**: `supabase/migrations/20260526120002_create_v_listings_map_public.sql`

```sql
-- Phase 15 FR-001 + FR-002 + FR-003 + FR-004: public map dataset projection.
--
-- WHERE gates:
--   - l.status = 'approved' (Phase 12 approval gate)
--   - l.location_visibility IN ('exact', 'approximate') (FR-002)
--   - (l.expires_at IS NULL OR l.expires_at > now()) (publish-window)
--
-- Coordinate projection:
--   - exact      → (l.latitude, l.longitude) verbatim (FR-004)
--   - approximate→ map_jitter_coordinates(...) (FR-003 — deterministic per-listing)
--
-- Field set:
--   id, title, marker_lat, marker_lng, is_approximate, location_visibility,
--   primary_amount, primary_currency, main_image_path, property_type, purpose,
--   governorate_name_ar, governorate_name_en.
--   (NO publisher contact details, NO description, NO full address — minimal
--    surface per FR-001 + ADR-0001 publisher-PII discipline.)
--
-- RLS posture:
--   The view inherits RLS from the underlying public.listings table. The base
--   table's RLS policy for SELECT permits anon/authenticated reads when
--   l.status = 'approved' AND the publish-window predicate holds — which the
--   view's WHERE clause re-enforces, so the path is consistent.
--   We GRANT SELECT explicitly to authenticated + anon to make the public
--   read intent explicit at the view layer.

CREATE OR REPLACE VIEW public.v_listings_map_public AS
SELECT
  l.id,
  l.title,
  -- Marker coordinates: jitter for approximate, passthrough for exact.
  CASE l.location_visibility
    WHEN 'exact' THEN l.latitude
    WHEN 'approximate' THEN (jitter.jittered_lat)
  END AS marker_lat,
  CASE l.location_visibility
    WHEN 'exact' THEN l.longitude
    WHEN 'approximate' THEN (jitter.jittered_lng)
  END AS marker_lng,
  (l.location_visibility = 'approximate') AS is_approximate,
  l.location_visibility,
  -- Primary price (is_primary = true row) — reused from v_listings_public pattern.
  lp.amount        AS primary_amount,
  lp.currency_code AS primary_currency,
  -- Main image (lowest ordering value among image-kind rows).
  lm.storage_path  AS main_image_path,
  -- Property classification.
  l.property_type,
  l.purpose,
  -- Bilingual governorate names (only governorate-level for the popover; city
  -- omitted to keep the surface minimal — the popover doesn't show full
  -- address per FR-001 minimal-projection rule).
  g.display_name->>'ar' AS governorate_name_ar,
  g.display_name->>'en' AS governorate_name_en
FROM public.listings l
LEFT JOIN LATERAL public.map_jitter_coordinates(
  l.id, l.area_id, l.latitude, l.longitude
) jitter ON l.location_visibility = 'approximate'
LEFT JOIN LATERAL (
  SELECT amount, currency_code
  FROM public.listing_prices
  WHERE listing_id = l.id
    AND is_primary = true
  LIMIT 1
) lp ON true
LEFT JOIN LATERAL (
  SELECT storage_path
  FROM public.listing_media
  WHERE listing_id = l.id
    AND kind = 'image'
  ORDER BY ordering ASC
  LIMIT 1
) lm ON true
LEFT JOIN public.governorates g ON g.id = l.governorate_id
WHERE l.status = 'approved'
  AND l.location_visibility IN ('exact', 'approximate')
  AND (l.expires_at IS NULL OR l.expires_at > now());

GRANT SELECT ON public.v_listings_map_public TO authenticated, anon;

COMMENT ON VIEW public.v_listings_map_public IS
  'Phase 15 FR-001+FR-002+FR-003+FR-004: public map dataset. Returns one row per '
  'approved listing whose location_visibility is exact or approximate. For approximate '
  'listings, coordinates are jittered server-side via map_jitter_coordinates() — the '
  'publisher''s true coords never appear in the wire response. Hidden and admin_only '
  'listings are absent from this view.';
```

**Wire-level verification query** (captured in `quickstart.md`):

```sql
-- Confirm hidden and admin_only listings are absent
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility IN ('hidden', 'admin_only');
-- Expected: 0

-- Confirm approximate listings have jittered (not true) coordinates
SELECT l.id, l.latitude AS true_lat, v.marker_lat AS jittered_lat,
       l.longitude AS true_lng, v.marker_lng AS jittered_lng,
       (l.latitude = v.marker_lat AND l.longitude = v.marker_lng) AS leaked
FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility = 'approximate';
-- Expected: every row has leaked = false

-- Confirm exact listings have passthrough coordinates
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility = 'exact'
    AND (l.latitude != v.marker_lat OR l.longitude != v.marker_lng);
-- Expected: 0
```

---

## 3. SQL migration — `search_map` RPC

**File**: `supabase/migrations/20260526120003_create_search_map_rpc.sql`

```sql
-- Phase 15 FR-007a: filter-shape-compatible RPC for the search→map handoff.
-- Mirrors the parameter shape of Phase 14's search_listings RPC, minus
-- sort/cursor/limit (the map dataset is one-shot per FR-001a).

CREATE OR REPLACE FUNCTION public.search_map(
  -- Full-text keyword (null = no keyword filter)
  p_query              text       DEFAULT NULL,
  -- Facet filters (null = dimension inactive)
  p_purpose            text       DEFAULT NULL,
  p_property_type      text       DEFAULT NULL,
  p_governorate_id     uuid       DEFAULT NULL,
  p_city_id            uuid       DEFAULT NULL,
  p_area_id            uuid       DEFAULT NULL,
  -- Price range — pre-converted to USD and SYP by client (consistent with R-75)
  p_price_min_usd      numeric    DEFAULT NULL,
  p_price_max_usd      numeric    DEFAULT NULL,
  p_price_min_syp      numeric    DEFAULT NULL,
  p_price_max_syp      numeric    DEFAULT NULL,
  -- Rooms filter
  p_rooms              integer    DEFAULT NULL,
  p_rooms_mode         text       DEFAULT 'exactly',
  -- Bathrooms filter
  p_bathrooms          integer    DEFAULT NULL,
  p_bathrooms_mode     text       DEFAULT 'exactly',
  -- Area size range
  p_area_size_min      numeric    DEFAULT NULL,
  p_area_size_max      numeric    DEFAULT NULL
)
RETURNS SETOF public.v_listings_map_public
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT v.*
  FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  LEFT JOIN public.listing_details ld ON ld.listing_id = l.id
  LEFT JOIN public.listing_prices lp_usd
    ON lp_usd.listing_id = l.id AND lp_usd.currency_code = 'USD'
  LEFT JOIN public.listing_prices lp_syp
    ON lp_syp.listing_id = l.id AND lp_syp.currency_code = 'SYP'
  WHERE
    -- Keyword (Phase 14 tsvector + ILIKE supplement pattern; null = no filter)
    (p_query IS NULL OR p_query = ''
     OR l.search_vector @@ plainto_tsquery('simple', p_query)
     OR ld.description ILIKE '%' || p_query || '%')
    -- Facets
    AND (p_purpose IS NULL OR l.purpose = p_purpose)
    AND (p_property_type IS NULL OR l.property_type = p_property_type)
    AND (p_governorate_id IS NULL OR l.governorate_id = p_governorate_id)
    AND (p_city_id IS NULL OR l.city_id = p_city_id)
    AND (p_area_id IS NULL OR l.area_id = p_area_id)
    -- Price range — match if EITHER USD or SYP row falls within bounds
    AND (
      (p_price_min_usd IS NULL AND p_price_max_usd IS NULL
       AND p_price_min_syp IS NULL AND p_price_max_syp IS NULL)
      OR (lp_usd.amount IS NOT NULL
          AND (p_price_min_usd IS NULL OR lp_usd.amount >= p_price_min_usd)
          AND (p_price_max_usd IS NULL OR lp_usd.amount <= p_price_max_usd))
      OR (lp_syp.amount IS NOT NULL
          AND (p_price_min_syp IS NULL OR lp_syp.amount >= p_price_min_syp)
          AND (p_price_max_syp IS NULL OR lp_syp.amount <= p_price_max_syp))
    )
    -- Rooms (exactly / at_least)
    AND (
      p_rooms IS NULL
      OR (p_rooms_mode = 'exactly'  AND ld.rooms = p_rooms)
      OR (p_rooms_mode = 'at_least' AND ld.rooms >= p_rooms)
    )
    -- Bathrooms (exactly / at_least)
    AND (
      p_bathrooms IS NULL
      OR (p_bathrooms_mode = 'exactly'  AND ld.bathrooms = p_bathrooms)
      OR (p_bathrooms_mode = 'at_least' AND ld.bathrooms >= p_bathrooms)
    )
    -- Area size range
    AND (p_area_size_min IS NULL OR ld.area_size >= p_area_size_min)
    AND (p_area_size_max IS NULL OR ld.area_size <= p_area_size_max);
$$;

REVOKE ALL ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text, numeric, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text, numeric, numeric
) TO authenticated, anon;

COMMENT ON FUNCTION public.search_map IS
  'Phase 15 FR-007a: filter-shape-compatible RPC for the search→map handoff. '
  'Mirrors search_listings parameter shape minus sort/cursor/limit (map dataset is one-shot).';
```

**RPC behavior**:
- All-null parameters → returns the full `v_listings_map_public` dataset (identical to a direct `SELECT *`).
- Per-parameter null → that dimension is inactive (no narrowing).
- The view's WHERE gates (status='approved', visibility tier, publish window) compose with the RPC's filter gates — both must pass for a row to appear.

---

## 4. Dart domain entities

### 4.1 `MarkerCoordinates` value object

**File**: `lib/features/map/domain/entities/marker_coordinates.dart`

```dart
import 'package:equatable/equatable.dart';

/// A geographic coordinate pair. Domain-pure (no flutter_map / latlong2 import).
/// The data layer maps to/from package:latlong2's LatLng at the data-source
/// boundary.
class MarkerCoordinates extends Equatable {
  const MarkerCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object> get props => [latitude, longitude];
}
```

### 4.2 `MapMarker` entity

**File**: `lib/features/map/domain/entities/map_marker.dart`

```dart
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart'
    show PropertyType, ListingPurpose;
import 'marker_coordinates.dart';

/// A single map marker. Phase 15 FR-001 minimal-projection: only the fields the
/// map and its preview popover render. No publisher contact details, no
/// description, no full media gallery, no address.
class MapMarker extends Equatable {
  const MapMarker({
    required this.id,
    required this.position,
    required this.title,
    required this.primaryAmount,
    required this.primaryCurrencyCode,
    required this.mainImagePath,
    required this.propertyType,
    required this.purpose,
    required this.isApproximate,
    required this.governorateNameAr,
    required this.governorateNameEn,
  });

  final String id;
  final MarkerCoordinates position;
  final String title;
  final Decimal primaryAmount;
  final String primaryCurrencyCode;
  final String? mainImagePath;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final bool isApproximate;
  final String governorateNameAr;
  final String governorateNameEn;

  @override
  List<Object?> get props => [
        id, position, title, primaryAmount, primaryCurrencyCode,
        mainImagePath, propertyType, purpose, isApproximate,
        governorateNameAr, governorateNameEn,
      ];
}
```

### 4.3 `MapEntryContext` sealed class

**File**: `lib/features/map/domain/entities/map_entry_context.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../../search/domain/entities/filter_state.dart';
import 'marker_coordinates.dart';

/// The navigation envelope passed to MapPage via go_router state.extra.
/// Sub-Phase A creates this; Sub-Phase E (MapBloc) and Sub-Phase G (entry-point
/// widgets) consume it.
sealed class MapEntryContext extends Equatable {
  const MapEntryContext();
}

/// Entered from the home shell's map tile. No payload.
final class MapEntryFromHome extends MapEntryContext {
  const MapEntryFromHome();
  @override
  List<Object?> get props => const [];
}

/// Entered from a listing details page's "View on map" affordance.
/// Carries the listing id (for marker pre-selection) and the listing's
/// coordinates (for camera centering).
final class MapEntryFromListing extends MapEntryContext {
  const MapEntryFromListing({
    required this.listingId,
    required this.position,
  });
  final String listingId;
  final MarkerCoordinates position;
  @override
  List<Object?> get props => [listingId, position];
}

/// Entered from the Phase 14 search results "Show on map" affordance.
/// Carries the active FilterState; the map honors the filters and shows the
/// FilterActiveAlertDialog when showFilterAlert is true.
final class MapEntryFromSearch extends MapEntryContext {
  const MapEntryFromSearch({
    required this.filterState,
    required this.showFilterAlert,
  });
  final FilterState filterState;
  final bool showFilterAlert;
  @override
  List<Object?> get props => [filterState, showFilterAlert];
}
```

### 4.4 `MapRepository` interface

**File**: `lib/features/map/domain/repositories/map_repository.dart`

```dart
import '../../../search/domain/entities/filter_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/map_marker.dart';

/// Phase 15 — abstract domain interface for loading the public map dataset.
/// Concrete impl in lib/features/map/data/repositories/map_repository_impl.dart.
abstract class MapRepository {
  /// Load every approved+visible marker. When [filter] is null, calls the bare
  /// v_listings_map_public view; when non-null, calls the search_map RPC with
  /// the filter parameters.
  Future<Result<List<MapMarker>, Failure>> loadMarkers({FilterState? filter});
}
```

### 4.5 `LoadMapMarkers` use case

**File**: `lib/features/map/domain/usecases/load_map_markers.dart`

```dart
import 'package:injectable/injectable.dart';

import '../../../search/domain/entities/filter_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/map_marker.dart';
import '../repositories/map_repository.dart';

@injectable
class LoadMapMarkers {
  const LoadMapMarkers(this._repository);
  final MapRepository _repository;

  Future<Result<List<MapMarker>, Failure>> call({FilterState? filter}) =>
      _repository.loadMarkers(filter: filter);
}
```

---

## 5. Dart data layer (DTO + datasource + repository impl)

### 5.1 `MapMarkerDto`

**File**: `lib/features/map/data/models/map_marker_dto.dart`

```dart
import 'package:decimal/decimal.dart';

import '../../domain/entities/map_marker.dart';
import '../../domain/entities/marker_coordinates.dart';
import '../../../listing_form/domain/entities/listing.dart'
    show PropertyType, ListingPurpose;

/// Mirrors the v_listings_map_public row shape.
class MapMarkerDto {
  MapMarkerDto({
    required this.id,
    required this.title,
    required this.markerLat,
    required this.markerLng,
    required this.isApproximate,
    required this.primaryAmount,
    required this.primaryCurrency,
    required this.mainImagePath,
    required this.propertyType,
    required this.purpose,
    required this.governorateNameAr,
    required this.governorateNameEn,
  });

  factory MapMarkerDto.fromJson(Map<String, dynamic> json) => MapMarkerDto(
        id: json['id'] as String,
        title: json['title'] as String,
        markerLat: (json['marker_lat'] as num).toDouble(),
        markerLng: (json['marker_lng'] as num).toDouble(),
        isApproximate: json['is_approximate'] as bool,
        primaryAmount: Decimal.parse(json['primary_amount'].toString()),
        primaryCurrency: json['primary_currency'] as String,
        mainImagePath: json['main_image_path'] as String?,
        propertyType: PropertyType.values
            .firstWhere((e) => e.name == json['property_type']),
        purpose: ListingPurpose.values
            .firstWhere((e) => e.name == json['purpose']),
        governorateNameAr: json['governorate_name_ar'] as String,
        governorateNameEn: json['governorate_name_en'] as String,
      );

  final String id;
  final String title;
  final double markerLat;
  final double markerLng;
  final bool isApproximate;
  final Decimal primaryAmount;
  final String primaryCurrency;
  final String? mainImagePath;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final String governorateNameAr;
  final String governorateNameEn;

  MapMarker toEntity() => MapMarker(
        id: id,
        position: MarkerCoordinates(latitude: markerLat, longitude: markerLng),
        title: title,
        primaryAmount: primaryAmount,
        primaryCurrencyCode: primaryCurrency,
        mainImagePath: mainImagePath,
        propertyType: propertyType,
        purpose: purpose,
        isApproximate: isApproximate,
        governorateNameAr: governorateNameAr,
        governorateNameEn: governorateNameEn,
      );
}
```

### 5.2 `SupabaseMapDatasource` (sketch)

**File**: `lib/features/map/data/datasources/supabase_map_datasource.dart`

```dart
import 'package:injectable/injectable.dart';

import '../../../search/domain/entities/filter_state.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/map_marker_dto.dart';

@injectable
class SupabaseMapDatasource {
  SupabaseMapDatasource(this._client);
  final SupabaseClientWrapper _client;

  Future<List<MapMarkerDto>> loadAll() async {
    final rows = await _client.raw
        .from('v_listings_map_public')
        .select();
    return (rows as List)
        .map((r) => MapMarkerDto.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<MapMarkerDto>> loadFiltered(FilterState filter) async {
    final rows = await _client.raw.rpc(
      'search_map',
      params: _filterToRpcParams(filter),
    );
    return (rows as List)
        .map((r) => MapMarkerDto.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _filterToRpcParams(FilterState filter) {
    // Maps FilterState fields to the search_map(...) RPC parameter names.
    // Currency conversion to (USD, SYP) reuses Phase 14 R-75's pattern via
    // CurrencyRepository.latestRatesForBase (injected at construction or via
    // a dedicated mapper helper — plan-time choice).
    // ... (full body in implementation).
    return {};
  }
}
```

### 5.3 `MapRepositoryImpl` (sketch)

**File**: `lib/features/map/data/repositories/map_repository_impl.dart`

```dart
import 'package:injectable/injectable.dart';

import '../../../search/domain/entities/filter_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/map_marker.dart';
import '../../domain/repositories/map_repository.dart';
import '../datasources/supabase_map_datasource.dart';

@LazySingleton(as: MapRepository)
class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl(this._datasource);
  final SupabaseMapDatasource _datasource;

  @override
  Future<Result<List<MapMarker>, Failure>> loadMarkers({
    FilterState? filter,
  }) async {
    try {
      final dtos = filter == null
          ? await _datasource.loadAll()
          : await _datasource.loadFiltered(filter);
      return Result.success(dtos.map((d) => d.toEntity()).toList());
    } catch (e, s) {
      return Result.failure(Failure.fromException(e, stackTrace: s));
    }
  }
}
```

---

## 6. RLS posture summary

| Artifact | RLS source | Public read | Public write |
|----------|------------|-------------|--------------|
| `public.v_listings_map_public` | Inherits from `public.listings` base table; view's WHERE re-enforces approval + visibility gate | YES — `GRANT SELECT TO authenticated, anon` | No (views are not writeable from clients; even if they were, no INSERT/UPDATE policies exist for this view) |
| `public.map_jitter_coordinates(...)` | `SECURITY DEFINER` — runs as the function owner, reading `app.map_jitter_salt` GUC | YES — `GRANT EXECUTE TO authenticated, anon` | N/A (read-only function) |
| `public.search_map(...)` | `SECURITY DEFINER` — RPC, calls the view internally | YES — `GRANT EXECUTE TO authenticated, anon` | N/A |

**Constitution III check**: No new RLS opt-outs. The visibility gate (`location_visibility IN ('exact', 'approximate')`) is the data-layer enforcement of FR-002. The jitter function's `SECURITY DEFINER` is necessary because non-superuser roles cannot read the `app.map_jitter_salt` GUC — the function definer owns the read; callers never see the salt.

---

## 7. Per-FR / per-SC verification map

### Functional Requirements

| FR | Verification artifact |
|----|----------------------|
| FR-001 (read surface projects minimal fields) | data-model.md §2 view body — only the 13 listed columns appear in the SELECT list |
| FR-001a (return full country in one fetch, no bbox / cap / zoom-scoping) | data-model.md §2 view body has no `LIMIT` clause and no bbox parameter; §3 RPC body has no `p_bbox` or `p_limit` parameter |
| FR-002 (visibility gate at data layer) | data-model.md §2 WHERE: `l.location_visibility IN ('exact', 'approximate')` + quickstart.md grep gate "no app-layer location_visibility filter" |
| FR-003 (deterministic per-listing jitter, no true coords on wire) | data-model.md §1 function body uses SHA-256 hash; §2 view projects jittered coords for approximate; quickstart.md wire-level check confirms `leaked = false` for all approximate rows |
| FR-003a (approximate marker has visual + textual indicator) | plan.md §Sub-Phase E item 5 (popover renders "Approximate location" label when `marker.isApproximate`); plan.md §Sub-Phase F adds `map_marker_approximate_location_label` ARB key |
| FR-004 (exact coords passthrough) | data-model.md §2 view body: `CASE l.location_visibility WHEN 'exact' THEN l.latitude` |
| FR-005 (data-layer gate, no app-layer post-filter) | quickstart.md grep gate: `grep -RE "\.eq\('status', 'approved'\)\|\.neq\('location_visibility'" lib/features/map/` returns zero matches |
| FR-006 (anonymous-accessible) | data-model.md §2 `GRANT SELECT TO authenticated, anon`; §3 `GRANT EXECUTE TO authenticated, anon` |
| FR-007 (three entry points) | plan.md §Sub-Phase G scope items 1/2/3 wire all three; contracts/phase15-home-map-tile.md, phase15-listing-details-view-on-map.md, phase15-search-show-on-map.md |
| FR-007a (filter handoff from search + alert) | data-model.md §3 search_map RPC mirrors search_listings parameter shape; plan.md §Sub-Phase E item 7 (`FilterActiveAlertDialog`); contracts/phase15-search-show-on-map.md |
| FR-008 (OSM attribution visible) | plan.md §Sub-Phase E item 9 (`OsmAttributionWidget` overlay); R-94 documents the attribution copy |
| FR-009 (one marker per row) | plan.md §Sub-Phase E item 4 (`MarkerClusterLayerWidget` with markers from `MapLoaded.markers`) |
| FR-010 (marker tap → popover with image/title/price/badges) | plan.md §Sub-Phase E item 5 (`MarkerPreviewPopover` composition) |
| FR-011 (popover tap → /listings/:id) | plan.md §Sub-Phase E item 5 (`onTap` calls `context.go(AppRoutes.listingDetailsFor(id))`) |
| FR-012 (tap elsewhere dismisses popover; tap-different-marker single-tap) | plan.md §Sub-Phase E item 5 + bloc behavior in item 3 (`MarkerTapped(id)` replaces `selectedMarker`) |
| FR-013 (cluster: auto-zoom below max, spiderfy at max) | R-93 documents `flutter_map_marker_cluster` config; plan.md §Sub-Phase E item 4 (`zoomToBoundsOnClick: true`, `spiderfyClusterMaxZoom: maxZoom`) |
| FR-014 (back from details restores camera) | plan.md §Sub-Phase E item 3 — BLoC state is preserved across the marker-tap → details-page → back navigation cycle because the BLoC is route-scoped (Phase 14 R-77 pattern) |
| FR-014a (refresh strategy: button + session cache, no auto-refresh) | R-89 documents the decision; plan.md §Sub-Phase E item 8 ships `MapRefreshButton` |
| FR-015 (deep-link back via Navigator.canPop) | R-96 + plan.md §Sub-Phase B extracts `DeepLinkAwareBackButton`; plan.md §Sub-Phase E item 4 consumes it in MapPage AppBar |
| FR-015a (initial view: Syria-wide / centered-on-listing / fit-to-results) | plan.md §Sub-Phase E item 3 — bloc derives camera from MapEntryContext case |
| FR-015b (center-on-my-location + Android runtime permission) | R-88 documents plugin choice; plan.md §Sub-Phase E item 6 ships `CenterOnMyLocationFab`; contracts/phase15-geolocation-envelope.md captures the lifecycle |
| FR-015c (geolocation not persisted server-side) | contracts/phase15-geolocation-envelope.md "no persistence" rule; grep gate in quickstart confirms no Supabase call with `latitude`/`longitude` payload from the geolocation handler |
| FR-016 (all strings localized) | plan.md §Sub-Phase F lists all ~22 keys; quickstart grep gate: `grep -RE "Text\\([\"']" lib/features/map/` returns zero matches |
| FR-017 (RTL/LTR correctness) | quickstart.md two-device matrix tests 4 combinations (light/dark × ar/en) |
| FR-018 (design tokens) | quickstart.md grep gate: `grep -RE "Color\\(0xFF\|EdgeInsets\\.only\\(left" lib/features/map/` returns zero matches |
| FR-019 (flutter_map + OSM only, no commercial-map deps) | R-85 documents the constitutional pre-lock; quickstart grep gate: `grep -RE "google_maps\|mapbox" pubspec.yaml` returns zero matches |
| FR-020 (no changes to Phase 13/14 widgets beyond entry-point additions) | plan.md §Sub-Phase G scope items 2 + 3 explicitly limit the touch surface; Phase 12 Q8=A widget purity preserved for `ListingLocationBlock` |

### Success Criteria

| SC | Verification artifact |
|----|----------------------|
| SC-001 (tiles ≤3s, markers +2s) | quickstart.md step "Cold-launch map open on Syrian 4G" |
| SC-002 (exact at true coords, approximate within area) | quickstart.md wire-level inspection §2 quickstart.md + data-model.md §2 verification queries |
| SC-003 (zero wire-level rows for hidden/admin_only/non-approved; zero true-coord leaks for approximate) | quickstart.md wire-level inspection §3 — same queries as data-model.md §2 |
| SC-004 (marker tap ≤500ms popover; popover tap ≤1s nav) | quickstart.md manual stopwatch on Infinix Note 8 |
| SC-005 (back restores camera, no marker reload) | quickstart.md manual: tap marker → details → back; observe no marker flicker |
| SC-006 (cluster threshold + split-on-zoom) | quickstart.md manual: seed ≥30 listings in central Damascus; verify cluster at country zoom; verify split at city zoom |
| SC-007 (attribution always visible) | quickstart.md 4-combination matrix |
| SC-008 (4-combination correctness) | quickstart.md two-device matrix |
| SC-009 (zero google_maps/mapbox in pubspec) | quickstart.md grep gate (same as FR-019) |
| SC-010 (admin flip → marker disappears on refresh) | quickstart.md manual: flip visibility via SQL; tap refresh button; verify marker gone |
| SC-011 (auth state doesn't change dataset) | quickstart.md manual: same map state observed in anonymous and signed-in sessions |
| SC-012 (filter handoff → restricted markers; reset → +2s reload) | quickstart.md manual: apply filters in search; tap "Show on map"; verify alert + restricted set; tap "Reset filters"; stopwatch reload |
| SC-013 (alert ≤500ms when filtered; absent when unfiltered) | quickstart.md manual stopwatch on Infinix Note 8 |
| SC-014 (first geo tap → prompt; grant → ≤3s pan; subsequent ≤1s) | quickstart.md manual permission flow |
| SC-015 (denial → localized message ≤500ms; map remains functional) | quickstart.md manual permission flow — both "deny once" and "don't ask again" paths |
