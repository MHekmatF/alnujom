import '../../domain/entities/listing_media.dart';

/// Phase 11 — DTO mirroring the `public.listing_media` DB row shape.
///
/// Field names are camelCase Dart conventions; the JSON keys remain the
/// snake_case DB column names per Supabase/PostgREST convention.
class ListingMediaDto {
  ListingMediaDto({
    required this.id,
    required this.listingId,
    required this.kind,
    this.storagePath,
    this.externalUrl,
    this.thumbnailPath,
    required this.ordering,
    required this.isMain,
    required this.watermarked,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listingId;
  final String kind; // 'image' | 'video' | 'external_link'
  final String? storagePath;
  final String? externalUrl;

  /// Phase 030 (W1) — poster JPEG path in the `listing-images` bucket for a
  /// video row (null for images / older rows). Read defensively: the column is
  /// nullable and absent from pre-migration rows.
  final String? thumbnailPath;
  final int ordering;
  final bool isMain;
  final bool watermarked;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ListingMediaDto.fromJson(Map<String, dynamic> json) {
    return ListingMediaDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      kind: json['kind'] as String,
      storagePath: json['storage_path'] as String?,
      externalUrl: json['external_url'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      ordering: (json['ordering'] as num).toInt(),
      isMain: json['is_main'] as bool,
      watermarked: json['watermarked'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  ListingMedia toEntity() => ListingMedia(
    id: id,
    listingId: listingId,
    kind: ListingMediaKind.fromDbValue(kind),
    // Preserve the raw free-text kind so the listing-details gallery can
    // detect a 360° panorama (which the closed enum collapses to `image`).
    rawKind: kind,
    storagePath: storagePath,
    externalUrl: externalUrl,
    thumbnailPath: thumbnailPath,
    ordering: ordering,
    isMain: isMain,
    watermarked: watermarked,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
