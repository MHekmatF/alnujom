# Contract: ListingDetailsPage Composition

**Path**: `lib/features/listing_details/presentation/pages/listing_details_page.dart`
**Implements**: FR-021, FR-022, FR-026, FR-027
**Verifies**: SC-004, SC-005, SC-016, SC-027, SC-030, SC-033

## Composition order (top-to-bottom)

1. `AppBar`:
   - **Start side**: Back arrow `IconButton(icon: Icons.arrow_back, onPressed: <Q4=D conditional handler>)` per FR-021 + Q4=D. NO share icon (Q2=A means share lives only in the per-listing-action block, NOT as an app-bar affordance).
   - **Center / End**: Optional listing title (truncated) OR empty per Phase 2 token guidance.

2. `ListingGallery` — imported VERBATIM from `lib/shared/presentation/widgets/listing_display/listing_gallery.dart` (Phase 12 Q8=A). Phase 13 wraps the widget with a video-tap callback per FR-027 (see "Video tap wiring" below).

3. Title block: `Text(state.listing.title, style: Theme.of(context).textTheme.headlineSmall)` per Phase 2 typography. RTL-aware via Flutter default.

4. `ListingPriceBlock` — imported VERBATIM from `lib/shared/presentation/widgets/listing_display/listing_price_block.dart`. Consumes `state.prices` + the user's `display_currency` (from Phase 9 `user_preferences`).

5. `ListingLocationBlock` — imported VERBATIM from `lib/shared/presentation/widgets/listing_display/listing_location_block.dart`. Consumes `state.governorate` + `state.city` + `state.area` + optional `state.listing.addressText`. Respects `location_visibility` per the data-source contract.

6. `_ContactBlock` (NEW Phase 13 widget):
   - Three Phase-2-token-styled `OutlinedButton.icon` widgets:
     - `cta_call` label + `Icons.phone` icon → tap shows `contact_call_coming_soon` snackbar per Q2=A.
     - `cta_whatsapp` label + WhatsApp icon (Phase 2 token or `Icons.chat`) → tap shows `contact_whatsapp_coming_soon` snackbar per Q2=A.
     - `cta_send_inquiry` label + `Icons.email` icon → tap shows `contact_inquiry_coming_soon` snackbar per Q2=A.
   - NO `url_launcher.launch('tel:...')` / `wa.me/` / share-sheet wiring. Plan-time grep confirms per SC-030.

7. `ListingAmenitiesBlock` — imported VERBATIM. Consumes `state.details.amenities`. Auto-hides if amenities `jsonb` is empty.

8. `ListingDescriptionBlock` — imported VERBATIM. Consumes `state.details.description`. Auto-truncates at ~10 lines with "Read more" inline expansion.

9. `_PerListingActionBlock` (NEW Phase 13 widget):
   - Three Phase-2-token-styled CTAs (icons + labels per Phase 2):
     - `cta_favorite` + heart icon → tap shows `action_favorite_coming_soon` snackbar per Q2=A.
     - `cta_share` + share icon → tap shows `action_share_coming_soon` snackbar per Q2=A.
     - `cta_report` + flag icon → tap shows `action_report_coming_soon` snackbar per Q2=A.

## Page-body wrapper

```dart
return PopScope(
  canPop: false,  // We handle the pop ourselves per Q4=D.
  onPopInvoked: (didPop) {
    if (didPop) return;
    _handleBack();
  },
  child: Scaffold(
    appBar: AppBar(
      leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: _handleBack),
      // ...
    ),
    body: BlocBuilder<ListingDetailsBloc, ListingDetailsState>(
      builder: (context, state) {
        switch (state.status) {
          case ListingDetailsStatus.loading:
            return Center(child: CircularProgressIndicator());
          case ListingDetailsStatus.notFound:
            return _NotFoundView();  // FR-024
          case ListingDetailsStatus.error:
            return _ErrorView(onRetry: () => context.read<ListingDetailsBloc>().add(RetryRequested()));  // FR-025
          case ListingDetailsStatus.success:
            return _SuccessBody(state);  // composition 2–9 above
          // ...
        }
      },
    ),
  ),
);

void _handleBack() {
  // Q4=D conditional pattern.
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go(AppRoutes.home);
  }
}
```

## Video tap wiring (FR-027)

The `ListingGallery` widget (Phase 12 Q8=A) accepts a tap-handler callback per its contract. Phase 13's wrapping passes:

```dart
ListingGallery(
  media: state.media,
  onVideoTap: (videoMedia) async {
    final url = _client.storage.from('listing-images').getPublicUrl(videoMedia.storagePath);
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  },
)
```

(If Phase 12's `ListingGallery` widget signature does NOT include an `onVideoTap` callback — plan-time inspection at implementation — the gallery's existing tap behavior is preserved and Phase 13 wraps via an `InkWell` overlay OR the gallery widget is amended in a Phase 13 patch per Phase 12 forward-state contract clarification.)

## Constitution compliance

Identical to HomePage contract: V, VI, IX, XI. Plus:

- **Q8=A widget reuse contract**: NO edits to the five widget files in `lib/shared/presentation/widgets/listing_display/`. Plan-time `git diff` confirms per SC-016.
- **R-53 BLoC ownership boundary**: `ListingDetailsBloc` independent of Phase 12's `ListingPreviewBloc`. No shared BLoC import path per SC-016.
