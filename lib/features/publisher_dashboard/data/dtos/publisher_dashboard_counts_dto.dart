// Phase 25 premium uplift v2 — publisher summary dashboard.
// PublisherDashboardCountsDto: maps the publisher_dashboard_counts() RPC row to
// the domain entity. Constitution IX: only data/dtos imports the domain entity.

import '../../domain/entities/publisher_dashboard_counts.dart';

class PublisherDashboardCountsDto {
  const PublisherDashboardCountsDto({
    required this.totalListings,
    required this.activeListings,
    required this.pendingListings,
    required this.rejectedListings,
    required this.totalInquiries,
    required this.newInquiries,
    required this.leadEventsTotal,
  });

  final int totalListings;
  final int activeListings;
  final int pendingListings;
  final int rejectedListings;
  final int totalInquiries;
  final int newInquiries;
  final int leadEventsTotal;

  factory PublisherDashboardCountsDto.fromJson(Map<String, dynamic> json) {
    return PublisherDashboardCountsDto(
      totalListings: _toInt(json['total_listings']),
      activeListings: _toInt(json['active_listings']),
      pendingListings: _toInt(json['pending_listings']),
      rejectedListings: _toInt(json['rejected_listings']),
      totalInquiries: _toInt(json['total_inquiries']),
      newInquiries: _toInt(json['new_inquiries']),
      leadEventsTotal: _toInt(json['lead_events_total']),
    );
  }

  PublisherDashboardCounts toEntity() {
    return PublisherDashboardCounts(
      totalListings: totalListings,
      activeListings: activeListings,
      pendingListings: pendingListings,
      rejectedListings: rejectedListings,
      totalInquiries: totalInquiries,
      newInquiries: newInquiries,
      leadEventsTotal: leadEventsTotal,
    );
  }

  /// Coerces a JSON scalar to a non-null int, defaulting to 0 for missing rows.
  /// Supabase may return BIGINT as int, num, or String depending on the client.
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
