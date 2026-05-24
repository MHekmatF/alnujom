# Contract: Phase 14 `SearchFilterSheet` Widget

**File**: `lib/features/search/presentation/widgets/search_filter_sheet.dart`
**Sub-Phase**: E (Wave 2)
**Created**: 2026-05-24

---

## Purpose

`SearchFilterSheet` is the modal bottom sheet that exposes all nine filter dimensions to the user. It is opened from `SearchPage` when the user taps the "Filters" button. It returns a new `FilterState` via callback when the user taps "Apply".

---

## Widget Signature

```dart
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  final FilterState initialFilters;
  final ValueChanged<FilterState> onApply;
}
```

- `initialFilters`: The currently active `FilterState` from `SearchBloc.state.filters`. Pre-populates all filter controls on open.
- `onApply(FilterState newFilters)`: Called when the user taps "Apply". The caller (`SearchPage`) dispatches `SearchFiltersApplied(newFilters)` to `SearchBloc`.

---

## Composition Contract

```
showModalBottomSheet(
  isScrollControlled: true,
  context: context,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    maxChildSize: 0.92,
    minChildSize: 0.4,
    expand: false,
    builder: (_, scrollController) => SingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: EdgeInsetsDirectional.all(16),
        child: Column(
          children: [
            _SheetHandle(),                          // drag handle
            _SheetTitle('search_filter_sheet_title') // ARB key
            _PurposeSection(),                       // ChoiceChip or DropdownButton
            _PropertyTypeSection(),                  // ChoiceChip or DropdownButton
            _LocationSection(),                      // cascading dropdowns
            _PriceRangeSection(),                    // PriceRangeInput widget
            _RoomsSection(),                         // SegmentedButton + stepper
            _BathroomsSection(),                     // SegmentedButton + stepper
            _AreaSizeSection(),                      // min/max TextFormField pair
            _ActionRow(onApply, onReset),            // Apply + Reset buttons
          ],
        ),
      ),
    ),
  ),
)
```

---

## Filter Dimension Contracts

### Purpose (`_PurposeSection`)
- Displays all `ListingPurpose` enum values as selectable chips or a dropdown.
- Single-select or null (no purpose filter active).
- Maps to `FilterState.purpose`.

### Property Type (`_PropertyTypeSection`)
- Displays all `PropertyType` enum values.
- Single-select or null.
- Maps to `FilterState.propertyType`.

### Location (`_LocationSection`)
- Three cascading `DropdownButton` widgets: Governorate → City → Area.
- Governorates loaded once on sheet open via Phase 8 `LocationRepository` (R-83).
- Cities loaded when governorate selection changes.
- Areas loaded when city selection changes.
- When governorate changes: city selection is cleared, area selection is cleared.
- When city changes: area selection is cleared.
- Hints: `search_filter_governorate_hint`, `search_filter_city_hint`, `search_filter_area_hint` ARB keys.

### Price Range (`_PriceRangeSection`)
- Contains `PriceRangeInput` widget (separate file `price_range_input.dart`).
- Currency selector (DropdownButton populated from Phase 9 `CurrencyRepository`).
- If no exchange rate for selected currency: displays `search_filter_price_no_exchange_rate` message and disables min/max inputs.
- Maps to `FilterState.priceMin`, `FilterState.priceMax`, `FilterState.priceCurrency`.

### Rooms (`_RoomsSection`)
- `SegmentedButton<CountFilterMode>` with two segments:
  - Segment 0 label: `search_filter_rooms_exactly` ARB key → "تماماً / Exactly"
  - Segment 1 label: `search_filter_rooms_at_least` ARB key → "على الأقل / At least"
- Numeric stepper row (–, count text, +) below the SegmentedButton.
- When count is null: dimension is inactive; tapping + activates it at count = 1.
- Tapping – when count == 1: sets count to null (deactivates dimension).
- Maps to `FilterState.rooms`, `FilterState.roomsMode`.

### Bathrooms (`_BathroomsSection`)
- Identical pattern to Rooms, using `search_filter_bathrooms_label` ARB key.
- Maps to `FilterState.bathrooms`, `FilterState.bathroomsMode`.

### Area Size (`_AreaSizeSection`)
- Two `TextFormField` widgets (min and max), numeric keyboard.
- No SegmentedButton — area size always uses a min/max range.
- Maps to `FilterState.areaSizeMin`, `FilterState.areaSizeMax`.

---

## Action Row Contract

### Apply Button
- Label: `search_filter_apply` ARB key.
- On tap:
  1. Validates price range (min ≤ max via `PriceRangeInput`'s own validator).
  2. If valid: calls `onApply(currentLocalFilterState)` and `Navigator.pop(context)`.
  3. If invalid: shows inline error in `PriceRangeInput`; does NOT close sheet.

### Reset Button
- Label: `search_filter_reset` ARB key.
- On tap: resets ALL filter controls to empty state (`FilterState.empty`).
- Sheet stays open after reset (per spec US2 scenario 9: "sheet remains open for further edits").
- Does NOT dispatch to `SearchBloc` — reset only affects local sheet state.
- Calling `onApply(FilterState.empty)` only happens if the user then explicitly taps Apply.

---

## `PriceRangeInput` Contract

**File**: `lib/features/search/presentation/widgets/price_range_input.dart`

```dart
class PriceRangeInput extends StatelessWidget {
  const PriceRangeInput({
    super.key,
    required this.minController,
    required this.maxController,
    required this.formKey,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final GlobalKey<FormState> formKey;
}
```

- Two `TextFormField` widgets side by side, numeric keyboard.
- `validator` on max field: if both fields non-empty and `double.parse(min) > double.parse(max)`, returns `search_filter_price_min_max_error` ARB string.
- Validation is triggered by the Apply button's `formKey.currentState!.validate()` call.

---

## RTL / LTR Behavior

- All `Padding` uses `EdgeInsetsDirectional` (not `EdgeInsets`).
- `SegmentedButton` is RTL-aware by default in Material 3.
- Cascade dropdowns use `TextDirection.inherit` — they adapt to the app locale.
- The sheet title and section labels use `TextAlign.start` (aligns right in RTL, left in LTR).

---

## Dependency Summary

| Dependency | From | Used For |
|------------|------|---------|
| `FilterState` | `lib/features/search/domain/entities/filter_state.dart` | Constructor + callback type |
| `CountFilterMode` | `lib/features/search/domain/entities/count_filter_mode.dart` | SegmentedButton value type |
| `LocationRepository` | `lib/features/locations/domain/repositories/location_repository.dart` (Phase 8) | Cascading location data |
| `CurrencyRepository` | `lib/features/currencies/domain/repositories/currency_repository.dart` (Phase 9) | Currency selector data |
| ARB keys | `app_ar.arb`, `app_en.arb` (Sub-Phase C) | All user-visible strings |
