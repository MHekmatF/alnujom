// lib/features/notifications/domain/entities/notification_type.dart
//
// Phase 22 — NotificationType enum matching the `type` CHECK constraint on
// `public.notifications`.  Six values exactly (FR-001).
//
// Phase 25 — `savedSearchMatch` added: a DB trigger inserts a
// `saved_search_match` notification when a newly-public listing matches a
// saved search (params: listing_id, listing_title, saved_search_id,
// saved_search_label).

/// Mirrors the `type` CHECK values in the `notifications` table.
enum NotificationType {
  accountApproved,
  accountRejected,
  listingApproved,
  listingRejected,
  inquiryReceived,
  agencyInvitation,
  savedSearchMatch,
  // Plan A16 — the two things that actually bring someone back to the app.
  messageReceived,
  viewingRequested,
  viewingConfirmed,
  viewingDeclined,
  viewingCancelled;

  /// The wire key stored in the database and carried in push payloads.
  String get key {
    switch (this) {
      case NotificationType.accountApproved:
        return 'account_approved';
      case NotificationType.accountRejected:
        return 'account_rejected';
      case NotificationType.listingApproved:
        return 'listing_approved';
      case NotificationType.listingRejected:
        return 'listing_rejected';
      case NotificationType.inquiryReceived:
        return 'inquiry_received';
      case NotificationType.agencyInvitation:
        return 'agency_invitation';
      case NotificationType.savedSearchMatch:
        return 'saved_search_match';
      case NotificationType.messageReceived:
        return 'message_received';
      case NotificationType.viewingRequested:
        return 'viewing_requested';
      case NotificationType.viewingConfirmed:
        return 'viewing_confirmed';
      case NotificationType.viewingDeclined:
        return 'viewing_declined';
      case NotificationType.viewingCancelled:
        return 'viewing_cancelled';
    }
  }

  /// Parses a wire key.  Returns `null` for unknown values so callers can
  /// degrade gracefully rather than throw.
  static NotificationType? fromKey(String key) {
    for (final value in NotificationType.values) {
      if (value.key == key) return value;
    }
    return null;
  }
}
