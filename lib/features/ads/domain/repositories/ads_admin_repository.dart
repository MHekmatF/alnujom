// Phase 21 (spec/021-ads-banners) — AdsAdminRepository interface.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.
// The concrete implementation lives in data/repositories/.
//
// All methods return Result<T> / Failure (core/errors/).
// RPC error-code → Failure mapping (implemented by AdsAdminRepositoryImpl):
//   42501  permission_denied  → PermissionDeniedFailure
//   23503  ad_not_found       → ValidationFailure('ad_not_found')
//   23514  constraint/check   → ValidationFailure('constraint_violation')
//   23505  uniqueness         → ValidationFailure code
//   Other  PostgrestException → UnknownFailure

import 'dart:typed_data';

import '../../../../core/errors/result.dart';
import '../entities/ad.dart';

abstract interface class AdsAdminRepository {
  /// Uploads the image file to the `ads` storage bucket and returns the
  /// storage path (e.g. `{uuid}/banner.jpg`). Pass the returned path as
  /// [imagePath] to [createAd] or [updateAd].
  ///
  /// Bucket: `ads` (public read; ads.manage write — R-174).
  /// Path shape: `{client-uuid}/{filename}`.
  ///
  /// Returns [Success] with the storage object path string.
  /// Returns [FailureResult] on storage or network errors.
  Future<Result<String>> uploadAdImage({
    required Uint8List bytes,
    required String contentType,
  });

  /// Calls the `create_ad(p_title, p_image_path, …, p_placements)` SECURITY
  /// DEFINER RPC and returns the new ad's UUID.
  ///
  /// [placements] is a list of `{'placement_key': String, 'priority': int}`
  /// maps (serialized to JSONB by the datasource).
  ///
  /// Returns [Success] with the new ad UUID string.
  /// Returns [FailureResult] on permission (42501), constraint (23514/23505),
  /// or network errors.
  Future<Result<String>> createAd({
    required String title,
    required String imagePath,
    String? captionAr,
    String? captionEn,
    required String linkKind,
    required String linkValue,
    DateTime? startAt,
    DateTime? endAt,
    required bool isActive,
    required List<Map<String, dynamic>> placements,
  });

  /// Calls the `update_ad(p_ad_id, …, p_placements)` SECURITY DEFINER RPC.
  /// Replaces the placement set atomically.
  ///
  /// Returns [Success(null)] on success.
  /// Returns [FailureResult] on permission (42501), ad_not_found (23503),
  /// constraint (23514/23505), or network errors.
  Future<Result<void>> updateAd({
    required String adId,
    required String title,
    required String imagePath,
    String? captionAr,
    String? captionEn,
    required String linkKind,
    required String linkValue,
    DateTime? startAt,
    DateTime? endAt,
    required bool isActive,
    required List<Map<String, dynamic>> placements,
  });

  /// Calls the `set_ad_active(p_ad_id, p_is_active)` SECURITY DEFINER RPC.
  ///
  /// Returns [Success(null)] on success.
  /// Returns [FailureResult] on permission (42501), ad_not_found (23503), or
  /// network errors.
  Future<Result<void>> setAdActive({
    required String adId,
    required bool isActive,
  });

  /// Calls the `archive_ad(p_ad_id)` SECURITY DEFINER RPC (soft-delete).
  ///
  /// Returns [Success(null)] on success.
  /// Returns [FailureResult] on permission (42501), ad_not_found (23503), or
  /// network errors.
  Future<Result<void>> archiveAd(String adId);

  /// Reads all ads from `public.ads` (admin SELECT policy — requires
  /// `ads.manage`) joined with their placement assignments.
  ///
  /// Pass [includeArchived] = true to include soft-deleted ads in the result;
  /// defaults to false (active/scheduled/expired/inactive only).
  ///
  /// Returns [Success] with the list of [Ad] entities (empty list when none).
  Future<Result<List<Ad>>> loadAds({bool includeArchived = false});
}
