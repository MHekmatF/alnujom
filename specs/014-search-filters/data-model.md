# Data Model: Search & Filters (Phase 14)

**Feature**: `014-search-filters`
**Created**: 2026-05-24

This file is the authoritative reference for every data shape introduced in Phase 14. Implementation agents must not deviate from these definitions without updating this file and the affected contracts.

---

## 1. SQL Artifacts

### 1.1 Migration: `20260525120001_listings_search_vector.sql`

```sql
-- Phase 14: Full-text search vector on public.listings
-- Covers title + address_text using 'simple' configuration (non-morphological, Arabic-compatible).
-- description is in listing_details (separate table) and is handled via ILIKE in the RPC (R-73).

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'simple',
      coalesce(title, '') || ' ' || coalesce(address_text, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_listings_search_vector
  ON public.listings USING GIN(search_vector);
```

**Idempotency**: `ADD COLUMN IF NOT EXISTS` + `CREATE INDEX IF NOT EXISTS` — safe to re-apply.

**Expected EXPLAIN output** (keyword query, see `contracts/phase14-search-vector-migration.md`):
```
Bitmap Heap Scan on listings
  -> Bitmap Index Scan on idx_listings_search_vector
```

---

### 1.2 Migration: `20260525120002_create_v_listings_public.sql`

```sql
-- Phase 14: Public listing projection view — approved, in-window listings only.
-- Read by search_listings RPC. Enforces status + publish-window at view level (R-81).

CREATE OR REPLACE VIEW public.v_listings_public AS
SELECT
  l.id,
  l.title,
  l.address_text,
  l.property_type,
  l.purpose,
  l.governorate_id,
  l.city_id,
  l.area_id,
  l.published_at,
  l.expires_at,
  l.search_vector,
  -- Primary price (is_primary = true row)
  lp.amount        AS primary_amount,
  lp.currency_code AS primary_currency,
  -- Main image (lowest position value)
  lm.storage_path  AS main_image_path,
  -- Bilingual location names
  g.name_ar        AS governorate_name_ar,
  g.name_en        AS governorate_name_en,
  c.name_ar        AS city_name_ar,
  c.name_en        AS city_name_en
FROM public.listings l
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
  ORDER BY position ASC
  LIMIT 1
) lm ON true
LEFT JOIN public.governorates g ON g.id = l.governorate_id
LEFT JOIN public.cities       c ON c.id = l.city_id
WHERE l.status = 'approved'
  AND (l.expires_at IS NULL OR l.expires_at > now());
```

**Idempotency**: `CREATE OR REPLACE VIEW` — safe to re-apply.

---

### 1.3 RPC: `20260525120003_create_search_listings_rpc.sql`

