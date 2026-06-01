// Phase 21 (spec/021-ads-banners) — ServingAdDto.
//
// DTO mirroring a row from `public.v_ads_serving` (data-model §4 / R-166).
//
// v_ads_serving projected columns:
//   ad_id, image_path, caption_ar, caption_en, link_kind, link_value,
//   placement_key, priority
//
// No supabase_flutter import — Supabase coupling is at the datasource boundary.

import '../../domain/entities/ad_link.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/serving_ad.dart';

class ServingAdDto {
  const ServingAdDto({
    required this.adId,
    required this.imagePath,
    required this.linkKind,
    required this.linkValue,
    required this.placement,
    required this.priority,
    this.captionAr,
    this.captionEn,
  });

  final String adId;
  final String imagePath;
  final String? captionAr;
  final String? captionEn;
  final AdLinkKind linkKind;
  final String linkValue;
  final AdPlacement placement;
  final int priority;

  factory ServingAdDto.fromJson(Map<String, dynamic> json) {
    return ServingAdDto(
      adId: json['ad_id'] as String,
      imagePath: json['image_path'] as String,
      captionAr: json['caption_ar'] as String?,
      captionEn: json['caption_en'] as String?,
      linkKind: AdLinkKind.fromWire(json['link_kind'] as String),
      linkValue: json['link_value'] as String,
      placement: AdPlacement.fromWire(json['placement_key'] as String),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  ServingAd toEntity() => ServingAd(
        adId: adId,
        imagePath: imagePath,
        captionAr: captionAr,
        captionEn: captionEn,
        linkKind: linkKind,
        linkValue: linkValue,
        placement: placement,
        priority: priority,
      );
}
