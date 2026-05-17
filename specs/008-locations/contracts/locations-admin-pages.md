# Contract: Locations Admin Pages

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Spec**: [../spec.md](../spec.md) US3/US4/US5, FR-012..FR-017

## Four pages

### 1. `LocationsListPage` (entry point — `/admin/locations`)

**Purpose**: Lists every governorate in the catalog with rolled-up city counts; entry point for admin governorate-CRUD.

**Layout contract**:
- AppBar title: ARB key `locationsListPageTitle` ("Governorates").
- Floating action: "Add governorate" (ARB key `addGovernorateButton`).
- Body: a scrollable list of `governorate_card` widgets, one per governorate row, ordered by `position NULLS LAST, key`.
- Each card shows: localized `display_name`, city-count summary, `is_system` badge (if true), `is_active=false` "Hidden" badge (if applicable), and a contextual menu / tap target.
- Tap a card → navigate to `/admin/locations/:governorateId`.
- Contextual menu on a `is_system=false` card: Edit, Deactivate, Delete.
- Contextual menu on a `is_system=true` card: Edit, Deactivate. **No Delete affordance**.

**BLoC**: `LocationsListBloc` (data-model.md §6.4).

**Verification**: US3.1, US3.7 acceptance scenarios + SC-017 system-row affordance check.

### 2. `GovernorateDetailPage` (`/admin/locations/:governorateId`)

**Purpose**: Lists cities scoped to the picked governorate.

**Layout contract**:
- AppBar title: localized `display_name` of the governorate.
- Header: governorate metadata (key slug, is_system badge, is_active state).
- Floating action: "Add city" (ARB key `addCityButton`).
- Body: a scrollable list of `city_card` widgets ordered by `position NULLS LAST, key`.
- Each card shows: localized `display_name`, area-count summary, `is_system` badge, `Hidden` badge, contextual menu.
- Tap a card → navigate to `/admin/locations/:governorateId/cities/:cityId`.

**BLoC**: `GovernorateDetailBloc`.

**Verification**: US4 acceptance scenarios + SC-017 city protection check.

### 3. `CityDetailPage` (`/admin/locations/:governorateId/cities/:cityId`)

**Purpose**: Lists areas scoped to the picked city.

**Layout contract**:
- AppBar title: localized `display_name` of the city.
- Header: breadcrumb "Governorate → City" with both localized names.
- Floating action: "Add area" (ARB key `addAreaButton`).
- Body: a scrollable list of `area_card` widgets ordered by `position NULLS LAST, key`.
- Each card shows: localized `display_name`, `Hidden` badge, contextual menu with Edit / Deactivate / Delete (areas have no `is_system`).

**BLoC**: `CityDetailBloc`.

**Verification**: US5 acceptance scenarios.

### 4. `LocationFormPage` (`/admin/locations/form`)

**Purpose**: Reusable modal/route for add and edit across the three levels (governorate / city / area). Mode and level are passed as query parameters: `mode=add|edit`, `level=governorate|city|area`, optional `id` (edit) and `parentId` (add child).

**Form fields**:

- `key` — `TextFormField`. Lowercase; auto-trim; refused on duplicate (within scope: global for governorate, per-governorate for city, per-city for area). On edit of an `is_system=true` row, this field is rendered read-only (the immutability trigger refuses key UPDATE).
- `display_name` — `BilingualDisplayNameField` widget (two inputs: `ar` required, `en` optional, R-19).
- `description` — optional `TextFormField` (multi-line). May also be bilingual; v1 ships as a single optional text area accepting either locale's text (the JSONB column holds `{"text": "..."}` or the user-typed JSON). Implementation simplifies: a single field per locale, both optional.
- `position` — optional integer field.
- `is_active` — toggle, defaults to true.

**Save contract**:
- On valid submit, dispatches to the appropriate use case (`Create*` or `Update*`).
- Save success → returns to the previous page; the parent BLoC's list state refreshes.
- Save failure (RLS deny, unique violation, immutability trigger) → reset form to dirty state, surface the appropriate localized error via the `LocationsFailure` → ARB-key map (data-model.md §10).

**BLoC**: `LocationFormBloc`.

**Verification**: US3.2-US3.6, US4.2-US4.4, US5.2-US5.3 acceptance scenarios + SC-016 form-validation checks.

## Cross-cutting contracts

### Delete confirmation dialog (Clarifications Q2)

When the admin taps Delete on a governorate or city, the `delete_confirmation_dialog` widget MUST:

1. Show the localized title (ARB key `deleteConfirmTitle`).
2. For a governorate with cities: show "{cityCount} cities and {areaCount} areas will also be deleted" (ARB key `deleteConfirmGovernorateWithDeps`). The counts come from `countCitiesInGovernorate` + `countAreasInGovernorate` repository helpers.
3. For a city with areas: show "{areaCount} areas will also be deleted" (`deleteConfirmCityWithDeps`).
4. For an area (no dependents): show a plain confirmation message.
5. Require explicit Confirm tap to proceed; Cancel dismisses.

### System-row affordance hiding (FR-015, SC-017)

The list pages MUST:

- Hide the Delete affordance on `is_system=true` rows (governorates list + cities list within a governorate detail page).
- Pass `readOnly: true` to the `key` field in the form when editing an `is_system=true` row.
- Render a `system_row_badge` widget on each `is_system=true` row.

### Form validation (FR-016, SC-016)

- Empty `key` → `keyRequired` ARB key.
- Duplicate `key` within scope → `keyAlreadyUsed`.
- Empty `display_name->>'ar'` → `arabicNameRequired`.
- All validation runs client-side AND is re-checked server-side (the CHECK constraints on the tables + the UNIQUE constraints).

### Constitution traceability

- Constitution IV: BLoC + use case + repository three-layer split for every page.
- Constitution V: every chrome string flows through `AppLocalizations`.
- Constitution VI: every visual primitive comes from Phase 2 design tokens.
- Constitution VII: every write surface gated by `PermissionChecker.has('locations.manage')` client-side + RLS server-side.
- Constitution VIII: no publisher-identity surface touched.
- Constitution IX: no Supabase imports anywhere in the four pages or their BLoCs.
