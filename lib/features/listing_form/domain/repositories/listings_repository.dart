import 'dart:typed_data';

import 'package:decimal/decimal.dart';

import '../entities/listing.dart';
import '../entities/listing_details.dart';
import '../entities/listing_media.dart';
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

  /// Persists the basics step (title, purpose, property_type, agency_id).
  /// [agencyId] is null for a personal listing; the membership gate is enforced
  /// at submit time by the submit_listing RPC (Phase 19 R-143 soft gate).
  Future<void> saveBasicsStep({
    required String listingId,
    required String title,
    required ListingPurpose purpose,
    required PropertyType propertyType,
    String? agencyId,
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

  // ---------------------------------------------------------------------------
  // Phase 11 — listing_media surface (R-40 — extends Phase 10 repository).
  // ---------------------------------------------------------------------------

  /// Loads every `listing_media` row for a listing, sorted by `ordering ASC`.
  Future<List<ListingMedia>> loadMediaForListing(String listingId);

  /// Uploads watermarked JPEG bytes to `listing-images` then inserts the
  /// `listing_media` row per FR-014 / FR-015 (atomic-from-publisher-perspective).
  Future<ListingMedia> uploadImage({
    required String listingId,
    required Uint8List watermarkedBytes,
    required int ordering,
    required bool isMain,
  });

  /// Uploads an MP4 file to `listing-videos` then inserts the row. No
  /// watermark composite for videos in Phase 11.
  Future<ListingMedia> uploadVideo({
    required String listingId,
    required String filePath,
    required int ordering,
  });

  /// Phase 029 (F5) — uploads processed equirectangular panorama JPEG bytes to
  /// `listing-images` then inserts a `kind='panorama'` row (watermarked=false,
  /// is_main=false). The panorama pipeline runs in the isolate worker BEFORE
  /// this call (no watermark — it would break the 360° wrap seam).
  Future<ListingMedia> uploadPanorama({
    required String listingId,
    required Uint8List panoramaBytes,
    required int ordering,
  });

  /// Re-sequences `ordering` for a list of media ids (drag-reorder commit).
  Future<void> reorderMedia({
    required String listingId,
    required List<String> newOrderIds,
  });

  /// Flips `is_main` to `true` on the target row and clears any prior main.
  Future<void> setMainImage({
    required String listingId,
    required String mediaId,
  });

  /// Per-thumbnail delete per R-38 (Storage REMOVE then SQL DELETE).
  Future<void> deleteMedia({required String mediaId});

  /// Returns a stable public URL for a bucket object (Q8=A consumer hook).
  String getMediaPublicUrl({required String bucket, required String path});

  /// Spec 026 — sets the free-text `kind` on an existing media row and returns
  /// the updated entity. Used to (un)mark an uploaded image as a 360°/virtual-
  /// tour panorama (`'panorama'` ⇄ `'image'`); the storage object is untouched.
  Future<ListingMedia> setMediaKind({
    required String mediaId,
    required String kind,
  });
}
