import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../../domain/entities/listing_revision.dart';
import '../../domain/entities/pending_revision.dart';
import '../../domain/entities/revision_manifest_item.dart';
import '../../domain/repositories/listing_revisions_repository.dart';
import '../datasources/supabase_listing_revision_datasource.dart';

@LazySingleton(as: ListingRevisionsRepository)
class ListingRevisionsRepositoryImpl implements ListingRevisionsRepository {
  ListingRevisionsRepositoryImpl(this._ds);

  final SupabaseListingRevisionDatasource _ds;

  @override
  Future<String> beginRevision(String listingId) {
    return _ds.beginRevision(listingId);
  }

  @override
  Future<ListingRevision?> loadRevision(String revisionId) async {
    final row = await _ds.loadRevision(revisionId);
    if (row == null) return null;
    return _toEntity(row);
  }

  @override
  Future<ListingRevision?> findOpenRevision(String listingId) async {
    final row = await _ds.findOpenRevision(listingId);
    if (row == null) return null;
    return _toEntity(row);
  }

  @override
  Future<void> saveRevision({
    required String revisionId,
    required Map<String, dynamic> proposed,
    required List<RevisionManifestItem> manifest,
  }) {
    return _ds.saveRevision(
      revisionId: revisionId,
      proposed: proposed,
      mediaManifest: manifest.map((m) => m.toJson()).toList(),
    );
  }

  @override
  Future<void> submitRevision(String revisionId) {
    return _ds.submitRevision(revisionId);
  }

  @override
  Future<void> applyRevision(String revisionId) {
    return _ds.applyRevision(revisionId);
  }

  @override
  Future<void> rejectRevision({
    required String revisionId,
    required Map<String, dynamic> reason,
  }) {
    return _ds.rejectRevision(revisionId: revisionId, reason: reason);
  }

  @override
  Future<String> uploadStagedImage({
    required String listingId,
    required Uint8List watermarkedBytes,
  }) {
    return _ds.uploadStagedImage(
      listingId: listingId,
      watermarkedJpegBytes: watermarkedBytes,
    );
  }

  @override
  Future<String> uploadStagedPanorama({
    required String listingId,
    required Uint8List panoramaBytes,
  }) {
    return _ds.uploadStagedPanorama(
      listingId: listingId,
      panoramaJpegBytes: panoramaBytes,
    );
  }

  @override
  Future<List<PendingRevision>> listPendingRevisions({int limit = 50}) async {
    final rows = await _ds.listPendingRevisions(limit: limit);
    return rows.map((row) {
      final revision = _toEntity(row);
      final submittedAtRaw = row['created_at'];
      final submittedAt = submittedAtRaw is String
          ? DateTime.parse(submittedAtRaw)
          : DateTime.fromMillisecondsSinceEpoch(0);
      return PendingRevision(
        revision: revision,
        listingId: (row['listing_id'] as String?) ?? '',
        submittedAt: submittedAt,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> loadCurrentSnapshot(String listingId) {
    return _ds.loadCurrentSnapshot(listingId);
  }

  @override
  Future<StagedMediaUpload> uploadStagedVideo({
    required String listingId,
    required String filePath,
    String? thumbnailJpegPath,
  }) async {
    final paths = await _ds.uploadStagedVideo(
      listingId: listingId,
      filePath: filePath,
      thumbnailJpegPath: thumbnailJpegPath,
    );
    return StagedMediaUpload(
      storagePath: paths.storagePath,
      thumbnailPath: paths.thumbnailPath,
    );
  }

  ListingRevision _toEntity(Map<String, dynamic> row) {
    final proposedRaw = row['proposed'];
    final proposed = proposedRaw is Map
        ? Map<String, dynamic>.from(proposedRaw)
        : <String, dynamic>{};
    final manifestRaw = row['media_manifest'];
    final manifest = manifestRaw is List
        ? manifestRaw
              .whereType<Map>()
              .map(
                (m) =>
                    RevisionManifestItem.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList()
        : <RevisionManifestItem>[];
    return ListingRevision(
      id: row['id'] as String,
      status: (row['status'] as String?) ?? 'draft',
      proposed: proposed,
      manifest: manifest,
    );
  }
}
