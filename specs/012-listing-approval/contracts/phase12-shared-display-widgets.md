# Contract: Shared Listing-Display Widgets (Q8=A)

**Path**: `lib/shared/presentation/widgets/listing_display/`
**Implements**: FR-011, Q8=A
**Verifies**: SC-015 (Constitution IX-clean), SC-016 (Constitution V), SC-017 (Constitution VI), SC-032

## Directory contents (exactly 5 files)

1. `listing_gallery.dart`
2. `listing_price_block.dart`
3. `listing_location_block.dart`
4. `listing_amenities_block.dart`
5. `listing_description_block.dart`

## Widget contracts

### `ListingGallery`

```dart
class ListingGallery extends StatelessWidget {
  const ListingGallery({super.key, required this.media});
  final List<ListingMedia> media;

  // Renders a horizontal carousel of media items, ordered by `ordering ASC`
  // with `is_main=true` first. Each item is a 16:9 aspect-ratio card.
  // Image media: uses `cached_network_image` against the public URL from
  //   supabase.storage.from('listing-images').getPublicUrl(storagePath).
  // Video media: renders a static play-button overlay on a neutral background
  //   per Phase 11 FR-013 (Phase 11 does not generate video-frame thumbnails;
  //   tap → opens external player — DEFERRED to Phase 13).
  // External-link media: same play-button overlay; Phase 11 Q2=D defers UI.
  // Empty media list: renders a 16:9 placeholder card with localized
  //   "no media available" text.
}
```

### `ListingPriceBlock`

```dart
class ListingPriceBlock extends StatelessWidget {
  const ListingPriceBlock({
    super.key,
    required this.prices,
    required this.displayCurrency,
  });
  final List<ListingPrice> prices;
  final Currency displayCurrency;

  // Renders the primary price (where is_primary=true) prominently in the
  // displayCurrency via Phase 9's MoneyFormatter. If displayCurrency differs
  // from the publisher's stored currency, a secondary line shows the original
  // currency price ("originally 50,000 USD").
}
```

### `ListingLocationBlock`

```dart
class ListingLocationBlock extends StatelessWidget {
  const ListingLocationBlock({
    super.key,
    required this.governorate,
    required this.city,
    required this.area,
    this.addressText,
  });
  final Governorate governorate;
  final City city;
  final Area area;
  final String? addressText;

  // Renders governorate / city / area names joined with " / " (Phase 8 conventions)
  // plus optional address_text below. RTL-aware. NO map embed (Phase 15 owns map).
}
```

### `ListingAmenitiesBlock`

```dart
class ListingAmenitiesBlock extends StatelessWidget {
  const ListingAmenitiesBlock({super.key, required this.amenities});
  final Map<String, dynamic> amenities;

  // Renders amenities as a Wrap of chips. The `amenities` jsonb shape comes
  // from Phase 10's `listing_details.amenities` column; keys are amenity
  // names (e.g., "parking", "elevator", "furnished") mapping to bool or
  // numeric values. The widget renders only truthy keys as chips.
}
```

### `ListingDescriptionBlock`

```dart
class ListingDescriptionBlock extends StatelessWidget {
  const ListingDescriptionBlock({super.key, required this.description});
  final String description;

  // Renders the description as multi-line text using Theme.of(context)
  // .textTheme.bodyLarge with proper line-height for Arabic + English.
  // Long descriptions: truncate at ~10 lines with a "Read more" affordance
  //   that expands inline. Tap counts as a noop for the admin preview
  //   (no analytics; consumers can override via onReadMore parameter).
}
```

## Constitution compliance

- **IX-clean**: no widget imports `package:supabase_flutter`. The widgets accept domain entities only; the consumer's data source resolves entities.
- **V**: every user-visible string (placeholders, "Read more", "no media available", "originally X") flows through `AppLocalizations`. ARB keys: `media_gallery_empty`, `media_gallery_video_play`, `description_read_more`, `price_originally_was`.
- **VI**: all spacing / colors / typography from Phase 2 design tokens. No inline hex.

## Forward-state contract for Phase 13

Phase 13's public listing-details page MUST import these 5 widget files verbatim. Phase 13 ships its own BLoC (`ListingDetailsBloc`) that fetches the underlying Listing + ListingDetails + ListingPrices + ListingMedia + Governorate/City/Area rows AND passes them to the widgets. The widgets themselves do NOT need to be edited in Phase 13. Any Phase 13 enhancement (pinch-to-zoom on the gallery, share button, favorite button) is added as a CONSUMER concern — wrapping the widget in additional UI without modifying the widget's own implementation.

## Verification

```bash
ls lib/shared/presentation/widgets/listing_display/
# Expected:
# listing_gallery.dart
# listing_price_block.dart
# listing_location_block.dart
# listing_amenities_block.dart
# listing_description_block.dart

grep -r "package:supabase_flutter" lib/shared/presentation/widgets/listing_display/
# Expected: no matches.
```
