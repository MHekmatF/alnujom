// Phase 20 (spec/020-admin-dashboard) — T013
// DashboardCountsDto: maps the admin_dashboard_counts() RPC row to the domain
// DashboardCounts entity. Preserves null (= not permitted) vs. 0 (= permitted
// but empty). Constitution IX: only data/dtos imports the domain entity.

import '../../domain/entities/dashboard_counts.dart';

class DashboardCountsDto {
  const DashboardCountsDto({
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

  factory DashboardCountsDto.fromJson(Map<String, dynamic> json) {
    return DashboardCountsDto(
      pendingUsers: _toInt(json['pending_users']),
      pendingListings: _toInt(json['pending_listings']),
      openReports: _toInt(json['open_reports']),
      newInquiries24h: _toInt(json['new_inquiries_24h']),
      activeListings: _toInt(json['active_listings']),
    );
  }

  DashboardCounts toEntity() {
    return DashboardCounts(
      pendingUsers: pendingUsers,
      pendingListings: pendingListings,
      openReports: openReports,
      newInquiries24h: newInquiries24h,
      activeListings: activeListings,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    // Supabase may return BIGINT as String in some clients.
    if (value is String) return int.tryParse(value);
    return null;
  }
}
