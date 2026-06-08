// lib/features/chat/data/dtos/conversation_dto.dart
//
// In-app chat — DTO mirroring a row from `public.conversations` joined with the
// listing title + main image (for the conversation heading).
//
// Column layout (conversations):
//   id                 uuid (PK)
//   listing_id         uuid
//   buyer_user_id      uuid
//   publisher_user_id  uuid
//   created_at         timestamptz
//   last_message_at    timestamptz
//
// The datasource embeds `listing:listings(title, listing_media(...))` so the
// list can render a heading + thumbnail without reading the counterpart's
// profile (which RLS hides).

import '../../domain/entities/conversation.dart';

/// DTO for a `public.conversations` row plus the embedded listing heading data.
class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.listingId,
    required this.buyerUserId,
    required this.publisherUserId,
    required this.lastMessageAt,
    this.listingTitle,
    this.listingImageUrl,
  });

  final String id;
  final String listingId;
  final String buyerUserId;
  final String publisherUserId;
  final DateTime lastMessageAt;

  /// Listing heading (embedded join). May be null if RLS hides the listing.
  final String? listingTitle;

  /// Resolved public URL for the listing's main image (computed in the
  /// datasource via `storage.from('listing-images').getPublicUrl(...)`).
  final String? listingImageUrl;

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'];
    String? title;
    if (listing is Map) {
      final raw = listing['title'];
      if (raw is String && raw.isNotEmpty) title = raw;
    }
    return ConversationDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      buyerUserId: json['buyer_user_id'] as String,
      publisherUserId: json['publisher_user_id'] as String,
      lastMessageAt: DateTime.parse(
        (json['last_message_at'] ?? json['created_at']) as String,
      ),
      listingTitle: title,
    );
  }

  ConversationDto copyWithListingImageUrl(String? url) => ConversationDto(
    id: id,
    listingId: listingId,
    buyerUserId: buyerUserId,
    publisherUserId: publisherUserId,
    lastMessageAt: lastMessageAt,
    listingTitle: listingTitle,
    listingImageUrl: url,
  );

  /// Maps to the domain entity. [currentUserId] decides whether the OTHER party
  /// is the publisher (true when the caller is the buyer).
  Conversation toEntity(String currentUserId) {
    return Conversation(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      listingImageUrl: listingImageUrl,
      otherIsPublisher: currentUserId == buyerUserId,
      lastMessageAt: lastMessageAt,
    );
  }
}
