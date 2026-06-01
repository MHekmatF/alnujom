// lib/features/notifications/domain/entities/notification_type.dart
//
// Phase 22 — NotificationType enum matching the `type` CHECK constraint on
// `public.notifications`.  Six values exactly (FR-001).

/// Mirrors the `type` CHECK values in the `notifications` table.
enum NotificationType {
  accountApproved,
  accountRejected,
  listingApproved,
  listingRejected,
  inquiryReceived,
  agencyInvitation;

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
