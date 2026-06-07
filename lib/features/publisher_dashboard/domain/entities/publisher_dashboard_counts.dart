// Phase 25 premium uplift v2 — publisher summary dashboard.
// PublisherDashboardCounts entity: the operational KPIs returned by the
// publisher_dashboard_counts() RPC for the authenticated publisher.
// Constitution IX: pure Dart, no Supabase import.

/// Operational counters returned by the `publisher_dashboard_counts()` RPC for
/// `auth.uid()`.
///
/// Every field is a plain (non-null) `int` — the RPC always returns a single
/// row scoped to the caller, with `0` for genuinely-empty buckets. There is no
/// null/0 permission distinction here (unlike the admin counters): a publisher
/// always sees their own totals.
class PublisherDashboardCounts {
  const PublisherDashboardCounts({
    required this.totalListings,
    required this.activeListings,
    required this.pendingListings,
    required this.rejectedListings,
    required this.totalInquiries,
    required this.newInquiries,
    required this.leadEventsTotal,
  });

  /// All listings the publisher owns, regardless of status.
  final int totalListings;

  /// Listings currently live (approved + visible).
  final int activeListings;

  /// Listings awaiting moderation.
  final int pendingListings;

  /// Listings rejected by moderation (need attention / resubmit).
  final int rejectedListings;

  /// Total inquiries received across all listings.
  final int totalInquiries;

  /// Inquiries that are new / unread.
  final int newInquiries;

  /// Total lead events (contact reveals, WhatsApp taps, etc.).
  final int leadEventsTotal;

  /// A zeroed instance — used as an optimistic placeholder while a refresh is
  /// in flight so the stat grid never has to collapse to a spinner.
  static const empty = PublisherDashboardCounts(
    totalListings: 0,
    activeListings: 0,
    pendingListings: 0,
    rejectedListings: 0,
    totalInquiries: 0,
    newInquiries: 0,
    leadEventsTotal: 0,
  );
}
