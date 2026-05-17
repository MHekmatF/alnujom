# Phase 1 Data Model: Locations Catalog

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

This file is the canonical structural definition for every backend artifact Phase 8 introduces (tables, triggers, policies, seed inventory), plus the Flutter-side domain shapes (entities, repositories, use cases, BLoCs) and the ARB key inventory. Everything below is derived from the spec FRs and the Session 2026-05-16 clarifications; the contracts in `contracts/` are the per-interface deliverable shapes downstream consumers MUST honor.

## 1. Tables

### 1.1 `public.governorates`

```sql
CREATE TABLE IF NOT EXISTS public.governorates (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key          TEXT NOT NULL UNIQUE,
  display_name JSONB NOT NULL CHECK (
    jsonb_typeof(display_name) = 'object'
    AND coalesce(trim(display_name->>'ar'), '') <> ''
  ),
  description  JSONB,
  position     INTEGER,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  is_system    BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT governorates_key_format CHECK (key ~ '^[a-z0-9][a-z0-9-]*$')
);

COMMENT ON TABLE public.governorates IS
  'Phase 8 — Syrian first-level administrative divisions (14 seeded with is_system=true). RLS: public SELECT (anon + authenticated); write gated by locations.manage per the Phase 6 permission catalog.';
COMMENT ON COLUMN public.governorates.key IS
  'Stable lowercase slug (e.g., damascus, aleppo, rif-dimashq). Unique. Cannot be UPDATEd on is_system=true rows (enforced by enforce_governorate_system_immutability).';
COMMENT ON COLUMN public.governorates.display_name IS
  'Bilingual JSONB {"ar": "...", "en": "..."} — Arabic value required; English value optional. Phase 6 roles.display_name pattern.';
COMMENT ON COLUMN public.governorates.position IS
  'Editorial ordering hint. ORDER BY position NULLS LAST, key ASC for display.';
COMMENT ON COLUMN public.governorates.is_active IS
  'Soft-deactivation flag. Admin pages show inactive rows with a Hidden badge; LocationPicker filters them out.';
COMMENT ON COLUMN public.governorates.is_system IS
  'TRUE for the 14 seeded governorates. Refuses DELETE and key UPDATE via enforce_governorate_system_immutability.';
```

### 1.2 `public.cities`

```sql
CREATE TABLE IF NOT EXISTS public.cities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  governorate_id  UUID NOT NULL REFERENCES public.governorates(id) ON DELETE CASCADE,
  key             TEXT NOT NULL,
  display_name    JSONB NOT NULL CHECK (
    jsonb_typeof(display_name) = 'object'
    AND coalesce(trim(display_name->>'ar'), '') <> ''
  ),
  description     JSONB,
  position        INTEGER,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  is_system       BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cities_key_format CHECK (key ~ '^[a-z0-9][a-z0-9-]*$'),
  CONSTRAINT cities_unique_key_per_governorate UNIQUE (governorate_id, key)
);

COMMENT ON TABLE public.cities IS
  'Phase 8 — cities scoped to governorates (~30–40 seeded with is_system=true per Clarifications Q4). RLS: public SELECT; write gated by locations.manage.';
```

### 1.3 `public.areas`

```sql
CREATE TABLE IF NOT EXISTS public.areas (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id      UUID NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  key          TEXT NOT NULL,
  display_name JSONB NOT NULL CHECK (
    jsonb_typeof(display_name) = 'object'
    AND coalesce(trim(display_name->>'ar'), '') <> ''
  ),
  description  JSONB,
  position     INTEGER,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT areas_key_format CHECK (key ~ '^[a-z0-9][a-z0-9-]*$'),
  CONSTRAINT areas_unique_key_per_city UNIQUE (city_id, key)
);

COMMENT ON TABLE public.areas IS
  'Phase 8 — areas scoped to cities (starter set seeded). No is_system column — areas have no protected seed; full CRUD on every row.';
```

## 2. Indexes (`20260517120004_create_locations_indexes.sql`)

