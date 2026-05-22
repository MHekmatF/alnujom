import 'package:injectable/injectable.dart';

import '../entities/listing.dart';
import '../entities/listing_form_state.dart';

/// Client-side mirror of the server-side Q1 Full required-field validation
/// from `data-model.md § RPC § submit_listing`. The server is the source
/// of truth; this exists so the UI can pre-emptively render a localized
/// missing-fields list without round-tripping.
@injectable
class ValidateSubmitPayload {
  const ValidateSubmitPayload();

  ({bool ok, List<String> missingFields}) call(ListingFormState state) {
    final missing = <String>[];
    final listing = state.draftListing;
    final price = state.draftPrice;

    if (listing == null) {
      return (ok: false, missingFields: const ['listings']);
    }

    if (listing.title.trim().isEmpty) {
      missing.add('listings.title');
    }
    // purpose + property_type + location_visibility + contact_name_visibility
    // are non-nullable enums in the entity — server enforces the column-level
    // NOT NULL; client adds no extra check.
    if (listing.governorateId == null || listing.governorateId!.isEmpty) {
      missing.add('listings.governorate_id');
    }
    if (listing.cityId == null || listing.cityId!.isEmpty) {
      missing.add('listings.city_id');
    }
    if (listing.areaId == null || listing.areaId!.isEmpty) {
      missing.add('listings.area_id');
    }
    if (listing.addressText == null || listing.addressText!.trim().isEmpty) {
      missing.add('listings.address_text');
    }
    if (listing.areaSize == null || listing.areaSize! <= 0) {
      missing.add('listings.area_size');
    }
    if (listing.propertyType.isResidential) {
      if (listing.rooms == null || listing.rooms! < 0) {
        missing.add('listings.rooms');
      }
      if (listing.bathrooms == null || listing.bathrooms! < 0) {
        missing.add('listings.bathrooms');
      }
    }
    final hasPhone = listing.phone != null && listing.phone!.trim().isNotEmpty;
    final hasWa =
        listing.whatsapp != null && listing.whatsapp!.trim().isNotEmpty;
    if (!hasPhone && !hasWa) {
      missing.add('listings.phone_or_whatsapp');
    }
    if (price == null) {
      missing.add('listing_prices.primary');
    }

    return (ok: missing.isEmpty, missingFields: missing);
  }
}
