// Phase 20 (spec/020-admin-dashboard) — T012
// DashboardCounts entity: five nullable counter fields from admin_dashboard_counts().
// Constitution IX: pure Dart, no Supabase import.

/// Operational counters returned by the admin_dashboard_counts() RPC.
///
/// - A [null] value means the caller lacks the permission to see that counter
///   (the section tile should omit the counter badge entirely — FR-010).
/// - A [0] value means the caller IS permitted and the count is genuinely zero
///   (still rendered, just styled differently — FR-010).
class DashboardCounts {
  const DashboardCounts({
    this.pendingUsers,
    this.pendingListings,
    this.openReports,
    this.newInquiries24h,
    this.activeListings,
  });

  final int? pendingUsers;
  final int? pendingListings;
  final int? openReports;
  final int? newInquiries24h;
  final int? activeListings;
}
