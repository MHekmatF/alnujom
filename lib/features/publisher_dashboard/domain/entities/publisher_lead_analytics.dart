// Phase 25 premium uplift v2 — publisher lead analytics.
// Domain entities for the lead-analytics surface: per-listing lead breakdown
// (publisher_lead_analytics_by_listing()) + daily lead totals
// (publisher_lead_totals_by_day()). Constitution IX: pure Dart, no Supabase.

/// Lead-source breakdown for a single listing owned by the authenticated
/// publisher, returned by the `publisher_lead_analytics_by_listing()` RPC.
///
/// Every counter is a plain (non-null) `int` — the RPC scopes to `auth.uid()`
/// and yields `0` for genuinely-empty buckets. [total] is the server-computed
/// sum across the four lead sources.
class PublisherListingLeadAnalytics {
  const PublisherListingLeadAnalytics({
    required this.listingId,
    required this.title,
    required this.status,
    required this.featured,
    required this.phoneCount,
    required this.whatsappCount,
    required this.inquiryCount,
    required this.favoriteCount,
    required this.total,
  });

  /// The listing's UUID.
  final String listingId;

  /// The listing's display title.
  final String title;

  /// The listing's moderation/visibility status (e.g. `approved`, `pending`).
  final String status;

  /// Whether the listing is currently featured.
  final bool featured;

  /// Phone reveals (`phone_revealed` lead events).
  final int phoneCount;

  /// WhatsApp taps (`whatsapp_clicked` lead events).
  final int whatsappCount;

  /// Inquiries sent (`inquiry_sent` lead events).
  final int inquiryCount;

  /// Favourites added (`favorite_added` lead events).
  final int favoriteCount;

  /// Server-computed sum across the four lead sources.
  final int total;
}

/// A single (day, total) point in the publisher's daily lead trend, returned by
/// the `publisher_lead_totals_by_day()` RPC.
///
/// Note: the RPC omits days with zero events — gaps are filled client-side so
/// the bar chart has one bar per calendar day across the window.
class PublisherDailyLeadTotal {
  const PublisherDailyLeadTotal({required this.day, required this.total});

  /// The calendar day (date only — no time component is meaningful).
  final DateTime day;

  /// Total lead events recorded on [day] (>= 0; gap-filled days carry `0`).
  final int total;
}

/// The full lead-analytics payload for the authenticated publisher: the daily
/// trend (gap-filled by the repository) plus the per-listing breakdown.
class PublisherLeadAnalytics {
  const PublisherLeadAnalytics({
    required this.byDay,
    required this.byListing,
  });

  /// Gap-filled daily totals, oldest → newest (one entry per calendar day).
  final List<PublisherDailyLeadTotal> byDay;

  /// Per-listing breakdown, ordered as returned by the RPC (busiest first).
  final List<PublisherListingLeadAnalytics> byListing;

  /// The grand total of lead events across the window (sum of [byDay]).
  int get totalLeads => byDay.fold(0, (sum, point) => sum + point.total);

  /// True when there is nothing to chart and no listing has any leads.
  bool get isEmpty =>
      totalLeads == 0 && byListing.every((listing) => listing.total == 0);

  /// An empty payload — handy as an optimistic placeholder.
  static const empty = PublisherLeadAnalytics(byDay: [], byListing: []);
}
