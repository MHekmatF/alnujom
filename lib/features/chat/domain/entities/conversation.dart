// lib/features/chat/domain/entities/conversation.dart
//
// In-app chat — domain entity for one conversation in the list.

/// Immutable domain representation of a `public.conversations` row, augmented
/// with the listing heading (title + image) the UI renders.
class Conversation {
  const Conversation({
    required this.id,
    required this.listingId,
    required this.otherIsPublisher,
    required this.lastMessageAt,
    this.listingTitle,
    this.listingImageUrl,
  });

  /// UUID primary key (also the route argument to the thread page).
  final String id;

  final String listingId;

  /// Listing title used as the conversation heading. May be null when RLS
  /// hides the listing (deleted/unapproved) — the UI falls back to a generic
  /// label.
  final String? listingTitle;

  /// Resolved public URL for the listing's main image (heading thumbnail).
  final String? listingImageUrl;

  /// `true` when the OTHER party is the listing's publisher (i.e. the caller is
  /// the buyer); `false` when the caller is the publisher talking to a buyer.
  final bool otherIsPublisher;

  /// Last activity time — the list is ordered by this descending.
  final DateTime lastMessageAt;

  @override
  String toString() => 'Conversation(id: $id, listingId: $listingId)';
}