```sql
CREATE INDEX IF NOT EXISTS idx_governorates_position_key ON public.governorates(position NULLS LAST, key);
CREATE INDEX IF NOT EXISTS idx_governorates_is_active   ON public.governorates(is_active);
CREATE INDEX IF NOT EXISTS idx_cities_governorate_id    ON public.cities(governorate_id);
CREATE INDEX IF NOT EXISTS idx_cities_is_active         ON public.cities(is_active);
CREATE INDEX IF NOT EXISTS idx_cities_position_key      ON public.cities(governorate_id, position NULLS LAST, key);
CREATE INDEX IF NOT EXISTS idx_areas_city_id            ON public.areas(city_id);
CREATE INDEX IF NOT EXISTS idx_areas_is_active          ON public.areas(is_active);
CREATE INDEX IF NOT EXISTS idx_areas_position_key       ON public.areas(city_id, position NULLS LAST, key);
```

The composite `(parent_id, position, key)` indexes support the page-load query pattern `WHERE parent_id = $1 AND is_active = ...  ORDER BY position NULLS LAST, key`. The unique constraints (`UNIQUE (governorate_id, key)` and `UNIQUE (city_id, key)`) already produce supporting indexes.

## 3. Triggers

Every trigger is declared with `DROP TRIGGER IF EXISTS ... ; CREATE TRIGGER ...` so re-applying the migration is idempotent (Phase 4 R-01 convention).

### 3.1 `set_updated_at` (existing Phase 4 helper, reused unchanged)

Attached to all three new tables. Body is in Phase 4's migration; Phase 8 attaches it as:

```sql
CREATE TRIGGER trg_governorates_set_updated_at
  BEFORE UPDATE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_cities_set_updated_at
  BEFORE UPDATE ON public.cities
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_areas_set_updated_at
  BEFORE UPDATE ON public.areas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

### 3.2 `enforce_governorate_system_immutability` (new, Phase 8)

NOTE on `SECURITY DEFINER`: Phase 6's shipped `enforce_role_system_immutability` is **not** `SECURITY DEFINER`, and during Phase 8 implementation the Supabase advisor flagged `SECURITY DEFINER` on these trigger functions (`anon_security_definer_function_executable` + `authenticated_security_definer_function_executable`). Trigger functions only read `OLD.*` and raise exceptions — they do not need elevated privileges. The shipped code therefore drops `SECURITY DEFINER` to match Phase 6's actual practice. The body below reflects the canonical final-shipped state.

```sql
CREATE OR REPLACE FUNCTION public.enforce_governorate_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'governorate_system_immutable: cannot delete a system governorate (key=%)', OLD.key
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key THEN
      RAISE EXCEPTION 'governorate_system_immutable: cannot rename a system governorate''s key (was %, attempted %)', OLD.key, NEW.key
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_governorates_enforce_immutability ON public.governorates;
CREATE TRIGGER trg_governorates_enforce_immutability
  BEFORE UPDATE OR DELETE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.enforce_governorate_system_immutability();
```

### 3.3 `enforce_city_system_immutability` (new, Phase 8)

Symmetric to 3.2, against `public.cities`. Same SQLSTATE `42501`; same error code prefix `city_system_immutable`.

### 3.4 Audit triggers — three groups via Phase 4's `log_audit()` (unchanged)

Per R-08, attached BEFORE the seed `INSERT` statements within each table-creation migration so seed rows produce one `*.created` audit row each.

```sql
-- governorates
CREATE TRIGGER trg_governorates_audit_created
  AFTER INSERT ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('governorate.created', '*', 'id');

CREATE TRIGGER trg_governorates_audit_updated
  AFTER UPDATE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('governorate.updated', '*', 'id');

CREATE TRIGGER trg_governorates_audit_deleted
  AFTER DELETE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('governorate.deleted', '*', 'id');

