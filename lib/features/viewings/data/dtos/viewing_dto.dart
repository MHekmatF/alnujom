// lib/features/viewings/data/dtos/viewing_dto.dart
//
// Viewing scheduler — DTO mirroring a row from `public.viewings` joined with
// the listing title (for the list heading).
//
// Column layout (viewings):
//   id                  uuid (PK)
//   listing_id          uuid
//   requester_user_id   uuid (DB-defaulted to auth.uid())
//   publisher_user_id   uuid
//   scheduled_at        timestamptz
//   status              text in (requested|confirmed|declined|cancelled)
//   note                text
//   created_at          timestamptz
//   updated_at          timestamptz
//
// The datasource embeds `listing:listings(title)` so the list can render a
// heading without a second query. `amIPublisher` is computed in the mapping
// layer from the caller's user id (publisher_user_id == currentUserId).

import '../../domain/entities/viewing.dart';

/// DTO for a `public.viewings` row plus the embedded listing title.
class ViewingDto {
  const ViewingDto({
    required this.id,
    required this.listingId,
    required this.publisherUserId,
    required this.scheduledAt,
    required this.status,
    this.listingTitle,
    this.note,
  });

  final String id;
  final String listingId;
  final String publisherUserId;
  final DateTime scheduledAt;

  /// Raw status string from the DB (one of requested/confirmed/declined/
  /// cancelled). Mapped to the enum in [toEntity].
  final String status;

  /// Listing heading (embedded join). May be null if RLS hides the listing.
  final String? listingTitle;

  final String? note;

  factory ViewingDto.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'];
    String? title;
    if (listing is Map) {
      final raw = listing['title'];
      if (raw is String && raw.isNotEmpty) title = raw;
    }
    return ViewingDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      publisherUserId: json['publisher_user_id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String,
      listingTitle: title,
      note: json['note'] as String?,
    );
  }

  /// Maps to the domain entity. [currentUserId] decides whether the caller is
  /// the listing's publisher (the reviewer) vs the requester.
  Viewing toEntity(String currentUserId) {
    return Viewing(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      scheduledAt: scheduledAt,
      status: ViewingStatus.fromRaw(status),
      note: note,
      amIPublisher: currentUserId == publisherUserId,
    );
  }
}