```sql
-- Phase 14: SECURITY DEFINER search RPC.
-- Re-enforces status='approved' + publish-window guard independently of RLS (R-74).
-- Full parameter contract: contracts/phase14-search-listings-rpc.md

-- Return type composite
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'search_result_row'
  ) THEN
    CREATE TYPE public.search_result_row AS (
      id               uuid,
      title            text,
      property_type    text,
      purpose          text,
      governorate_name_ar text,
      governorate_name_en text,
      city_name_ar     text,
      city_name_en     text,
      primary_amount   numeric,
      primary_currency text,
      main_image_path  text,
      published_at     timestamptz
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.search_listings(
  -- Full-text keyword (null = no keyword filter)
  p_query              text       DEFAULT NULL,
  -- Facet filters (null = dimension inactive)
  p_purpose            text       DEFAULT NULL,
  p_property_type      text       DEFAULT NULL,
  p_governorate_id     uuid       DEFAULT NULL,
  p_city_id            uuid       DEFAULT NULL,
  p_area_id            uuid       DEFAULT NULL,
  -- Price range — pre-converted to USD and SYP by client (R-75)
  p_price_min_usd      numeric    DEFAULT NULL,
  p_price_max_usd      numeric    DEFAULT NULL,
  p_price_min_syp      numeric    DEFAULT NULL,
  p_price_max_syp      numeric    DEFAULT NULL,
  -- Rooms filter
  p_rooms              integer    DEFAULT NULL,
  p_rooms_mode         text       DEFAULT 'exactly',  -- 'exactly' | 'at_least'
  -- Bathrooms filter
  p_bathrooms          integer    DEFAULT NULL,
  p_bathrooms_mode     text       DEFAULT 'exactly',  -- 'exactly' | 'at_least'
  -- Area size range (m²)
  p_area_size_min      numeric    DEFAULT NULL,
  p_area_size_max      numeric    DEFAULT NULL,
  -- Sort order
  p_sort               text       DEFAULT 'newest',   -- 'newest' | 'price_asc' | 'price_desc'
  -- Cursor (newest sort)
  p_cursor_published_at timestamptz DEFAULT NULL,
  p_cursor_id_newest   uuid       DEFAULT NULL,
  -- Cursor (price sorts)
  p_cursor_price_amount numeric   DEFAULT NULL,
  p_cursor_id_price    uuid       DEFAULT NULL,
  -- Page size
  p_limit              integer    DEFAULT 20
)
RETURNS SETOF public.search_result_row
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id,
    v.title,
    v.property_type,
    v.purpose,
    v.governorate_name_ar,
    v.governorate_name_en,
    v.city_name_ar,
    v.city_name_en,
    v.primary_amount,
    v.primary_currency,
    v.main_image_path,
    v.published_at
  FROM public.v_listings_public v
  LEFT JOIN public.listing_details ld ON ld.listing_id = v.id
  WHERE
    -- Approved + window guard is already enforced by the view (defense in depth)
    true
    -- Keyword: full-text on title/address + ILIKE on description
    AND (
      p_query IS NULL
      OR v.search_vector @@ plainto_tsquery('simple', p_query)
      OR ld.description ILIKE '%' || p_query || '%'
    )
    -- Facet filters
    AND (p_purpose       IS NULL OR v.purpose       = p_purpose)
    AND (p_property_type IS NULL OR v.property_type = p_property_type)
    AND (p_governorate_id IS NULL OR v.governorate_id = p_governorate_id)
    AND (p_city_id        IS NULL OR v.city_id        = p_city_id)
    AND (p_area_id        IS NULL OR v.area_id        = p_area_id)
    -- Price range (compare against listing's native currency; client pre-converts bounds)
    AND (
      p_price_min_usd IS NULL OR p_price_max_usd IS NULL
      OR (v.primary_currency = 'USD' AND v.primary_amount BETWEEN p_price_min_usd AND p_price_max_usd)
      OR (v.primary_currency = 'SYP' AND v.primary_amount BETWEEN p_price_min_syp AND p_price_max_syp)
    )
    -- Rooms filter
    AND (
      p_rooms IS NULL
      OR (p_rooms_mode = 'exactly'  AND ld.rooms = p_rooms)
      OR (p_rooms_mode = 'at_least' AND ld.rooms >= p_rooms)
    )
    -- Bathrooms filter
    AND (
      p_bathrooms IS NULL
      OR (p_bathrooms_mode = 'exactly'  AND ld.bathrooms = p_bathrooms)
      OR (p_bathrooms_mode = 'at_least' AND ld.bathrooms >= p_bathrooms)
    )
    -- Area size range
    AND (p_area_size_min IS NULL OR ld.area_size >= p_area_size_min)
    AND (p_area_size_max IS NULL OR ld.area_size <= p_area_size_max)
    -- Cursor predicates
    AND (
      p_sort <> 'newest'
      OR p_cursor_published_at IS NULL
      OR (v.published_at, v.id) < (p_cursor_published_at, p_cursor_id_newest)
    )
    AND (
      p_sort NOT IN ('price_asc', 'price_desc')
      OR p_cursor_price_amount IS NULL
      OR (
        p_sort = 'price_asc'
        AND (v.primary_amount, v.id::text) > (p_cursor_price_amount, p_cursor_id_price::text)
      )
      OR (
        p_sort = 'price_desc'
        AND (v.primary_amount, v.id::text) < (p_cursor_price_amount, p_cursor_id_price::text)
      )
    )
  ORDER BY
    CASE p_sort
      WHEN 'newest'     THEN v.published_at END DESC,
    CASE p_sort
      WHEN 'price_asc'  THEN v.primary_amount END ASC,
    CASE p_sort
      WHEN 'price_desc' THEN v.primary_amount END DESC,
    v.id ASC
  LIMIT p_limit;
END;
$$;

-- Grant execute to authenticated and anon roles
GRANT EXECUTE ON FUNCTION public.search_listings TO authenticated, anon;
```

