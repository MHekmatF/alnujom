import 'package:injectable/injectable.dart';

import '../entities/listing_form_state.dart';
import '../repositories/listings_repository.dart';

@injectable
class SaveFormStep {
  const SaveFormStep(this._repository);

  final ListingsRepository _repository;

  Future<void> call(ListingFormState state, ListingFormStep step) async {
    final listing = state.draftListing;
    if (listing == null) {
      throw StateError('SaveFormStep called before draft was loaded');
    }
    switch (step) {
      case ListingFormStep.basics:
        await _repository.saveBasicsStep(
          listingId: listing.id,
          title: listing.title,
          purpose: listing.purpose,
          propertyType: listing.propertyType,
          agencyId: listing.agencyId,
        );
      case ListingFormStep.location:
        if (listing.governorateId == null ||
            listing.cityId == null ||
            listing.areaId == null ||
            listing.latitude == null ||
            listing.longitude == null) {
          throw StateError('Location step is missing required fields');
        }
        await _repository.saveLocationStep(
          listingId: listing.id,
          governorateId: listing.governorateId!,
          cityId: listing.cityId!,
          areaId: listing.areaId!,
          addressText: listing.addressText ?? '',
          latitude: listing.latitude!,
          longitude: listing.longitude!,
        );
      case ListingFormStep.details:
        final details = state.draftDetails;
        await _repository.saveDetailsStep(
          listingId: listing.id,
          areaSize: listing.areaSize,
          rooms: listing.rooms,
          bathrooms: listing.bathrooms,
          floor: listing.floor,
          description: details?.description,
          amenities: details?.amenities ?? const <String>[],
          yearBuilt: details?.yearBuilt,
          furnished: details?.furnished,
          parking: details?.parking,
        );
      case ListingFormStep.prices:
        final price = state.draftPrice;
        if (price == null) {
          throw StateError('Prices step is missing currency or amount');
        }
        await _repository.savePricesStep(
          listingId: listing.id,
          currencyCode: price.currencyCode,
          amount: price.amount,
        );
      case ListingFormStep.visibility:
        await _repository.saveVisibilityStep(
          listingId: listing.id,
          locationVisibility: listing.locationVisibility,
          contactNameVisibility: listing.contactNameVisibility,
          hideUntil: state.draftVisibility?.hideUntil,
          phone: listing.phone,
          whatsapp: listing.whatsapp,
        );
      case ListingFormStep.media:
      case ListingFormStep.review:
        // No-op: media is Phase 11; review is rendered, not saved.
        return;
    }
  }
}
