import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — staged media uploads for revision mode. Each pushes the
/// processed bytes/file into the SAME `{listingId}/` bucket path as the live
/// upload, but inserts NO `listing_media` row — the caller appends a manifest
/// entry instead. The admin's `apply_listing_revision` reconciles the live rows.
@injectable
class UploadStagedImage {
  const UploadStagedImage(this._repository);

  final ListingRevisionsRepository _repository;

  Future<String> call({
    required String listingId,
    required Uint8List watermarkedBytes,
  }) {
    return _repository.uploadStagedImage(
      listingId: listingId,
      watermarkedBytes: watermarkedBytes,
    );
  }
}

@injectable
class UploadStagedPanorama {
  const UploadStagedPanorama(this._repository);

  final ListingRevisionsRepository _repository;

  Future<String> call({
    required String listingId,
    required Uint8List panoramaBytes,
  }) {
    return _repository.uploadStagedPanorama(
      listingId: listingId,
      panoramaBytes: panoramaBytes,
    );
  }
}

@injectable
class UploadStagedVideo {
  const UploadStagedVideo(this._repository);

  final ListingRevisionsRepository _repository;

  Future<StagedMediaUpload> call({
    required String listingId,
    required String filePath,
    String? thumbnailJpegPath,
  }) {
    return _repository.uploadStagedVideo(
      listingId: listingId,
      filePath: filePath,
      thumbnailJpegPath: thumbnailJpegPath,
    );
  }
}