**Idempotency**: `CREATE OR REPLACE FUNCTION` — safe to re-apply. The `DO $$ BEGIN IF NOT EXISTS ...` block for the composite type is also idempotent.

---

## 2. Dart Domain Entities

### 2.1 `search_result_item.dart`

```dart
// lib/features/search/domain/entities/search_result_item.dart
import 'package:equatable/equatable.dart';
import 'package:alnujom/features/listing_form/domain/entities/listing.dart';

class SearchResultItem extends Equatable {
  final String id;
  final String title;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final String governorateNameAr;
  final String governorateNameEn;
  final String cityNameAr;
  final String cityNameEn;
  final double primaryAmount;
  final String primaryCurrency;
  final String? mainImagePath;
  final DateTime publishedAt;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.governorateNameAr,
    required this.governorateNameEn,
    required this.cityNameAr,
    required this.cityNameEn,
    required this.primaryAmount,
    required this.primaryCurrency,
    this.mainImagePath,
    required this.publishedAt,
  });

  @override
  List<Object?> get props => [id];
}
```

### 2.2 `sort_order.dart`

```dart
// lib/features/search/domain/entities/sort_order.dart
enum SortOrder { newest, priceAsc, priceDesc }
```

### 2.3 `count_filter_mode.dart`

```dart
// lib/features/search/domain/entities/count_filter_mode.dart
enum CountFilterMode { exactly, atLeast }
```

### 2.4 `filter_state.dart`

```dart
// lib/features/search/domain/entities/filter_state.dart
import 'package:equatable/equatable.dart';
import 'package:alnujom/features/listing_form/domain/entities/listing.dart';
import 'package:alnujom/features/search/domain/entities/count_filter_mode.dart';

class FilterState extends Equatable {
  final String? query;
  final ListingPurpose? purpose;
  final PropertyType? propertyType;
  final String? governorateId;
  final String? cityId;
  final String? areaId;
  final double? priceMin;
  final double? priceMax;
  final String? priceCurrency;
  final int? rooms;
  final CountFilterMode roomsMode;
  final int? bathrooms;
  final CountFilterMode bathroomsMode;
  final double? areaSizeMin;
  final double? areaSizeMax;

  const FilterState({
    this.query,
    this.purpose,
    this.propertyType,
    this.governorateId,
    this.cityId,
    this.areaId,
    this.priceMin,
    this.priceMax,
    this.priceCurrency,
    this.rooms,
    this.roomsMode = CountFilterMode.exactly,
    this.bathrooms,
    this.bathroomsMode = CountFilterMode.exactly,
    this.areaSizeMin,
    this.areaSizeMax,
  });

  static const empty = FilterState();

  bool get isEmpty =>
      query == null &&
      purpose == null &&
      propertyType == null &&
      governorateId == null &&
      cityId == null &&
      areaId == null &&
      priceMin == null &&
      priceMax == null &&
      rooms == null &&
      bathrooms == null &&
      areaSizeMin == null &&
      areaSizeMax == null;

  FilterState copyWith({
    String? query,
    ListingPurpose? purpose,
    PropertyType? propertyType,
    String? governorateId,
    String? cityId,
    String? areaId,
    double? priceMin,
    double? priceMax,
    String? priceCurrency,
    int? rooms,
    CountFilterMode? roomsMode,
    int? bathrooms,
    CountFilterMode? bathroomsMode,
    double? areaSizeMin,
    double? areaSizeMax,
    // Sentinel for clearing nullable fields
    bool clearQuery = false,
    bool clearPurpose = false,
    bool clearPropertyType = false,
    bool clearGovernorateId = false,
    bool clearCityId = false,
    bool clearAreaId = false,
    bool clearPriceMin = false,
    bool clearPriceMax = false,
    bool clearRooms = false,
    bool clearBathrooms = false,
    bool clearAreaSize = false,
  }) {
    return FilterState(
      query: clearQuery ? null : (query ?? this.query),
      purpose: clearPurpose ? null : (purpose ?? this.purpose),
      propertyType: clearPropertyType ? null : (propertyType ?? this.propertyType),
      governorateId: clearGovernorateId ? null : (governorateId ?? this.governorateId),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      areaId: clearAreaId ? null : (areaId ?? this.areaId),
      priceMin: clearPriceMin ? null : (priceMin ?? this.priceMin),
      priceMax: clearPriceMax ? null : (priceMax ?? this.priceMax),
      priceCurrency: priceCurrency ?? this.priceCurrency,
      rooms: clearRooms ? null : (rooms ?? this.rooms),
      roomsMode: roomsMode ?? this.roomsMode,
      bathrooms: clearBathrooms ? null : (bathrooms ?? this.bathrooms),
      bathroomsMode: bathroomsMode ?? this.bathroomsMode,
      areaSizeMin: clearAreaSize ? null : (areaSizeMin ?? this.areaSizeMin),
      areaSizeMax: clearAreaSize ? null : (areaSizeMax ?? this.areaSizeMax),
    );
  }

  @override
  List<Object?> get props => [
        query, purpose, propertyType, governorateId, cityId, areaId,
        priceMin, priceMax, priceCurrency,
        rooms, roomsMode, bathrooms, bathroomsMode,
        areaSizeMin, areaSizeMax,
      ];
}
```

