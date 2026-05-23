import 'package:injectable/injectable.dart';

import '../entities/listing_media.dart';
import '../repositories/listings_repository.dart';

/// Phase 11 — Uploads an MP4 file and inserts the `listing_media` row.
///
/// The video validator (lib/core/validators/video_file_validator.dart) runs
/// at the BLoC layer BEFORE this use case is called; the use case sees only
/// validated input.
@injectable
class UploadVideo {
  const UploadVideo(this._repository);

  final ListingsRepository _repository;

  Future<ListingMedia> call({
    required String listingId,
    required String filePath,
    required int ordering,
  }) {
    return _repository.uploadVideo(
      listingId: listingId,
      filePath: filePath,
      ordering: ordering,
    );
  }
}
