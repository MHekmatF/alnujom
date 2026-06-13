import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/listing_media_dto.dart';

/// Phase 11 — surfaced by the [SupabaseListingMediaDatasource] when the
/// per-thumbnail delete sequence (R-38) cannot fully complete. The BLoC
/// maps this to a localized ARB key via `_mapMediaErrorToArbKey`.
class MediaDeleteException implements Exception {
  final String message;
  MediaDeleteException(this.message);
  @override
  String toString() => 'MediaDeleteException: $message';
}

/// Phase 11 — Supabase datasource for the `public.listing_media` table and
/// the two Storage buckets (`listing-images`, `listing-videos`).
///
/// Constitution IX boundary: this is the ONLY Phase 11 file (besides the BLoC,
/// which imports `PostgrestException` for error mapping per R-30) that imports
/// `package:supabase_flutter`. All storage SDK and PostgREST calls live here;
/// the repository / use cases / BLoC consume only domain types.
@injectable
class SupabaseListingMediaDatasource {
  SupabaseListingMediaDatasource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  static const String _imagesBucket = 'listing-images';
  static const String _videosBucket = 'listing-videos';

  /// 8-character lowercase-hex random suffix used in storage paths.
  ///
  /// Uses `dart:math.Random.secure()` when available (preferred) and
  /// falls back to the default `Random()` if the platform throws. No
  /// `package:uuid` dependency is added — Phase 11 keeps the pubspec
  /// delta to R-22's three packages.
  String _randomSuffix() {
    final rnd = _secureOrDefault();
    final chars = '0123456789abcdef'.split('');
    final buf = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buf.write(chars[rnd.nextInt(16)]);
    }
    return buf.toString();
  }

  math.Random _secureOrDefault() {
    try {
      return math.Random.secure();
    } catch (_) {
      return math.Random();
    }
  }

  /// Loads every `listing_media` row for a listing, sorted by `ordering ASC`
  /// per data-model.md § 8.3.
  Future<List<ListingMediaDto>> loadForListing(String listingId) async {
    final rows = await _client
        .from('listing_media')
        .select()
        .eq('listing_id', listingId)
        .order('ordering', ascending: true);
    return (rows as List)
        .map(
          (r) => ListingMediaDto.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  /// Uploads watermarked JPEG bytes to `listing-images` then inserts the
  /// `listing_media` row. FR-015: atomic-from-publisher-perspective —
  /// on INSERT failure the bucket object is removed (defense-in-depth
  /// against orphan objects).
  Future<ListingMediaDto> uploadImage({
    required String listingId,
    required Uint8List watermarkedJpegBytes,
    required int ordering,
    required bool isMain,
  }) async {
    // Per task #29 follow-up: `ordering` is no longer embedded in the path,
    // and we send 0 as the sentinel — the listing_media_assign_ordering
    // BEFORE INSERT trigger computes the actual value server-side.
    final path = '$listingId/${_randomSuffix()}.jpg';
    await _client.storage
        .from(_imagesBucket)
        .uploadBinary(
          path,
          watermarkedJpegBytes,
          fileOptions: const supabase.FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    try {
      final row = await _client
          .from('listing_media')
          .insert(<String, dynamic>{
            'listing_id': listingId,
            'kind': 'image',
            'storage_path': path,
            'external_url': null,
            'ordering': 0, // sentinel — trigger assigns max(ordering)+1
            'is_main': isMain,
            'watermarked':
                true, // FR-016 — always true for Phase 11 client uploads
          })
          .select()
          .single();
      return ListingMediaDto.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      // On INSERT failure (cap trigger fire, RLS deny, etc.) — orphan cleanup.
      try {
        await _client.storage.from(_imagesBucket).remove([path]);
      } catch (_) {
        // Swallow cleanup failure — the bucket object becomes a true orphan;
        // the Phase 23 reconciliation job will eventually clean it up (R-28).
      }
      rethrow;
    }
  }

  /// Phase 029 (F5) — Uploads a processed equirectangular JPEG to
  /// `listing-images` (a panorama is just an image stored in the same bucket)
  /// then inserts the `listing_media` row with `kind='panorama'`,
  /// `watermarked=false` (the panorama pipeline applies no watermark — it would
  /// break the 360° wrap seam) and `is_main=false` (a panorama can never be the
  /// main image — the `listing_media_main_only_when_image_chk` CHECK plus the
  /// one-main partial index already forbid it).
  ///
  /// Path convention matches [uploadImage]: `{listingId}/{suffix}.jpg`. On INSERT
  /// failure the bucket object is removed (orphan cleanup, FR-015 parity).
  Future<ListingMediaDto> uploadPanorama({
    required String listingId,
    required Uint8List panoramaJpegBytes,
    required int ordering,
  }) async {
    final path = '$listingId/${_randomSuffix()}.jpg';
    await _client.storage
        .from(_imagesBucket)
        .uploadBinary(
          path,
          panoramaJpegBytes,
          fileOptions: const supabase.FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    try {
      final row = await _client
          .from('listing_media')
          .insert(<String, dynamic>{
            'listing_id': listingId,
            'kind': 'panorama',
            'storage_path': path,
            'external_url': null,
            'ordering': 0, // sentinel — trigger assigns max(ordering)+1
            'is_main': false, // panorama rows can never be main
            'watermarked': false, // no watermark on equirectangular images
          })
          .select()
          .single();
      return ListingMediaDto.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      // On INSERT failure (panorama cap trigger fire, RLS deny, etc.) —
      // orphan cleanup, mirroring uploadImage.
      try {
        await _client.storage.from(_imagesBucket).remove([path]);
      } catch (_) {
        // Swallow cleanup failure — the bucket object becomes a true orphan;
        // the reconciliation job will eventually clean it up.
      }
      rethrow;
    }
  }

  /// Uploads an MP4 to `listing-videos` then inserts the row. No watermark
  /// is applied — Phase 11 watermarks images only per FR-014.
  ///
  /// Phase 030 (W1): when [thumbnailJpegPath] is provided, the poster JPEG is
  /// also uploaded to the `listing-images` bucket at `{listingId}/{suffix}_thumb.jpg`
  /// (sharing the mp4's random suffix) and its storage path is written into the
  /// new `listing_media.thumbnail_path` column on the inserted video row. The
  /// poster is best-effort — a failed poster upload never blocks the video
  /// upload (the row is still inserted with a null `thumbnail_path`).
  Future<ListingMediaDto> uploadVideo({
    required String listingId,
    required String filePath,
    required int ordering,
    String? thumbnailJpegPath,
  }) async {
    final suffix = _randomSuffix();
    final path = '$listingId/$suffix.mp4';
    await _client.storage
        .from(_videosBucket)
        .upload(
          path,
          File(filePath),
          fileOptions: const supabase.FileOptions(
            contentType: 'video/mp4',
            upsert: false,
          ),
        );

    // Best-effort poster upload to the images bucket (sharing the mp4 suffix).
    // A failure here must NOT abort the video upload — the row is inserted with
    // a null thumbnail_path and the reels/gallery falls back to the first image.
    String? thumbnailPath;
    if (thumbnailJpegPath != null) {
      final candidate = '$listingId/${suffix}_thumb.jpg';
      try {
        await _client.storage
            .from(_imagesBucket)
            .upload(
              candidate,
              File(thumbnailJpegPath),
              fileOptions: const supabase.FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
        thumbnailPath = candidate;
      } catch (_) {
        thumbnailPath = null; // poster is optional — fall through
      }
    }

    try {
      final row = await _client
          .from('listing_media')
          .insert(<String, dynamic>{
            'listing_id': listingId,
            'kind': 'video',
            'storage_path': path,
            'external_url': null,
            'ordering': 0, // sentinel — trigger assigns
            'is_main': false, // FR-002 CHECK — video rows can never be main
            'watermarked': false,
            // Phase 030 (W1) — poster path in the listing-images bucket (or null).
            'thumbnail_path': thumbnailPath,
          })
          .select()
          .single();
      return ListingMediaDto.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      try {
        await _client.storage.from(_videosBucket).remove([path]);
      } catch (_) {}
      // Also clean up the orphaned poster object if the row INSERT failed.
      if (thumbnailPath != null) {
        try {
          await _client.storage.from(_imagesBucket).remove([thumbnailPath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Re-sequences `ordering` for a list of media ids via the
  /// `reorder_listing_media` SECURITY DEFINER RPC — single round-trip,
  /// atomic under one DB transaction (task #31 follow-up).
  ///
  /// Caller authorization is enforced inside the function body (per Phase
  /// 7/9 R-06 precedent): the caller must own the listing OR have
  /// `listings.edit_any`, the listing must be in draft/rejected status,
  /// and every id in newOrderIds must belong to that listing.
  Future<void> reorder({
    required String listingId,
    required List<String> newOrderIds,
  }) async {
    if (newOrderIds.isEmpty) return;
    await _client.rpc<void>(
      'reorder_listing_media',
      params: <String, dynamic>{
        'p_listing_id': listingId,
        'p_ordered_ids': newOrderIds,
      },
    );
  }

  /// Flips `is_main` to `true` on the target row and `false` on the prior
  /// main row. The partial unique index serializes set-main at the DB
  /// layer — a concurrent UPDATE would surface as a 23505 unique_violation.
  Future<void> setMain({
    required String listingId,
    required String mediaId,
  }) async {
    // 1. Clear any prior main image rows for this listing.
    await _client
        .from('listing_media')
        .update(<String, dynamic>{'is_main': false})
        .eq('listing_id', listingId)
        .eq('is_main', true);
    // 2. Set the target row.
    await _client
        .from('listing_media')
        .update(<String, dynamic>{'is_main': true})
        .eq('id', mediaId);
  }

  /// Deletes a media row per R-38 ordering: Storage REMOVE first (with up
  /// to 2 attempts × 1s delay), then SQL DELETE. If Storage fails, the row
  /// is NOT deleted — the publisher can retry. If SQL DELETE fails after
  /// Storage succeeded, the row is briefly orphaned — the picker reloads
  /// and the publisher retries.
  Future<void> deleteMedia(String mediaId) async {
    final row = await _client
        .from('listing_media')
        .select('storage_path, kind')
        .eq('id', mediaId)
        .maybeSingle();
    if (row == null) return; // already gone — idempotent

    final path = row['storage_path'] as String?;
    final kind = row['kind'] as String?;
    final bucket = kind == 'video' ? _videosBucket : _imagesBucket;

    // Storage REMOVE — up to 2 attempts with 1s delay
    if (path != null) {
      Object? lastStorageError;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          await _client.storage.from(bucket).remove([path]);
          lastStorageError = null;
          break;
        } catch (e) {
          lastStorageError = e;
          if (attempt < 1) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
      }
      if (lastStorageError != null) {
        throw MediaDeleteException(
          'Storage remove failed for $path: $lastStorageError',
        );
      }
    }

    // SQL DELETE — up to 3 attempts (Storage already gone; retries safe)
    Object? lastSqlError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _client.from('listing_media').delete().eq('id', mediaId);
        lastSqlError = null;
        break;
      } catch (e) {
        lastSqlError = e;
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
    if (lastSqlError != null) {
      throw MediaDeleteException(
        'Row delete failed after storage cleanup: $lastSqlError',
      );
    }
  }

  /// Returns a stable public URL for a bucket object. Per Q8=A, both buckets
  /// are `public: true` with RLS as the access filter; the URL is stable and
  /// safe to cache via `cached_network_image` (Phase 13 / Phase 14 gallery).
  String getPublicUrl({required String bucket, required String path}) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Spec 026 — sets the free-text `kind` on an existing media row.
  ///
  /// Used to (un)mark an already-uploaded image as a 360°/virtual-tour
  /// panorama (a panorama is just an equirectangular image with `kind` flipped
  /// from `'image'` to `'panorama'` and back). The storage object is untouched —
  /// only the DB column changes. Returns the updated row.
  Future<ListingMediaDto> setKind({
    required String mediaId,
    required String kind,
  }) async {
    final row = await _client
        .from('listing_media')
        .update(<String, dynamic>{'kind': kind})
        .eq('id', mediaId)
        .select()
        .single();
    return ListingMediaDto.fromJson(Map<String, dynamic>.from(row));
  }
}
