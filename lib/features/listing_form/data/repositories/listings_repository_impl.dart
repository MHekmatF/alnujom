import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_details.dart';
import '../../domain/entities/listing_media.dart';
import '../../domain/entities/listing_price.dart';
import '../../domain/entities/submit_listing_result.dart';
import '../../domain/repositories/listings_repository.dart';
import '../datasources/supabase_listing_media_datasource.dart';
import '../datasources/supabase_listings_datasource.dart';

@LazySingleton(as: ListingsRepository)
class ListingsRepositoryImpl implements ListingsRepository {
  ListingsRepositoryImpl(this._ds, this._mediaDs);

  final SupabaseListingsDatasource _ds;
  final SupabaseListingMediaDatasource _mediaDs;

  @override
  Future<Listing?> findDraftForPublisher(String publisherUserId) async {
    final dto = await _ds.findDraftForPublisher(publisherUserId);
    return dto?.toEntity();
  }

  @override
  Future<Listing?> loadListing(String listingId) async {
    final dto = await _ds.loadListing(listingId);
    return dto?.toEntity();
  }

  @override
  Future<Listing> insertDraft(String publisherUserId) async {
    final dto = await _ds.insertDraft(publisherUserId);
    return dto.toEntity();
  }

  @override
  Future<ListingDetails?> loadDetails(String listingId) async {
    final dto = await _ds.loadDetails(listingId);
    return dto?.toEntity();
  }

  @override
  Future<ListingPrice?> loadPrimaryPrice(String listingId) async {
    final dto = await _ds.loadPrimaryPrice(listingId);
    return dto?.toEntity();
  }

  @override
  Future<void> saveBasicsStep({
    required String listingId,
    required String title,
    required ListingPurpose purpose,
    required PropertyType propertyType,
  }) async {
    await _ds.updateListing(listingId, <String, dynamic>{
      'title': title,
      'purpose': purpose.toDbValue(),
      'property_type': propertyType.toDbValue(),
    });
  }

  @override
  Future<void> saveLocationStep({
    required String listingId,
    required String governorateId,
    required String cityId,
    required String areaId,
    required String addressText,
    required double latitude,
    required double longitude,
  }) async {
    await _ds.updateListing(listingId, <String, dynamic>{
      'governorate_id': governorateId,
      'city_id': cityId,
      'area_id': areaId,
      'address_text': addressText,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  @override
  Future<void> saveDetailsStep({
    required String listingId,
    double? areaSize,
    int? rooms,
    int? bathrooms,
    int? floor,
    String? description,
    List<String> amenities = const <String>[],
    int? yearBuilt,
    bool? furnished,
    bool? parking,
  }) async {
    final parentFields = <String, dynamic>{
      if (areaSize != null) 'area_size': areaSize,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'floor': floor,
    };
    await _ds.updateListing(listingId, parentFields);
    await _ds.upsertListingDetails(
      listingId: listingId,
      description: description,
      amenities: amenities,
      yearBuilt: yearBuilt,
      furnished: furnished,
      parking: parking,
    );
  }

  @override
  Future<void> savePricesStep({
    required String listingId,
    required String currencyCode,
    required Decimal amount,
  }) async {
    await _ds.upsertListingPrice(
      listingId: listingId,
      currencyCode: currencyCode,
      amount: amount,
    );
  }

  @override
  Future<void> saveVisibilityStep({
    required String listingId,
    required LocationVisibility locationVisibility,
    required ContactNameVisibility contactNameVisibility,
    DateTime? hideUntil,
    String? phone,
    String? whatsapp,
  }) async {
    await _ds.updateListing(listingId, <String, dynamic>{
      'location_visibility': locationVisibility.toDbValue(),
      'contact_name_visibility': contactNameVisibility.toDbValue(),
      'phone': phone,
      'whatsapp': whatsapp,
      if (hideUntil != null) 'hide_until': hideUntil.toIso8601String(),
    });
  }

  @override
  Future<SubmitListingResult> submitListing(String listingId) async {
    final dto = await _ds.submitListing(listingId);
    return dto.toEntity();
  }

  @override
  Future<void> deleteDraft(String listingId) async {
    await _ds.deleteListing(listingId);
  }

  // ---------------------------------------------------------------------------
  // Phase 11 — listing_media surface (R-40 — extends Phase 10 repository).
  // ---------------------------------------------------------------------------

  @override
  Future<List<ListingMedia>> loadMediaForListing(String listingId) async {
    final dtos = await _mediaDs.loadForListing(listingId);
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<ListingMedia> uploadImage({
    required String listingId,
    required Uint8List watermarkedBytes,
    required int ordering,
    required bool isMain,
  }) async {
    final dto = await _mediaDs.uploadImage(
      listingId: listingId,
      watermarkedJpegBytes: watermarkedBytes,
      ordering: ordering,
      isMain: isMain,
    );
    return dto.toEntity();
  }

  @override
  Future<ListingMedia> uploadVideo({
    required String listingId,
    required String filePath,
    required int ordering,
  }) async {
    final dto = await _mediaDs.uploadVideo(
      listingId: listingId,
      filePath: filePath,
      ordering: ordering,
    );
    return dto.toEntity();
  }

  @override
  Future<void> reorderMedia({
    required String listingId,
    required List<String> newOrderIds,
  }) {
    return _mediaDs.reorder(listingId: listingId, newOrderIds: newOrderIds);
  }

  @override
  Future<void> setMainImage({
    required String listingId,
    required String mediaId,
  }) {
    return _mediaDs.setMain(listingId: listingId, mediaId: mediaId);
  }

  @override
  Future<void> deleteMedia({required String mediaId}) {
    return _mediaDs.deleteMedia(mediaId);
  }

  @override
  String getMediaPublicUrl({required String bucket, required String path}) {
    return _mediaDs.getPublicUrl(bucket: bucket, path: path);
  }
}
