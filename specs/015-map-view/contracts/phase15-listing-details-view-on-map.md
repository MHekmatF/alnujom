# Contract: Listing details "View on map" affordance

**Phase**: 15 — Map View
**Owner**: Sub-Phase G2 (entry-point wiring)
**File**: `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE only)
**Spec refs**: FR-007 (entry point b), FR-020, US5, Q1=A clarification
**Phase 12 contract preserved**: `ListingLocationBlock` (shared widget at `lib/shared/presentation/widgets/listing_display/listing_location_block.dart`) is NOT modified — the affordance is added as a CONSUMER wrap

## Insertion point in `_SuccessBody`

Locate the existing `ListingLocationBlock` invocation (line ~178–185 of `listing_details_page.dart`):

```dart
// BEFORE:
// 5. Location block — Phase 12 Q8=A VERBATIM
ListingLocationBlock(
  governorate: aggregate.governorate,
  city: aggregate.city,
  area: aggregate.area,
  addressText: aggregate.listing.addressText,
),

// AFTER (Phase 15 G2 addition):
// 5. Location block — Phase 12 Q8=A VERBATIM (widget itself unmodified)
ListingLocationBlock(
  governorate: aggregate.governorate,
  city: aggregate.city,
  area: aggregate.area,
  addressText: aggregate.listing.addressText,
),
// 5b. Phase 15 G2: "View on map" affordance — consumer wrap.
//     Rendered only when the listing's location_visibility permits map presence.
if (_canShowOnMap(aggregate.listing))
  Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md,
    ),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => context.go(
          AppRoutes.map,
          extra: MapEntryFromListing(
            listingId: aggregate.listing.id,
            position: MarkerCoordinates(
              latitude: aggregate.listing.latitude!,
              longitude: aggregate.listing.longitude!,
            ),
          ),
        ),
        icon: const Icon(Icons.map_outlined),
        label: Text(l10n.listing_details_view_on_map_action),
      ),
    ),
  ),
```

The `_canShowOnMap` helper (added to the same page file):

```dart
bool _canShowOnMap(Listing listing) {
  return listing.locationVisibility == LocationVisibility.exact ||
         listing.locationVisibility == LocationVisibility.approximate;
}
```

## Behavioral contract

1. **Conditional render**: The button MUST appear ONLY when `listing.locationVisibility` is `exact` or `approximate`. For `hidden` and `admin_only` listings, the button MUST be omitted from the widget tree entirely (not rendered as disabled).
2. **Phase 12 widget purity**: The shared `ListingLocationBlock` at `lib/shared/presentation/widgets/listing_display/listing_location_block.dart` MUST NOT be modified. No new callback parameters, no new fields. The button is a sibling widget in the consumer's column.
3. **Navigation**: `onPressed` calls `context.go(AppRoutes.map, extra: MapEntryFromListing(...))` carrying the listing's id and coordinates. The map opens centered on this listing's marker per FR-015a.
4. **Null-bang safety**: The `aggregate.listing.latitude!` and `aggregate.listing.longitude!` assertions are safe because Phase 10 Q2=A auto-populates lat/lng from the area centroid on submit, AND the `_canShowOnMap` check above guarantees the visibility tier permits map presence (which in turn means the columns were set per the Phase 10 contract). If a defensive `?? aggregate.area.centroidLat` fallback is desired, plan-time research codifies — for v1, the null-bang is acceptable per Phase 10's invariant.
5. **Localization**: Button label flows through `l10n.listing_details_view_on_map_action` (e.g., "اعرض على الخريطة" / "View on map").
6. **Theming**: `TextButton.icon` consumes default Phase 2 button theme; no inline styling. Padding uses `AppSpacing` tokens.
7. **RTL**: `EdgeInsetsDirectional` + `AlignmentDirectional.centerStart` ensure the button aligns to the start (right in RTL, left in LTR).

## Acceptance test (manual)

- Navigate to a listing details page for an approved listing with `location_visibility = 'exact'`. Confirm "View on map" button appears below the location block. Tap. Confirm map opens centered on the listing's marker; the marker is visually selected (popover open). Press back. Confirm return to the details page.
- Navigate to a listing details page for an approved listing with `location_visibility = 'approximate'`. Confirm button appears; tap; confirm map opens centered on the jittered marker (which sits within the area, not at the publisher's true address).
- Navigate to a listing details page for an approved listing with `location_visibility = 'hidden'`. Confirm "View on map" button is NOT present in the tree.
- Repeat for `location_visibility = 'admin_only'` (admin context — Phase 12 preview page uses the same shared widget). Confirm button is NOT present.
