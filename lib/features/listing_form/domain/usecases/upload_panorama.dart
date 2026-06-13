import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../entities/listing_media.dart';
import '../repositories/listings_repository.dart';

/// Phase 029 (F5) — Uploads a processed equirectangular panorama JPEG and
/// inserts the `listing_media` row with `kind='panorama'`.
///
/// The panorama pipeline (no watermark, 4096px cap, 2:1 aspect gate) runs in
/// the BLoC's isolate worker BEFORE this use case is called; the use case sees
/// only the post-pipeline bytes.
@injectable
class UploadPanorama {
  const UploadPanorama(this._repository);

  final ListingsRepository _repository;

  Future<ListingMedia> call({
    required String listingId,
    required Uint8List panoramaBytes,
    required int ordering,
  }) {
    return _repository.uploadPanorama(
      listingId: listingId,
      panoramaBytes: panoramaBytes,
      ordering: ordering,
    );
  }
}
