// Phase 21 (spec/021-ads-banners) — ServingAd entity.
//
// Public projection from `public.v_ads_serving` (R-166 / FR-020).
// Contains ONLY the fields needed to render + tap a banner:
//   ad_id, image_path, caption_ar, caption_en, link_kind, link_value,
//   placement_key, priority.
//
// Admin-only fields (title, schedule, created_by, is_active) are NOT present.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:equatable/equatable.dart';

import 'ad_link.dart';
import 'ad_placement.dart';

/// Public render + tap projection of a banner ad served from `v_ads_serving`.
///
/// Returned by [AdsServingRepository.loadServingAds].
class ServingAd extends Equatable {
  const ServingAd({
    required this.adId,
    required this.imagePath,
    required this.linkKind,
    required this.linkValue,
    required this.placement,
    required this.priority,
    this.captionAr,
    this.captionEn,
  });

  /// UUID of the backing `ads` row.
  final String adId;

  /// Storage path in the `ads` bucket. Resolve to a display URL via
  /// `supabase.storage.from('ads').getPublicUrl(imagePath)` in the widget
  /// layer.
  final String imagePath;

  /// Optional bilingual caption — Arabic (R-172). Both or neither are non-null.
  final String? captionAr;

  /// Optional bilingual caption — English (R-172). Both or neither are non-null.
  final String? captionEn;

  /// Tap-through discriminator (R-169).
  final AdLinkKind linkKind;

  /// Tap-through payload (R-179).
  final String linkValue;

  /// The placement this serving row belongs to.
  final AdPlacement placement;

  /// Carousel priority within the placement (higher → earlier).
  final int priority;

  @override
  List<Object?> get props => [
    adId,
    imagePath,
    captionAr,
    captionEn,
    linkKind,
    linkValue,
    placement,
    priority,
  ];
}
