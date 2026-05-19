import 'package:decimal/decimal.dart';

import '../entities/listing.dart';
import '../entities/listing_details.dart';
import '../entities/listing_price.dart';
import '../entities/submit_listing_result.dart';

/// Abstract repository for the Phase 10 listing-form feature.
/// Concrete impl lives in lib/features/listing_form/data/repositories/.
abstract class ListingsRepository {
  /// Returns the publisher's most-recent `status='draft'` listing, or null.
  Future<Listing?> findDraftForPublisher(String publisherUserId);

  /// Loads a specific listing by id. Returns null if not found / not owned.
  Future<Listing?> loadListing(String listingId);

  /// Inserts a new `status='draft'` row owned by [publisherUserId].
  /// Server-side trigger writes the NULL→draft history row.
  Future<Listing> insertDraft(String publisherUserId);

  /// Loads child rows if present.
  Future<ListingDetails?> loadDetails(String listingId);
  Future<ListingPrice?> loadPrimaryPrice(String listingId);

  /// Persists the basics step (title, purpose, property_type).
  Future<void> saveBasicsStep({
    required String listingId,
    required String title,
    required ListingPurpose purpose,
    required PropertyType propertyType,
  });

  /// Persists the location step (parent columns + auto-filled centroid).
  Future<void> saveLocationStep({
    required String listingId,
    required String governorateId,
    required String cityId,
    required String areaId,
    required String addressText,
    required double latitude,
    required double longitude,
  });

  /// Persists the details step. Updates parent `listings` columns
  /// (area_size, rooms, bathrooms, floor) AND UPSERTs the child
  /// `listing_details` row in a single repository call.
  Future<void> saveDetailsStep({
    required String listingId,
    double? areaSize,
    int? rooms,
    int? bathrooms,
    int? floor,
    String? description,
    List<String> amenities,
    int? yearBuilt,
    bool? furnished,
    bool? parking,
  });

  /// Persists the prices step. Q3 single-currency invariant — if the
  /// publisher changes currency on an existing draft, the impl
  /// DELETEs then INSERTs to avoid creating a second row.
  Future<void> savePricesStep({
    required String listingId,
    required String currencyCode,
    required Decimal amount,
  });

  /// Persists the visibility step (parent columns; child row is synced by
  /// the listing_visibility_sync_trigger on the server).
  Future<void> saveVisibilityStep({
    required String listingId,
    required LocationVisibility locationVisibility,
    required ContactNameVisibility contactNameVisibility,
    DateTime? hideUntil,
    String? phone,
    String? whatsapp,
  });

  /// Calls the submit_listing RPC; surfaces `SubmitListingFailureException`
  /// when SQLSTATE=22023 with a missing_fields payload.
  Future<SubmitListingResult> submitListing(String listingId);

  /// Deletes the listing row (cascades to children). Throws if status is
  /// not `draft`.
  Future<void> deleteDraft(String listingId);
}