-- cities (same shape with action prefix 'city.', target column 'id')
-- areas (same shape with action prefix 'area.', target column 'id')
```

Action keys: `governorate.created`, `governorate.updated`, `governorate.deleted`, `city.created`, `city.updated`, `city.deleted`, `area.created`, `area.updated`, `area.deleted`. The nine keys are added to `supabase/docs/audit_logs.md`.

## 4. RLS Policies

RLS is enabled on all three tables:

```sql
ALTER TABLE public.governorates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cities       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.areas        ENABLE ROW LEVEL SECURITY;
```

Each table carries the same four policies (the table identifier is the only difference). Below is the `governorates` set; `cities` and `areas` are identical mod the table name.

```sql
-- SELECT: anon + authenticated (R-04)
DROP POLICY IF EXISTS governorates_select_public ON public.governorates;
CREATE POLICY governorates_select_public
  ON public.governorates
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: requires locations.manage
DROP POLICY IF EXISTS governorates_insert_locations_manage ON public.governorates;
CREATE POLICY governorates_insert_locations_manage
  ON public.governorates
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- UPDATE: requires locations.manage
DROP POLICY IF EXISTS governorates_update_locations_manage ON public.governorates;
CREATE POLICY governorates_update_locations_manage
  ON public.governorates
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'))
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- DELETE: requires locations.manage
DROP POLICY IF EXISTS governorates_delete_locations_manage ON public.governorates;
CREATE POLICY governorates_delete_locations_manage
  ON public.governorates
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'));
```

The same policies are mirrored to `supabase/policies/governorates_phase8.sql`, `cities_phase8.sql`, `areas_phase8.sql` per R-02. The `20260517120005_phase8_advisor_hardening.sql` migration codifies `GRANT SELECT ON public.<table> TO anon, authenticated;` for all three.

## 5. Seed inventory

### 5.1 Governorates (14 rows, `is_system=true`, with editorial `position`)

| `key` | `display_name->>'ar'` | `display_name->>'en'` | `position` |
|---|---|---|---|
| `damascus`     | دمشق          | Damascus         | 10  |
| `aleppo`       | حلب           | Aleppo           | 20  |
| `homs`         | حمص           | Homs             | 30  |
| `latakia`      | اللاذقية      | Latakia          | 40  |
| `tartus`       | طرطوس         | Tartus           | 50  |
| `hama`         | حماة          | Hama             | 60  |
| `rif-dimashq`  | ريف دمشق      | Rif Dimashq      | 70  |
| `idlib`        | إدلب          | Idlib            | 80  |
| `daraa`        | درعا          | Daraa            | 90  |
| `deir-ez-zor`  | دير الزور     | Deir ez-Zor      | 100 |
| `al-hasakah`   | الحسكة        | Al-Hasakah       | 110 |
| `al-raqqah`    | الرقة         | Al-Raqqah        | 120 |
| `as-suwayda`   | السويداء      | As-Suwayda       | 130 |
| `quneitra`     | القنيطرة      | Quneitra         | 140 |

### 5.2 Cities (target 30–40 rows, all `is_system=true`)

Locked at implementation time within the 30–40 target band. Below is the planned inventory; the migration author MAY adjust by one or two rows in either direction if a name's bilingual spelling needs verification. **EVERY row in this table is seeded with `is_system=true`** (the column is omitted from the table headers to save space — the seed `INSERT` statement MUST include `is_system=true` explicitly for every value tuple).

| `key` (scoped per governorate) | `governorate.key` | `ar` | `en` | `position` | `is_system` |
|---|---|---|---|---|---|
| `damascus`        | `damascus`     | دمشق              | Damascus           | 10 | true |
| `aleppo`          | `aleppo`       | حلب               | Aleppo             | 10 | true |
| `manbij`          | `aleppo`       | منبج              | Manbij             |    | true |
| `afrin`           | `aleppo`       | عفرين             | Afrin              |    | true |
| `azaz`            | `aleppo`       | أعزاز             | Azaz               |    | true |
| `homs`            | `homs`         | حمص               | Homs               | 10 | true |
| `palmyra`         | `homs`         | تدمر              | Palmyra            |    | true |
| `talkalakh`       | `homs`         | تلكلخ             | Talkalakh          |    | true |
| `latakia`         | `latakia`      | اللاذقية          | Latakia            | 10 | true |
| `jableh`          | `latakia`      | جبلة              | Jableh             |    | true |
| `tartus`          | `tartus`       | طرطوس             | Tartus             | 10 | true |
| `banias`          | `tartus`       | بانياس            | Banias             |    | true |
| `hama`            | `hama`         | حماة              | Hama               | 10 | true |
| `salamiya`        | `hama`         | سلمية             | Salamiya           |    | true |
| `masyaf`          | `hama`         | مصياف             | Masyaf             |    | true |
| `douma`           | `rif-dimashq`  | دوما              | Douma              | 10 | true |
| `yabroud`         | `rif-dimashq`  | يبرود             | Yabroud            |    | true |
| `qatana`          | `rif-dimashq`  | قطنا              | Qatana             |    | true |
| `idlib`           | `idlib`        | إدلب              | Idlib              | 10 | true |
| `maaret-al-numan` | `idlib`        | معرة النعمان      | Maaret al-Numan    |    | true |
| `daraa`           | `daraa`        | درعا              | Daraa              | 10 | true |
| `bosra`           | `daraa`        | بصرى              | Bosra              |    | true |
| `deir-ez-zor`     | `deir-ez-zor`  | دير الزور         | Deir ez-Zor        | 10 | true |
| `albu-kamal`      | `deir-ez-zor`  | البوكمال          | Albu Kamal         |    | true |
| `mayadeen`        | `deir-ez-zor`  | الميادين          | Mayadeen           |    | true |
| `al-hasakah`      | `al-hasakah`   | الحسكة            | Al-Hasakah         | 10 | true |
| `qamishli`        | `al-hasakah`   | القامشلي          | Qamishli           |    | true |
| `al-raqqah`       | `al-raqqah`    | الرقة             | Al-Raqqah          | 10 | true |
| `tabqa`           | `al-raqqah`    | الطبقة            | Tabqa              |    | true |
| `as-suwayda`      | `as-suwayda`   | السويداء          | As-Suwayda         | 10 | true |
| `shahba`          | `as-suwayda`   | شهبا              | Shahba             |    | true |
| `quneitra`        | `quneitra`     | القنيطرة          | Quneitra           | 10 | true |

Total: 32 cities (within the 30–40 target band). All 32 rows MUST be inserted with `is_system=true`.

### 5.3 Areas (starter set, no `is_system`)

A small set scoped to the largest cities. Locked at implementation time; the migration author SHOULD include at least one area per the six explicitly-named major cities (Damascus, Aleppo, Homs, Latakia, Tartus, Hama). Example seed entries:

| `key` | `city.key` (in governorate) | `ar` | `en` |
|---|---|---|---|
| `old-city-damascus` | `damascus` / `damascus`        | المدينة القديمة | Old City Damascus |
| `mezzeh`            | `damascus` / `damascus`        | المزة            | Mezzeh            |
| `mashrouh-dummar`   | `damascus` / `damascus`        | مشروع دمر        | Mashrouh Dummar   |
| `aleppo-old-city`   | `aleppo` / `aleppo`            | حلب القديمة     | Aleppo Old City   |
| `sulaymaniyah`      | `aleppo` / `aleppo`            | السليمانية       | Sulaymaniyah      |
| `homs-old-city`     | `homs` / `homs`                | حمص القديمة     | Homs Old City     |
| `latakia-corniche`  | `latakia` / `latakia`          | كورنيش اللاذقية | Latakia Corniche  |
| `tartus-corniche`   | `tartus` / `tartus`            | كورنيش طرطوس    | Tartus Corniche   |
| `hama-norias`       | `hama` / `hama`                | منطقة النواعير  | Hama Norias       |

The exact starter inventory is finalized in the migration body; the row count is intentionally small (~10) because admins fill the rest via the in-app form (US5).

## 6. Flutter domain shapes

### 6.1 Entities (`lib/features/locations/domain/entities/`)

```dart
// governorate.dart
class Governorate extends Equatable {
  final String id;
  final String key;
  final Map<String, String> displayName; // {'ar': '...', 'en': '...'}
  final Map<String, String>? description;
  final int? position;
  final bool isActive;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  String localizedName(Locale locale) {
    final active = displayName[locale.languageCode]?.trim();
    if (active != null && active.isNotEmpty) return active;
    final fallback = locale.languageCode == 'ar' ? displayName['en'] : displayName['ar'];
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    return key;
  }

