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
        .map((r) => ListingMediaDto.fromJson(Map<String, dynamic>.from(r as Map)))
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
    final path = '$listingId/${ordering}_${_randomSuffix()}.jpg';
    await _client.storage.from(_imagesBucket).uploadBinary(
      path,
      watermarkedJpegBytes,
      fileOptions: const supabase.FileOptions(
        contentType: 'image/jpeg',
        upsert: false,
      ),
    );
    try {
      final row = await _client.from('listing_media').insert(<String, dynamic>{
        'listing_id': listingId,
        'kind': 'image',
        'storage_path': path,
        'external_url': null,
        'ordering': ordering,
        'is_main': isMain,
        'watermarked': true, // FR-016 — always true for Phase 11 client uploads
      }).select().single();
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

  /// Uploads an MP4 to `listing-videos` then inserts the row. No watermark
  /// is applied — Phase 11 watermarks images only per FR-014.
  Future<ListingMediaDto> uploadVideo({
    required String listingId,
    required String filePath,
    required int ordering,
  }) async {
    final path = '$listingId/${ordering}_${_randomSuffix()}.mp4';
    await _client.storage.from(_videosBucket).upload(
      path,
      File(filePath),
      fileOptions: const supabase.FileOptions(
        contentType: 'video/mp4',
        upsert: false,
      ),
    );
    try {
      final row = await _client.from('listing_media').insert(<String, dynamic>{
        'listing_id': listingId,
        'kind': 'video',
        'storage_path': path,
        'external_url': null,
        'ordering': ordering,
        'is_main': false, // FR-002 CHECK — video rows can never be main
        'watermarked': false,
      }).select().single();
      return ListingMediaDto.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      try {
        await _client.storage.from(_videosBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Re-sequences `ordering` for a list of media ids via sequential
  /// per-row UPDATEs. Each UPDATE touches only the `ordering` column so
  /// PostgREST does not need to validate the row's NOT NULL columns.
  ///
  /// NOTE: an `upsert` with a partial column set (id + listing_id + ordering)
  /// would round-trip in 1 call but PostgREST validates the INSERT branch
  /// against NOT NULL constraints on `kind` / `storage_path` / `is_main` /
  /// `watermarked` and returns 400 — even though the conflict resolution
  /// would have routed to UPDATE. Sequential UPDATEs are O(N) round-trips
  /// but reliable, and N is bounded by the 10-image + 2-video cap.
  Future<void> reorder({
    required String listingId,
    required List<String> newOrderIds,
  }) async {
    if (newOrderIds.isEmpty) return;
    for (int i = 0; i < newOrderIds.length; i++) {
      await _client
          .from('listing_media')
          .update(<String, dynamic>{'ordering': i + 1})
          .eq('id', newOrderIds[i]);
    }
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
}
