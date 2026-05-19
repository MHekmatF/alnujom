# Contract: Area-Centroid Auto-Fill (FR-013a / Q2)

**Owner**: Phase 10, `lib/features/listing_form/domain/usecases/derive_area_centroid.dart` + the location step's BLoC handler.
**Consumers**: every Phase 10 form draft that completes the location step.

## Obligations

When the publisher commits the location step (taps "Continue" from `StepLocation`), the BLoC MUST:

1. Read `centroid_lat` and `centroid_lng` from `public.areas` for the picked `area_id`.
2. Write the centroid values to the draft's `listings.latitude` and `listings.longitude` columns alongside the location step's other fields (governorate_id, city_id, area_id, address_text). This is part of the per-step auto-save.
3. NOT expose the raw lat/lng numbers as visible form fields. The publisher cannot see or edit the coordinates in Phase 10.
4. If the centroid lookup returns NULL (should never happen post-seed; defensive check), BLOCK the step transition with a localized "this area is missing map coordinates; please contact admin" error. The publisher cannot proceed past the location step.

The `DeriveAreaCentroid` use case is the canonical helper:

```dart
class DeriveAreaCentroid {
  final LocationsRepository locationsRepository;  // Phase 8 repository
  Future<AreaCentroid> call(String areaId);
}

class AreaCentroid extends Equatable {
  final double latitude;
  final double longitude;
}
```

The repository call MUST be a single SELECT against `public.areas.centroid_lat`/`centroid_lng`; no external geocoder, no client-side static map, no governorate-fallback path (R-07 alternatives rejected).

## Verification

```
On the device:
1. Open the form, advance to the location step.
2. Pick governorate=Damascus, city=Damascus, area=Al-Maliki.
3. Tap Continue.
4. From the desktop: SELECT latitude, longitude FROM public.listings WHERE id=<draft_id>.
   Expected: latitude≈33.5102, longitude≈36.2913 (matching the area's centroid seed).
5. Open the draft again, navigate back to the location step.
6. Verify there are NO lat/lng input fields visible in the UI.
7. Verify changing the area picker re-runs the auto-fill on next Continue.
```

## Forbidden

- Exposing raw lat/lng as form fields in Phase 10 (Q2 lock; Phase 15 owns the pin-drop edit).
- Permitting an area pick whose row carries NULL centroids (defensive block).
- Calling an external geocoder at form time.
- Storing centroid values in a Flutter-side static map (R-07 path-ii rejected).
- Falling back to governorate centroid when area centroid is missing (R-07 path-iii rejected; instead block the step).