  @override
  List<Object?> get props => [id, key, displayName, description, position, isActive, isSystem, createdAt, updatedAt];
}

// city.dart — adds governorateId; otherwise identical shape (also carries isSystem)
// area.dart — adds cityId; no isSystem; otherwise identical shape

// governorate_with_city_count.dart
class GovernorateWithCityCount extends Equatable {
  final Governorate governorate;
  final int cityCount;
  @override List<Object?> get props => [governorate, cityCount];
}

// city_with_area_count.dart — symmetric

// location_picker_selection.dart
class LocationPickerSelection extends Equatable {
  final String governorateId;
  final String cityId;
  final String? areaId;
  const LocationPickerSelection({required this.governorateId, required this.cityId, this.areaId});
  @override List<Object?> get props => [governorateId, cityId, areaId];
}
```

### 6.2 Repository (`lib/features/locations/domain/repositories/locations_repository.dart`)

```dart
abstract class LocationsRepository {
  Future<List<GovernorateWithCityCount>> listGovernorates({required bool includeInactive});
  Future<Governorate> loadGovernorate(String id);
  Future<List<CityWithAreaCount>> listCitiesForGovernorate(String governorateId, {required bool includeInactive});
  Future<City> loadCity(String id);
  Future<List<Area>> listAreasForCity(String cityId, {required bool includeInactive});

