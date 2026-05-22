import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_form_state.dart';

sealed class ListingFormEvent extends Equatable {
  const ListingFormEvent();

  @override
  List<Object?> get props => const [];
}

/// On mount, the page asks the bloc to load (edit mode) or create (create
/// mode) a draft owned by the signed-in publisher.
class LoadOrCreateDraftRequested extends ListingFormEvent {
  const LoadOrCreateDraftRequested({this.listingId});

  /// If provided, the bloc tries to load that exact listing (edit mode).
  /// Otherwise it falls back to the publisher's most-recent draft or
  /// inserts a new one (create mode).
  final String? listingId;

  @override
  List<Object?> get props => [listingId];
}

/// Generic field-change event. The bloc applies the typed update to its
/// in-memory state without persisting. Per R-13, persistence happens at
/// step transitions, not on every keystroke.
class FieldChanged extends ListingFormEvent {
  const FieldChanged.title(this.value) : field = ListingFormField.title;
  const FieldChanged.purpose(this.value) : field = ListingFormField.purpose;
  const FieldChanged.propertyType(this.value)
    : field = ListingFormField.propertyType;
  const FieldChanged.governorateId(this.value)
    : field = ListingFormField.governorateId;
  const FieldChanged.cityId(this.value) : field = ListingFormField.cityId;
  const FieldChanged.areaId(this.value) : field = ListingFormField.areaId;
  const FieldChanged.addressText(this.value)
    : field = ListingFormField.addressText;
  const FieldChanged.areaSize(this.value) : field = ListingFormField.areaSize;
  const FieldChanged.rooms(this.value) : field = ListingFormField.rooms;
  const FieldChanged.bathrooms(this.value) : field = ListingFormField.bathrooms;
  const FieldChanged.floor(this.value) : field = ListingFormField.floor;
  const FieldChanged.description(this.value)
    : field = ListingFormField.description;
  const FieldChanged.amenities(this.value) : field = ListingFormField.amenities;
  const FieldChanged.yearBuilt(this.value) : field = ListingFormField.yearBuilt;
  const FieldChanged.furnished(this.value) : field = ListingFormField.furnished;
  const FieldChanged.parking(this.value) : field = ListingFormField.parking;
  const FieldChanged.priceCurrencyCode(this.value)
    : field = ListingFormField.priceCurrencyCode;
  const FieldChanged.priceAmount(this.value)
    : field = ListingFormField.priceAmount;
  const FieldChanged.locationVisibility(this.value)
    : field = ListingFormField.locationVisibility;
  const FieldChanged.contactNameVisibility(this.value)
    : field = ListingFormField.contactNameVisibility;
  const FieldChanged.phone(this.value) : field = ListingFormField.phone;
  const FieldChanged.whatsapp(this.value) : field = ListingFormField.whatsapp;
  const FieldChanged.hideUntil(this.value) : field = ListingFormField.hideUntil;

  final ListingFormField field;
  final Object? value;

  @override
  List<Object?> get props => [field, value];
}

/// Save the current step and advance to the next. Auto-saves per R-13.
class SaveStepAndContinue extends ListingFormEvent {
  const SaveStepAndContinue();
}

/// Save the current step and return to the previous page (publisher
/// dashboard or my-listings). No-op-save when current step is media/review.
class SaveStepAndExit extends ListingFormEvent {
  const SaveStepAndExit();
}

/// Direct step navigation (used by the Review page's "Edit step N" CTAs and
/// the SubmitFailureDialog's "Jump to step" buttons).
class JumpToStep extends ListingFormEvent {
  const JumpToStep(this.step);

  final ListingFormStep step;

  @override
  List<Object?> get props => [step];
}

/// Submit-for-review tap on the Review step. Runs client-side Q1
/// validation first; on `ok=true` calls the submit_listing RPC.
class SubmitRequested extends ListingFormEvent {
  const SubmitRequested();
}

/// Tap on the delete-draft action (out-of-band; not in the seven-step
/// happy path but exposed for future surfaces).
class DeleteDraftRequested extends ListingFormEvent {
  const DeleteDraftRequested();
}

/// Result of the bloc resolving an area-centroid lookup (called internally
/// after a `FieldChanged.areaId` on the location step). The bloc converts
/// the use-case result into this event so the reducer applies lat/lng
/// atomically.
class AreaCentroidResolved extends ListingFormEvent {
  const AreaCentroidResolved({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}

class AreaCentroidLookupFailed extends ListingFormEvent {
  const AreaCentroidLookupFailed();
}

/// Field identifiers used by `FieldChanged`. Kept narrow on purpose — only
/// the form's editable fields appear here. The `Object?` payload is
/// destructured by the bloc reducer (downcast to the field's expected
/// runtime type).
enum ListingFormField {
  title,
  purpose,
  propertyType,
  governorateId,
  cityId,
  areaId,
  addressText,
  areaSize,
  rooms,
  bathrooms,
  floor,
  description,
  amenities,
  yearBuilt,
  furnished,
  parking,
  priceCurrencyCode,
  priceAmount,
  locationVisibility,
  contactNameVisibility,
  phone,
  whatsapp,
  hideUntil,
}

// Re-export for convenience.
typedef PurposeValue = ListingPurpose;
typedef PropertyTypeValue = PropertyType;
typedef LocationVisibilityValue = LocationVisibility;
typedef ContactNameVisibilityValue = ContactNameVisibility;
typedef PriceAmountValue = Decimal;
