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
    storagePath: storagePath,
    externalUrl: externalUrl,
    ordering: ordering,
    isMain: isMain,
    watermarked: watermarked,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