  Future<Governorate> createGovernorate({required String key, required Map<String, String> displayName, Map<String, String>? description, int? position, bool isActive = true});
  Future<Governorate> updateGovernorate(String id, {Map<String, String>? displayName, Map<String, String>? description, int? position, bool? isActive, String? key});
  Future<void> deleteGovernorate(String id);

  Future<City> createCity({required String governorateId, required String key, required Map<String, String> displayName, ...});
  Future<City> updateCity(String id, {...});
  Future<void> deleteCity(String id);

  Future<Area> createArea({required String cityId, required String key, required Map<String, String> displayName, ...});
  Future<Area> updateArea(String id, {...});
  Future<void> deleteArea(String id);

  // Count helpers for the delete-confirmation dialog (Clarifications Q2).
  Future<int> countCitiesInGovernorate(String governorateId);
  Future<int> countAreasInCity(String cityId);
  Future<int> countAreasInGovernorate(String governorateId);
}
```

### 6.3 Use cases (`lib/features/locations/domain/usecases/`)

16 use cases total — 14 primary CRUD/read use cases plus 2 dependent-count use cases consumed by the delete-confirmation dialogs (FR-017):

- `ListGovernorates({required bool includeInactive})`
- `LoadGovernorateDetail(String id)`
- `ListCitiesForGovernorate({required String governorateId, required bool includeInactive})`
- `LoadCityDetail(String id)`
- `ListAreasForCity({required String cityId, required bool includeInactive})`
- `CreateGovernorate(...)`
- `UpdateGovernorate(String id, ...)`
- `DeleteGovernorate(String id)`
- `CreateCity(...)`
- `UpdateCity(String id, ...)`
- `DeleteCity(String id)`
- `CreateArea(...)`
- `UpdateArea(String id, ...)`
- `DeleteArea(String id)`
- `CountGovernorateDependents(String governorateId)` — returns `({int cities, int areas})`. Consumed by `LocationsListPage` delete-confirmation dialog (FR-017). Wraps `repository.countCitiesInGovernorate` + `repository.countAreasInGovernorate`.
- `CountCityDependents(String cityId)` — returns `int` (the area count). Consumed by `GovernorateDetailPage` delete-confirmation dialog. Wraps `repository.countAreasInCity`.

Each use case is a class with a `call(...)` method that delegates to the repository; returns `Either<LocationsFailure, T>` (or the Phase 7 `Failure` pattern the project established).

### 6.4 BLoCs (`lib/features/locations/presentation/bloc/`)

| BLoC | Owns | Events | States |
|---|---|---|---|
| `LocationsListBloc` | Governorate list state for `LocationsListPage`. | `LoadRequested`, `RefreshRequested` | `Loading`, `Loaded(List<GovernorateWithCityCount>)`, `Error(String)` |
| `GovernorateDetailBloc` | Governorate header + city list for `GovernorateDetailPage`. | `LoadRequested(String governorateId)`, `RefreshRequested` | `Loading`, `Loaded(Governorate, List<CityWithAreaCount>)`, `Error` |
| `CityDetailBloc` | City header + area list for `CityDetailPage`. | `LoadRequested(String cityId)`, `RefreshRequested` | `Loading`, `Loaded(City, List<Area>)`, `Error` |
| `LocationFormBloc` | Add/edit form state (reused across governorate/city/area). | `FormOpened(LocationFormMode mode, LocationLevel level, String? id, String? parentId)`, `FieldChanged(...)`, `SaveRequested` | `Idle`, `Validating`, `Saving`, `SaveSuccess(<entity>)`, `SaveFailure(LocationsFailure)` |
| `LocationPickerBloc` | Cascade picker state for the `LocationPicker` widget. | `MountRequested`, `GovernoratePicked(String id)`, `CityPicked(String id)`, `AreaPicked(String? id)`, `Reset` | `Initial`, `GovernoratesLoading`, `GovernoratesLoaded(List<Governorate>)`, `CitiesLoading(String governorateId)`, `CitiesLoaded(...)`, `AreasLoading(String cityId)`, `AreasLoaded(...)`, `SelectionCommitted(LocationPickerSelection)` |

### 6.5 Pages and widgets (under `lib/features/locations/presentation/`)

- **Pages**: `locations_list_page.dart`, `governorate_detail_page.dart`, `city_detail_page.dart`, `location_form_page.dart`.
- **Widgets**: `governorate_card.dart`, `city_card.dart`, `area_card.dart`, `delete_confirmation_dialog.dart`, `bilingual_display_name_field.dart`, `location_picker.dart`, `location_picker_dropdown.dart`, `system_row_badge.dart`.

## 7. Routing

Four new routes registered in `lib/app.dart` (or `lib/core/routing/auth_redirect.dart`):

| Route | Page | Guard |
|---|---|---|
| `/admin/locations`                                            | `LocationsListPage`       | `PermissionChecker.has('locations.manage')` |
| `/admin/locations/:governorateId`                             | `GovernorateDetailPage`   | same |
| `/admin/locations/:governorateId/cities/:cityId`              | `CityDetailPage`          | same |
| `/admin/locations/form`                                       | `LocationFormPage` (modal)| same; takes `mode`, `level`, `id`, `parentId` as query params |

The Phase 6 `AdminHomePage` adds one new tile "Locations" gated by `PermissionChecker.has('locations.manage')` that navigates to `/admin/locations`.

## 8. ARB key inventory

Approximately 25 new ARB keys, added to both `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` in the same commit (Phase 3 localization gate).

| ARB key | `ar` | `en` |
|---|---|---|
| `locationsTileTitle`                | المواقع                       | Locations                       |
| `locationsListPageTitle`            | المحافظات                     | Governorates                    |
| `governorateDetailPageTitle`        | تفاصيل المحافظة               | Governorate Details             |
| `cityDetailPageTitle`               | تفاصيل المدينة                | City Details                    |
| `addGovernorateButton`              | إضافة محافظة                  | Add governorate                 |
| `addCityButton`                     | إضافة مدينة                   | Add city                        |
| `addAreaButton`                     | إضافة منطقة                   | Add area                        |
| `editAffordance`                    | تعديل                         | Edit                            |
| `deleteAffordance`                  | حذف                           | Delete                          |
| `keyFieldLabel`                     | المعرّف                       | Slug                            |
| `displayNameArabicLabel`            | الاسم بالعربية                | Arabic name                     |
| `displayNameEnglishLabel`           | الاسم بالإنجليزية              | English name                    |
| `descriptionLabel`                  | الوصف                         | Description                     |
| `positionLabel`                     | الترتيب                       | Order                           |
| `isActiveToggleLabel`               | نشط                           | Active                          |
| `hiddenBadge`                       | مخفي                          | Hidden                          |
| `systemBadge`                       | نظامي                         | System                          |
| `arabicNameRequired`                | الاسم بالعربية مطلوب          | Arabic name is required         |
| `keyRequired`                       | المعرّف مطلوب                 | Slug is required                |
| `keyAlreadyUsed`                    | هذا المعرّف مستخدم بالفعل     | This slug is already used       |
| `deleteConfirmTitle`                | تأكيد الحذف                   | Confirm deletion                |
| `deleteConfirmGovernorateWithDeps`  | ستُحذف {cityCount} مدن و{areaCount} منطقة | {cityCount} cities and {areaCount} areas will also be deleted |
| `deleteConfirmCityWithDeps`         | ستُحذف {areaCount} منطقة      | {areaCount} areas will also be deleted |
| `cannotDeleteSystemRow`             | لا يمكن حذف صف نظامي          | System rows cannot be deleted   |
| `locationPickerSelectGovernorate`   | اختر المحافظة                 | Select a governorate            |
| `locationPickerSelectCity`          | اختر المدينة                  | Select a city                   |
| `locationPickerSelectArea`          | اختر المنطقة (اختياري)        | Select an area (optional)       |
| `locationPickerNoAreasYet`          | لا توجد مناطق بعد — اتركها فارغة | No areas yet — leave blank   |
| `locationsLoadFailed`               | تعذّر تحميل المواقع           | Failed to load locations        |
| `locationSaveFailed`                | تعذّر الحفظ                   | Save failed                     |

Final exact count may shift by ±2 keys during implementation; the floor is "every user-visible chrome string the new feature surfaces."

## 9. Read-side query patterns

The data source issues these queries (the Supabase REST equivalents are the same shape):

```sql
-- LocationsListPage: governorate list with rolled-up city counts
SELECT
  g.*,
  (SELECT COUNT(*) FROM public.cities c WHERE c.governorate_id = g.id) AS city_count
