import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../entities/listing_media.dart';
import '../repositories/listings_repository.dart';

/// Phase 11 — Uploads a watermarked JPEG and inserts the `listing_media` row.
///
/// The watermark pipeline runs in the BLoC's isolate worker BEFORE this use
/// case is called; the use case sees only the post-pipeline bytes per the
/// FR-015 atomic-from-publisher-perspective invariant.
@injectable
class UploadImage {
  const UploadImage(this._repository);

  final ListingsRepository _repository;

  Future<ListingMedia> call({
    required String listingId,
    required Uint8List watermarkedBytes,
    required int ordering,
    required bool isMain,
    Uint8List? thumbnailBytes,
  }) {
    return _repository.uploadImage(
      listingId: listingId,
      watermarkedBytes: watermarkedBytes,
      ordering: ordering,
      isMain: isMain,
      thumbnailBytes: thumbnailBytes,
    );
  }
}
