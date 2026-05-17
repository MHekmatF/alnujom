# Contract: LocationPicker Widget

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Spec**: [../spec.md](../spec.md) US6, FR-018..FR-022

## Public API

The widget is exported from `lib/features/locations/presentation/widgets/location_picker.dart`:

```dart
class LocationPicker extends StatelessWidget {
  const LocationPicker({
    super.key,
    this.initialSelection,
    required this.onChanged,
    this.required = false,
    this.areaRequired = false,
  });

  final LocationPickerSelection? initialSelection;
  final ValueChanged<LocationPickerSelection?> onChanged;
  final bool required;       // whether the parent form treats governorate+city as required
  final bool areaRequired;   // whether the parent form requires area; default false (FR-019)
}
```

The widget MUST emit `LocationPickerSelection` (a pure-Dart domain entity — `data-model.md §6.1`) whenever any of the three levels changes, or `null` if the user clears the picker. The `LocationPickerSelection` carries `governorateId`, `cityId`, and an OPTIONAL `areaId`.

## Behavior contract

1. **Mount**: on first build, the widget MUST emit an internal `MountRequested` event to its `LocationPickerBloc`, which loads the active governorate list (`SELECT * FROM public.governorates WHERE is_active = true ORDER BY position NULLS LAST, key`). Loading state is reflected in the governorate control (spinner or disabled state); the city and area controls are disabled.
2. **Governorate picked**: emits `GovernoratePicked(id)`; loads cities for that governorate (`WHERE governorate_id = $1 AND is_active = true`); resets city and area selections; emits `onChanged(null)` because the selection is incomplete.
3. **City picked**: emits `CityPicked(id)`; loads areas for that city; resets area selection; emits `onChanged(LocationPickerSelection(governorateId, cityId, null))` because the selection is now committable (area is optional per FR-019).
4. **Area picked**: emits `AreaPicked(id)`; emits `onChanged(LocationPickerSelection(governorateId, cityId, areaId))`.
5. **Area cleared by user** (the area control supports a "skip" affordance): emits `AreaPicked(null)`; emits `onChanged(LocationPickerSelection(governorateId, cityId, null))`.
6. **Empty area branch**: if the picked city has zero active areas, the widget MUST render a localized "no areas yet — leave blank" affordance (`locationPickerNoAreasYet` ARB key); the area control is effectively a no-op; `onChanged` is called with `areaId: null` automatically (no user action needed for area).
7. **Locale toggle mid-selection**: when `Localizations.localeOf(context)` changes, the widget MUST re-render every label in the new locale without losing the user's selection. The `LocationPickerBloc` MUST NOT re-fetch in response to a locale change.
8. **Cache invariant** (R-20): the widget MUST NOT maintain a long-lived client-side cache. Each mount re-fetches from the repository. Mid-mount cascade transitions DO re-fetch (one transition = one round-trip).

## Filtering contract (FR-020, R-17)

The widget MUST request `includeInactive: false` on every call to the repository. The data source applies the `is_active = true` filter at the query level. Inactive rows are invisible to the picker even if they exist in the database.

## Locale fallback chain (FR-021, R-18)

Every row label rendered by the widget MUST use the `localizedName(Locale)` helper from the domain entity, which produces:

1. Active locale's `display_name` value (trimmed, non-empty).
2. The other locale's `display_name` value.
3. The row's `key` slug as a last-resort label.

No row ever renders blank.

## Visual & layout contract (Constitution VI)

The three controls MUST consume Phase 2 design tokens for spacing, color, and typography. The widget MUST be layout-direction-aware: in RTL locales, the cascade order reads right-to-left. The widget MUST work on the reference Infinix Note 8 (6.78" portrait) with one-handed reach.

## Localization contract (FR-023, Constitution V)

The ARB keys consumed by the widget:

- `locationPickerSelectGovernorate` — placeholder for the governorate control.
- `locationPickerSelectCity` — placeholder for the city control.
- `locationPickerSelectArea` — placeholder for the area control (carries the parenthetical "optional").
- `locationPickerNoAreasYet` — empty-branch message.
- `locationsLoadFailed` — error state.

All keys ship in both `app_ar.arb` and `app_en.arb` in the same commit.

## Domain-layer purity contract (Constitution IX)

The widget MUST consume the BLoC, the BLoC MUST consume the use cases, the use cases MUST consume the abstract `LocationsRepository`. `package:supabase_flutter` MUST NOT be imported anywhere in `lib/features/locations/domain/` or `lib/features/locations/presentation/widgets/location_picker.dart`. Compliance is verified by `grep -R "package:supabase_flutter" lib/features/locations/{domain,presentation}` returning zero results.

## Verification

Manual device walk steps (full recipe in `quickstart.md`):

1. Mount the picker on the smoke-test screen.
2. Confirm governorate dropdown lists all 14 governorates in the editorially-ordered sequence.
3. Tap Damascus → confirm city dropdown populates with Damascus's cities.
4. Tap a Damascus city → confirm area dropdown populates OR the no-areas-yet affordance appears.
5. Tap an area → confirm `onChanged` emits the full `{governorateId, cityId, areaId}` triple.
6. Toggle locale ar↔en → confirm labels flip; selection state is preserved.
7. From the admin pages (US3/US4/US5), deactivate a city → return to the picker → confirm the deactivated city is absent from the dropdown.
8. From the admin pages, rename a governorate's English display_name → return to the picker on a different device → confirm the rename appears within 5 seconds.

## Constitution traceability

- Constitution IV (Clean Architecture Flutter): three-layer split is preserved.
- Constitution V (Arabic-First Localization): ARB keys + locale fallback chain.
- Constitution VI (Theme System & Design Tokens): no inline magic numbers.
- Constitution IX (Future Backend Portability): no Supabase imports in widget code.
- Constitution XI (Android-First MVP): sized for the reference Infinix Note 8.