FROM public.governorates g
ORDER BY g.position NULLS LAST, g.key;

-- GovernorateDetailPage: governorate + cities-with-area-counts
SELECT g.* FROM public.governorates g WHERE g.id = $1;
SELECT
  c.*,
  (SELECT COUNT(*) FROM public.areas a WHERE a.city_id = c.id) AS area_count
FROM public.cities c
WHERE c.governorate_id = $1
ORDER BY c.position NULLS LAST, c.key;

-- CityDetailPage: city + areas
SELECT c.* FROM public.cities c WHERE c.id = $1;
SELECT a.* FROM public.areas a
WHERE a.city_id = $1
ORDER BY a.position NULLS LAST, a.key;

-- LocationPicker (consumer-facing): is_active filter
SELECT g.* FROM public.governorates g WHERE g.is_active ORDER BY g.position NULLS LAST, g.key;
SELECT c.* FROM public.cities       c WHERE c.governorate_id = $1 AND c.is_active ORDER BY c.position NULLS LAST, c.key;
SELECT a.* FROM public.areas        a WHERE a.city_id        = $1 AND a.is_active ORDER BY a.position NULLS LAST, a.key;
```

The dependency-count helpers (`countCitiesInGovernorate`, `countAreasInCity`, `countAreasInGovernorate`) issue single `SELECT COUNT(*)` queries; these are called inline when the admin opens the delete-confirmation dialog so the count is current.

## 10. Failure mapping

Domain `LocationsFailure` enum (per Phase 7 `super_admin/domain/failures.dart` precedent):

| Failure | Source | UI message ARB key |
|---|---|---|
| `LocationsFailure.notAuthorized` | RLS deny (`42501`) or `current_user_has_permission` false | `notAuthorized` (existing Phase 6) |
| `LocationsFailure.keyAlreadyUsed` | `23505 unique_violation` on `key` | `keyAlreadyUsed` |
| `LocationsFailure.systemRowProtected` | trigger raise `42501` from `enforce_*_system_immutability` | `cannotDeleteSystemRow` |
| `LocationsFailure.foreignKeyViolation` | `23503` from Phase 10 `listings.city_id` (forward-stated) or other dependents | `cannotDeleteDueToListings` (added if/when Phase 10 ships) |
| `LocationsFailure.network` | transport failure | existing localized "network error" |
| `LocationsFailure.unknown` | any other DB error | existing localized "unexpected error" |
