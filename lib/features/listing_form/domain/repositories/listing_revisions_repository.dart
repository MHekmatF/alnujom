import 'dart:typed_data';

import '../entities/listing_revision.dart';
import '../entities/pending_revision.dart';
import '../entities/revision_manifest_item.dart';

/// Phase 031 (WS-B) — abstract repository for the stay-live edit-revision flow.
/// Concrete impl lives in the data layer (sole Supabase importer).
abstract class ListingRevisionsRepository {
  /// Owner-gated `begin_listing_revision`. Only valid on an approved listing.
  /// Returns the open revision id (existing or newly snapshotted).
  Future<String> beginRevision(String listingId);

  /// Loads a revision (proposed snapshot + parsed manifest + status) by id.
  Future<ListingRevision?> loadRevision(String revisionId);

  /// Returns the open (draft|pending_review) revision for a listing, or null.
  Future<ListingRevision?> findOpenRevision(String listingId);

  /// Owner `save_listing_revision` — replaces the staged proposal + manifest.
  Future<void> saveRevision({
    required String revisionId,
    required Map<String, dynamic> proposed,
    required List<RevisionManifestItem> manifest,
  });

  /// Owner `submit_listing_revision` — pending_review (live listing untouched).
  Future<void> submitRevision(String revisionId);

  /// Admin `apply_listing_revision` — writes proposal back + reconciles media.
  Future<void> applyRevision(String revisionId);

  /// Admin `reject_listing_revision`. [reason] is `{preset, detail}`.
  Future<void> rejectRevision({
    required String revisionId,
    required Map<String, dynamic> reason,
  });

  /// Admin — lists `pending_review` revisions oldest-first.
  Future<List<PendingRevision>> listPendingRevisions({int limit = 50});

  /// Admin — the CURRENT live listing snapshot keyed by the same `proposed`
  /// JSON keys, for a current-vs-proposed diff. Null when the listing is gone.
  Future<Map<String, dynamic>?> loadCurrentSnapshot(String listingId);

  // ─── Staged storage-only uploads (no live listing_media row) ───────────

  /// Uploads watermarked JPEG bytes to `{listingId}/` in `listing-images`.
  /// Returns the staged storage path for a new manifest entry.
  Future<String> uploadStagedImage({
    required String listingId,
    required Uint8List watermarkedBytes,
  });

  /// Uploads a processed panorama JPEG. Returns the staged storage path.
  Future<String> uploadStagedPanorama({
    required String listingId,
    required Uint8List panoramaBytes,
  });

  /// Uploads an MP4 (+ optional poster). Returns the staged path tuple.
  Future<StagedMediaUpload> uploadStagedVideo({
    required String listingId,
    required String filePath,
    String? thumbnailJpegPath,
  });
}

/// Result of a staged video upload — the video path plus an optional poster.
class StagedMediaUpload {
  const StagedMediaUpload({required this.storagePath, this.thumbnailPath});

  final String storagePath;
  final String? thumbnailPath;
}
