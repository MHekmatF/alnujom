// Phase 21 (spec/021-ads-banners) — AdDto.
//
// DTO mirroring a row from `public.ads` joined with its `public.ad_placements`
// rows (datasource SELECT includes the placements via a nested select or join).
//
// Wire column names:
//   id, title, image_path, caption_ar, caption_en, link_kind, link_value,
//   start_at, end_at, is_active, archived_at, created_at
//   + nested placements: [{ placement_key, priority }]
//
// No supabase_flutter import — Supabase coupling is at the datasource boundary.

import '../../domain/entities/ad.dart';
import '../../domain/entities/ad_link.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/ad_placement_assignment.dart';

class AdDto {
  const AdDto({
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

  final String id;
  final String title;
  final String imagePath;
  final String? captionAr;
  final String? captionEn;
  final AdLinkKind linkKind;
  final String linkValue;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final DateTime? archivedAt;
  final List<AdPlacementAssignment> placements;
  final DateTime createdAt;

  /// Deserializes a row returned by the admin SELECT on `public.ads`.
  ///
  /// Expects `ad_placements` to be nested as a list under the key
  /// `'ad_placements'` (PostgREST nested select / join result shape).
  factory AdDto.fromJson(Map<String, dynamic> json) {
    final rawPlacements =
        (json['ad_placements'] as List<dynamic>?) ?? <dynamic>[];
    final placements = rawPlacements.map((p) {
      final row = p as Map<String, dynamic>;
      return AdPlacementAssignment(
        placement: AdPlacement.fromWire(row['placement_key'] as String),
        priority: (row['priority'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    return AdDto(
      id: json['id'] as String,
      title: json['title'] as String,
      imagePath: json['image_path'] as String,
      captionAr: json['caption_ar'] as String?,
      captionEn: json['caption_en'] as String?,
      linkKind: AdLinkKind.fromWire(json['link_kind'] as String),
      linkValue: json['link_value'] as String,
      startAt: json['start_at'] == null
          ? null
          : DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] == null
          ? null
          : DateTime.parse(json['end_at'] as String),
      isActive: json['is_active'] as bool,
      archivedAt: json['archived_at'] == null
          ? null
          : DateTime.parse(json['archived_at'] as String),
      placements: placements,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Ad toEntity() => Ad(
    id: id,
    title: title,
    imagePath: imagePath,
    captionAr: captionAr,
    captionEn: captionEn,
    linkKind: linkKind,
    linkValue: linkValue,
    startAt: startAt,
    endAt: endAt,
    isActive: isActive,
    archivedAt: archivedAt,
    placements: placements,
    createdAt: createdAt,
  );
}