### 2.5 Cursor sealed class (in `search_state.dart`)

```dart
// Declared inside lib/features/search/presentation/bloc/search_state.dart

sealed class SearchCursor {}

class NewestCursor extends SearchCursor {
  final DateTime publishedAt;
  final String id;
  NewestCursor({required this.publishedAt, required this.id});
}

class PriceCursor extends SearchCursor {
  final double priceAmount;
  final String id;
  PriceCursor({required this.priceAmount, required this.id});
}
```

---

## 3. ARB Key Inventory (~34 keys)

All keys are added to `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, and `lib/l10n/app_strings.dart` in Sub-Phase C.

### Search Page Chrome

| Key | Arabic (ar) | English (en) | Notes |
|-----|-------------|--------------|-------|
| `search_placeholder` | `ابحث عن شقق، فيلل، أراضي...` | `Search for apartments, villas, lands...` | Text field hint |
| `search_filters_button` | `الفلاتر` | `Filters` | Button label |
| `search_sort_label` | `ترتيب:` | `Sort:` | Prefix before DropdownButton |
| `search_results_count` | `{count} نتيجة` | `{count} results` | ICU plural; `count` param |

### Sort Options

| Key | Arabic (ar) | English (en) |
|-----|-------------|--------------|
| `search_sort_newest` | `الأحدث` | `Newest` |
| `search_sort_price_asc` | `السعر: من الأقل` | `Price: Low to High` |
| `search_sort_price_desc` | `السعر: من الأعلى` | `Price: High to Low` |

### Filter Sheet Chrome

| Key | Arabic (ar) | English (en) |
|-----|-------------|--------------|
| `search_filter_sheet_title` | `الفلاتر` | `Filters` |
| `search_filter_apply` | `تطبيق` | `Apply` |
| `search_filter_reset` | `إعادة تعيين` | `Reset` |

### Filter Dimensions

| Key | Arabic (ar) | English (en) | Notes |
|-----|-------------|--------------|-------|
| `search_filter_purpose_label` | `الغرض` | `Purpose` | Section label |
| `search_filter_property_type_label` | `نوع العقار` | `Property Type` | Section label |
| `search_filter_location_label` | `الموقع` | `Location` | Section label |
| `search_filter_governorate_hint` | `اختر المحافظة` | `Select governorate` | DropdownButton hint |
| `search_filter_city_hint` | `اختر المدينة` | `Select city` | DropdownButton hint |
| `search_filter_area_hint` | `اختر المنطقة` | `Select area` | DropdownButton hint |
| `search_filter_price_range_label` | `نطاق السعر` | `Price Range` | Section label |
| `search_filter_price_min_hint` | `الحد الأدنى` | `Min price` | TextFormField hint |
| `search_filter_price_max_hint` | `الحد الأعلى` | `Max price` | TextFormField hint |
| `search_filter_price_currency_label` | `العملة` | `Currency` | Label next to currency selector |
| `search_filter_price_min_max_error` | `الحد الأدنى يجب أن يكون أقل من الأعلى` | `Min price must be less than max` | Inline validation error |
| `search_filter_price_no_exchange_rate` | `سعر الصرف غير متاح لهذه العملة` | `Exchange rate unavailable for this currency` | Disables price filter for currency |
| `search_filter_rooms_label` | `غرف النوم` | `Bedrooms` | Section label |
| `search_filter_rooms_exactly` | `تماماً` | `Exactly` | SegmentedButton segment label |
| `search_filter_rooms_at_least` | `على الأقل` | `At least` | SegmentedButton segment label |
| `search_filter_bathrooms_label` | `الحمامات` | `Bathrooms` | Section label |
| `search_filter_area_size_label` | `المساحة (م²)` | `Area size (m²)` | Section label |

### Empty / Error States

| Key | Arabic (ar) | English (en) | Notes |
|-----|-------------|--------------|-------|
| `search_empty_title` | `لا توجد نتائج` | `No results found` | Empty-state headline |
| `search_empty_subtitle` | `حاول تغيير الكلمات أو الفلاتر` | `Try different keywords or filters` | Empty-state body |
| `search_empty_clear_filters` | `مسح الفلاتر` | `Clear all filters` | Empty-state CTA button |
| `search_arabic_hint` | `البحث بالعربية يطابق الكلمة تماماً. جرب: {suggestion}` | `Arabic search matches exact word forms. Try: {suggestion}` | FR-019; `suggestion` param |
| `search_loading` | `جارٍ البحث...` | `Searching...` | Loading indicator label |
| `search_error_message` | `حدث خطأ أثناء البحث` | `An error occurred while searching` | Error-state body |
| `search_error_retry` | `إعادة المحاولة` | `Retry` | Error-state CTA |

---

## 4. FR / SC Verification Map

Each row maps a Functional Requirement or Success Criterion to the artifact(s) that implement or verify it.

| FR / SC | Implemented By | Verified By |
|---------|---------------|-------------|
| FR-001 | `search_page.dart`, `app_router.dart` GoRoute `/search` | SC-011: navigate from home hero + home chip |
| FR-002 | `search_listings` RPC `p_query` + `v_listings_public.search_vector` | SC-001 / SC-002: keyword query returns matching results |
| FR-003 | `to_tsvector('simple', ...)` — 'simple' config, no morphology | SC-001: "شقة" does not match "شقق" |
| FR-004 | `p_query` ILIKE + `plainto_tsquery('simple', ...)` case-insensitive | SC-002: Latin keyword search |
| FR-005 | `search_filter_sheet.dart` + `price_range_input.dart` | SC-003: apply combinations; SC-007: Apply/Reset behavior |
| FR-006 | Location cascade in `search_filter_sheet.dart` using Phase 8 `LocationRepository` (R-83) | SC-003: governorate → city cascade |
| FR-007 | `latest_rates_for_base` fetch + pre-conversion in `supabase_search_datasource.dart` (R-75) | SC-003: price range filter |
| FR-008 | `inline_sort_control.dart` DropdownButton on `search_page.dart` | SC-004: sort reorder ≤1s |
| FR-009 | All three filters + sort composable in `search_bloc.dart` `SearchState` | SC-003: combined filter/sort |
| FR-010 | `search_page.dart` empty-state widget + `search_empty_clear_filters` ARB key | SC-006: empty state ≤1s |
| FR-011 | `v_listings_public` WHERE clause + RPC SECURITY DEFINER | SC-008: anonymous access; approved-only gate |
| FR-012 | `SearchBloc` BLoC lifetime at route scope (R-77) | SC-005: back-navigation restores state |
| FR-013 | ARB keys in `app_ar.arb` / `app_en.arb`; `EdgeInsetsDirectional` in widgets | SC-007: RTL/LTR rendering |
| FR-014 | Cursor pagination in `search_bloc.dart` + RPC cursor params | SC-010: scroll → next page |
| FR-015 | `v_listings_public` accessible to `anon` role; `search_listings` GRANT to `anon` | SC-008: anonymous search |
| FR-016 | `SearchStatus.loading` state → loading indicator in `search_page.dart` | Manual: loading spinner visible |
| FR-017 | `price_range_input.dart` inline validator `min > max` | SC-009: validation error visible |
| FR-018 | `FilterState.empty` → `SearchBloc` dispatches `SearchFiltersApplied(FilterState.empty)` on Reset | SC-007: Reset returns to all-approved |
| FR-019 | `search_page.dart` renders `search_arabic_hint` when `results.length < 3` | SC-001 variant: Arabic sparse-result hint |
