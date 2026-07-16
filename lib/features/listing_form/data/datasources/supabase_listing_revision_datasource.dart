import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Phase 031 (WS-B) — Supabase datasource for the stay-live edit-revision flow.
///
/// Constitution IX boundary: this is the ONLY revision file importing
/// `package:supabase_flutter`. It wraps the five SECURITY DEFINER RPCs created
/// in migration `20260615120001_listing_revisions.sql`
/// (`begin/save/submit/apply/reject_listing_revision`), a read to detect an
/// already-open revision, and STAGED storage-only uploads that push bytes/files
/// into the SAME `{listingId}/` bucket path WITHOUT inserting a live
/// `listing_media` row (the manifest is the source of truth until apply).
@injectable
class SupabaseListingRevisionDatasource {
  SupabaseListingRevisionDatasource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  static const String _imagesBucket = 'listing-images';
  static const String _videosBucket = 'listing-videos';

  /// 8-char lowercase-hex random suffix (mirrors the media datasource — no
  /// `package:uuid` dependency added).
  String _randomSuffix() {
    final rnd = _secureOrDefault();
    const chars = '0123456789abcdef';
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

  // ─── RPC wrappers ──────────────────────────────────────────────────────

  /// Owner-gated `begin_listing_revision`. Only succeeds when the live listing
  /// is `approved`; snapshots the listing into a draft revision (or returns the
  /// already-open one). Returns the revision id.
  Future<String> beginRevision(String listingId) async {
    final dynamic raw = await _client.rpc(
      'begin_listing_revision',
      params: <String, dynamic>{'p_listing_id': listingId},
    );
    return raw as String;
  }

  /// Owner `save_listing_revision` — replaces the staged proposal + manifest.
  Future<void> saveRevision({
    required String revisionId,
    required Map<String, dynamic> proposed,
    required List<Map<String, dynamic>> mediaManifest,
  }) async {
    await _client.rpc<void>(
      'save_listing_revision',
      params: <String, dynamic>{
        'p_revision_id': revisionId,
        'p_proposed': proposed,
        'p_media_manifest': mediaManifest,
      },
    );
  }

  /// Owner `submit_listing_revision` — moves the revision to pending_review.
  /// The live listing stays approved (untouched).
  Future<void> submitRevision(String revisionId) async {
    await _client.rpc<void>(
      'submit_listing_revision',
      params: <String, dynamic>{'p_revision_id': revisionId},
    );
  }

  /// Admin `apply_listing_revision` — writes the proposal back onto the live
  /// listing + reconciles media to the manifest. Requires `listings.review`.
  Future<void> applyRevision(String revisionId) async {
    await _client.rpc<void>(
      'apply_listing_revision',
      params: <String, dynamic>{'p_revision_id': revisionId},
    );
  }

  /// Admin `reject_listing_revision` — sets status='rejected' + reject_reason.
  /// [reason] is the `{preset, detail}` JSON written into `reject_reason`.
  Future<void> rejectRevision({
    required String revisionId,
    required Map<String, dynamic> reason,
  }) async {
    await _client.rpc<void>(
      'reject_listing_revision',
      params: <String, dynamic>{
        'p_revision_id': revisionId,
        'p_reason': reason,
      },
    );
  }

  /// Owner `withdraw_listing_revision` — cancels the caller's own open
  /// (draft|pending_review) revision (status → 'withdrawn'); the live listing is
  /// untouched. The DB enforces owner + status.
  Future<void> withdrawRevision(String revisionId) async {
    await _client.rpc<void>(
      'withdraw_listing_revision',
      params: <String, dynamic>{'p_revision_id': revisionId},
    );
  }

  // ─── Open-revision check ───────────────────────────────────────────────

  /// Returns the open (draft|pending_review) revision row for [listingId], or
  /// null. RLS restricts the SELECT to the owner (or an admin). Used by the
  /// form to detect an existing draft and by My Listings to surface the
  /// "edit in review" badge.
  Future<Map<String, dynamic>?> findOpenRevision(String listingId) async {
    final rows = await _client
        .from('listing_revisions')
        .select('id, status, proposed, media_manifest')
        .eq('listing_id', listingId)
        .inFilter('status', <String>['draft', 'pending_review'])
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// Loads one revision row by id (proposed + manifest + status).
  Future<Map<String, dynamic>?> loadRevision(String revisionId) async {
    final rows = await _client
        .from('listing_revisions')
        .select('id, listing_id, status, proposed, media_manifest, reject_reason')
        .eq('id', revisionId)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// Admin — lists `pending_review` revisions oldest-first (matches the
  /// `listing_revisions_pending_created_idx`). RLS exposes these rows only to a
  /// `listings.review` holder. Each row carries the proposed snapshot + manifest
  /// and the listing's id/created_at so the queue can show a compact summary.
  Future<List<Map<String, dynamic>>> listPendingRevisions({int limit = 50}) async {
    final rows = await _client
        .from('listing_revisions')
        .select(
          'id, listing_id, status, proposed, media_manifest, created_at',
        )
        .eq('status', 'pending_review')
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  /// Loads the CURRENT live listing snapshot (scalar + detail + primary price)
  /// for an admin's current-vs-proposed diff. Returns a flat map keyed by the
  /// same `proposed` JSON keys the revision uses, so the diff lines up 1:1.
  Future<Map<String, dynamic>?> loadCurrentSnapshot(String listingId) async {
    final listingRows = await _client
        .from('listings')
        .select(
          'title, purpose, property_type, governorate_id, city_id, area_id, '
          'address_text, latitude, longitude, location_visibility, '
          'contact_name_visibility, phone, whatsapp, area_size, rooms, '
          'bathrooms, floor',
        )
        .eq('id', listingId)
        .limit(1);
    if (listingRows.isEmpty) return null;
    final snapshot = Map<String, dynamic>.from(listingRows.first);

    final detailRows = await _client
        .from('listing_details')
        .select('description, amenities, year_built, furnished, parking')
        .eq('listing_id', listingId)
        .limit(1);
    if (detailRows.isNotEmpty) {
      snapshot.addAll(Map<String, dynamic>.from(detailRows.first));
    }

    final priceRows = await _client
        .from('listing_prices')
        .select('currency_code, amount')
        .eq('listing_id', listingId)
        .eq('is_primary', true)
        .limit(1);
    if (priceRows.isNotEmpty) {
      final p = Map<String, dynamic>.from(priceRows.first);
      snapshot['price_currency_code'] = p['currency_code'];
      snapshot['price_amount'] = p['amount'];
    }
    return snapshot;
  }

  // ─── Staged storage-only uploads ───────────────────────────────────────

  /// Uploads watermarked JPEG bytes to `listing-images` at `{listingId}/{sfx}.jpg`
  /// and returns the storage path. Does NOT insert a `listing_media` row — the
  /// caller appends a manifest entry instead. Best-effort orphan cleanup on a
  /// thrown upload (rethrows so the BLoC can surface the error tile).
  Future<String> uploadStagedImage({
    required String listingId,
    required Uint8List watermarkedJpegBytes,
  }) async {
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
    return path;
  }

  /// Uploads a processed equirectangular JPEG to `listing-images` and returns
  /// the storage path (staged; no row insert). Mirrors [uploadStagedImage].
  Future<String> uploadStagedPanorama({
    required String listingId,
    required Uint8List panoramaJpegBytes,
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
    return path;
  }

  /// Uploads an MP4 to `listing-videos` (and an optional poster JPEG to
  /// `listing-images`) and returns the staged paths. No row insert.
  Future<StagedVideoPaths> uploadStagedVideo({
    required String listingId,
    required String filePath,
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
        thumbnailPath = null; // poster optional — fall through
      }
    }
    return StagedVideoPaths(storagePath: path, thumbnailPath: thumbnailPath);
  }
}

/// Paths returned by a staged video upload.
class StagedVideoPaths {
  const StagedVideoPaths({required this.storagePath, this.thumbnailPath});

  final String storagePath;
  final String? thumbnailPath;
}
