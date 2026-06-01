// Phase 21 (spec/021-ads-banners) — SupabaseAdsAdminDatasource.
//
// SOLE importer of supabase_flutter under lib/features/ads/ for admin ops.
// Per Constitution IX: domain/ and data/dtos/ have ZERO supabase_flutter imports.
//
// Responsibilities:
//   - create_ad RPC      (FR-001 / data-model §6)
//   - update_ad RPC      (FR-001)
//   - set_ad_active RPC  (FR-006)
//   - archive_ad RPC     (FR-006 / R-170)
//   - ads + ad_placements SELECT (admin list — FR-008)
//   - ads bucket uploadBinary + getPublicUrl (R-174 / R-180)
//   - orphan-cleanup: delete uploaded object if RPC fails after upload

import 'dart:math';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/ad_dto.dart';

@injectable
class SupabaseAdsAdminDatasource {
  SupabaseAdsAdminDatasource(this._client);

  final supabase.SupabaseClient _client;

  static const _bucket = 'ads';

  // ---------------------------------------------------------------------------
  // Image storage
  // ---------------------------------------------------------------------------

  /// Uploads [bytes] to the `ads` bucket at `{uuid}/{filename}`.
  /// Path shape: `{client-uuid}/{original-filename}` (R-174).
  ///
  /// Returns the storage object path (NOT a URL — callers resolve via
  /// [getAdImagePublicUrl]). Throws [supabase.StorageException] on failure.
  Future<String> uploadAdImage({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final prefix = _generateUuid();
    final extension = _extensionForContentType(contentType);
    final path = '$prefix/banner$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(contentType: contentType),
        );
    return path;
  }

  /// Resolves a storage path to a public URL.
  String getAdImagePublicUrl(String path) =>
      _client.storage.from(_bucket).getPublicUrl(path);

  /// Deletes a storage object (used for orphan cleanup when a post-upload RPC
  /// call fails — R-174).
  Future<void> deleteAdImage(String path) async {
    await _client.storage.from(_bucket).remove([path]);
  }

  // ---------------------------------------------------------------------------
  // Write RPCs
  // ---------------------------------------------------------------------------

  /// Calls `create_ad(p_title, …, p_placements JSONB)` SECURITY DEFINER RPC.
  /// Returns the new ad UUID.
  ///
  /// [placements] elements: `{'placement_key': String, 'priority': int}`.
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - 42501 permission_denied
  ///   - 23514/23505 constraint violations (bad link_kind, invalid window,
  ///     one-caption-null)
  Future<String> createAd({
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
  }) async {
    final result = await _client.rpc(
      'create_ad',
      params: {
        'p_title': title,
        'p_image_path': imagePath,
        'p_caption_ar': captionAr,
        'p_caption_en': captionEn,
        'p_link_kind': linkKind,
        'p_link_value': linkValue,
        'p_start_at': startAt?.toIso8601String(),
        'p_end_at': endAt?.toIso8601String(),
        'p_is_active': isActive,
        'p_placements': placements.isEmpty ? null : placements,
      },
    );
    return result as String;
  }

  /// Calls `update_ad(p_ad_id, …, p_placements JSONB)` SECURITY DEFINER RPC.
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - 42501 permission_denied
  ///   - 23503 ad_not_found
  ///   - 23514/23505 constraint violations
  Future<void> updateAd({
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
  }) async {
    await _client.rpc(
      'update_ad',
      params: {
        'p_ad_id': adId,
        'p_title': title,
        'p_image_path': imagePath,
        'p_caption_ar': captionAr,
        'p_caption_en': captionEn,
        'p_link_kind': linkKind,
        'p_link_value': linkValue,
        'p_start_at': startAt?.toIso8601String(),
        'p_end_at': endAt?.toIso8601String(),
        'p_is_active': isActive,
        'p_placements': placements.isEmpty ? null : placements,
      },
    );
  }

  /// Calls `set_ad_active(p_ad_id, p_is_active)` SECURITY DEFINER RPC.
  ///
  /// Throws [supabase.PostgrestException] on 42501 or 23503.
  Future<void> setAdActive({
    required String adId,
    required bool isActive,
  }) async {
    await _client.rpc(
      'set_ad_active',
      params: {'p_ad_id': adId, 'p_is_active': isActive},
    );
  }

  /// Calls `archive_ad(p_ad_id)` SECURITY DEFINER RPC (soft-delete).
  ///
  /// Throws [supabase.PostgrestException] on 42501 or 23503.
  Future<void> archiveAd(String adId) async {
    await _client.rpc('archive_ad', params: {'p_ad_id': adId});
  }

  // ---------------------------------------------------------------------------
  // Read path
  // ---------------------------------------------------------------------------

  /// Reads all ads from `public.ads` joined with `public.ad_placements`.
  ///
  /// Admin SELECT policy requires `ads.manage`. [includeArchived] = false
  /// (default) filters `archived_at IS NULL`.
  ///
  /// Returns a list of [AdDto] objects.
  Future<List<AdDto>> loadAds({bool includeArchived = false}) async {
    final baseQuery = _client
        .from('ads')
        .select(
          'id, title, image_path, caption_ar, caption_en, link_kind, '
          'link_value, start_at, end_at, is_active, archived_at, created_at, '
          'ad_placements(placement_key, priority)',
        );

    final List<dynamic> rows;
    if (includeArchived) {
      rows = await baseQuery.order('created_at', ascending: false);
    } else {
      // Filter `archived_at IS NULL` before applying transform (order).
      rows = await baseQuery
          .isFilter('archived_at', null)
          .order('created_at', ascending: false);
    }

    return rows
        .map((r) => AdDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generates a random UUID v4 string for the storage path prefix.
  ///
  /// Uses `dart:math`'s [Random] (no `uuid` package — FR-025) to produce 16
  /// genuinely random bytes with the v4 version/variant bits set. A per-byte
  /// `DateTime.now()` scheme was rejected: 16 rapid clock reads yield near-zero
  /// entropy, so concurrent/rapid uploads would collide on the same `{prefix}/`
  /// path (`uploadBinary` is non-upsert → 409 Duplicate, or cross-ad overlap).
  /// The output matches the `ads` bucket's `{8-4-4-4-12 hex}/…` policy regex.
  String _generateUuid() {
    final rnd = Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  String _extensionForContentType(String contentType) {
    switch (contentType) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/jpeg':
      default:
        return '.jpg';
    }
  }
}
