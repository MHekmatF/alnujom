// Phase 21 (spec/021-ads-banners) — Ad entity (admin view).
//
// Mirrors a row from `public.ads` (+ joined `public.ad_placements`).
// [status] is DERIVED — never stored in the DB (R-171). Computed from
// [isActive] + [archivedAt] + [startAt]/[endAt] vs `DateTime.now()`.
//
// Caption bilingual rule (R-172): both [captionAr] and [captionEn] are null
// (image-only), or both are non-null (bilingual).
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:equatable/equatable.dart';

import 'ad_link.dart';
import 'ad_placement_assignment.dart';
import 'ad_status.dart';

/// Admin view of a banner ad — includes title, schedule, and placement list.
///
/// Returned by [AdsAdminRepository.loadAds] and [AdsAdminRepository.createAd]/
/// [updateAd] (via a subsequent load). Public consumers see only [ServingAd].
class Ad extends Equatable {
  const Ad({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.linkKind,
    required this.linkValue,
    required this.isActive,
    required this.placements,
    required this.createdAt,
    this.captionAr,
    this.captionEn,
    this.startAt,
    this.endAt,
    this.archivedAt,
  });

  /// UUID primary key.
  final String id;

  /// Internal label (admin-facing only; never surfaced in [v_ads_serving]).
  final String title;

  /// Storage path in the `ads` bucket (NOT a URL; resolve via `getPublicUrl`).
  final String imagePath;

  /// Optional bilingual caption — Arabic text (R-172).
  /// When non-null, [captionEn] is also non-null.
  final String? captionAr;

  /// Optional bilingual caption — English text (R-172).
  /// When non-null, [captionAr] is also non-null.
  final String? captionEn;

  /// Tap-through discriminator (R-169).
  final AdLinkKind linkKind;

  /// Tap-through payload — encoding depends on [linkKind] (R-179).
  final String linkValue;

  /// Schedule window start — `null` means "no earliest bound".
  final DateTime? startAt;

  /// Schedule window end — `null` means "no expiry".
  final DateTime? endAt;

  /// `true` when the admin has toggled the ad on.
  final bool isActive;

  /// Non-null when the ad has been soft-deleted via `archive_ad` (R-170).
  final DateTime? archivedAt;

  /// Placement assignments for this ad (empty if none assigned).
  final List<AdPlacementAssignment> placements;

  final DateTime createdAt;

  /// Derived status computed from stored flags + current time (R-171).
  ///
  /// Do NOT store or compare across serialization boundaries; recompute
  /// from the stored fields when needed.
  AdStatus get status => AdStatus.compute(
        isActive: isActive,
        archivedAt: archivedAt,
        startAt: startAt,
        endAt: endAt,
      );

  @override
  List<Object?> get props => [
        id,
        title,
        imagePath,
        captionAr,
        captionEn,
        linkKind,
        linkValue,
        startAt,
        endAt,
        isActive,
        archivedAt,
        placements,
        createdAt,
      ];
}
