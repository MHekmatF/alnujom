// Phase 21 (spec/021-ads-banners) — UploadAdImage use case.
//
// Uploads a banner image to the `ads` storage bucket and returns the storage
// path (e.g. `{uuid}/banner.jpg`). The caller passes the path to CreateAd or
// UpdateAd as [imagePath] (R-174 / R-180).
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/ads_admin_repository.dart';

@injectable
class UploadAdImage {
  const UploadAdImage(this._repository);

  final AdsAdminRepository _repository;

  /// Uploads [bytes] with the given [contentType] to the `ads` bucket.
  ///
  /// Returns [Success] with the storage path string (e.g. `{uuid}/banner.jpg`).
  /// Returns [FailureResult] on storage or network errors.
  Future<Result<String>> call({
    required Uint8List bytes,
    required String contentType,
  }) =>
      _repository.uploadAdImage(bytes: bytes, contentType: contentType);
}
