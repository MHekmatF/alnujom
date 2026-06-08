// Phase 25 premium uplift v2 — publisher lead analytics.
// DTOs mapping the two lead-analytics RPC rows to domain entities.
// Constitution IX: only data/dtos imports the domain entities; Supabase scalar
// coercion is confined here (BIGINT may arrive as int/num/String).
import '../../domain/entities/publisher_lead_analytics.dart';

/// Maps one `publisher_lead_analytics_by_listing()` row → entity.
class PublisherListingLeadAnalyticsDto {
  const PublisherListingLeadAnalyticsDto({
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

  final String listingId;
  final String title;
  final String status;
  final bool featured;
  final int phoneCount;
  final int whatsappCount;
  final int inquiryCount;
  final int favoriteCount;
  final int total;

  factory PublisherListingLeadAnalyticsDto.fromJson(Map<String, dynamic> json) {
    return PublisherListingLeadAnalyticsDto(
      listingId: (json['listing_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      featured: _toBool(json['featured']),
      phoneCount: _toInt(json['phone_count']),
      whatsappCount: _toInt(json['whatsapp_count']),
      inquiryCount: _toInt(json['inquiry_count']),
      favoriteCount: _toInt(json['favorite_count']),
      total: _toInt(json['total']),
    );
  }

  PublisherListingLeadAnalytics toEntity() {
    return PublisherListingLeadAnalytics(
      listingId: listingId,
      title: title,
      status: status,
      featured: featured,
      phoneCount: phoneCount,
      whatsappCount: whatsappCount,
      inquiryCount: inquiryCount,
      favoriteCount: favoriteCount,
      total: total,
    );
  }
}

/// Maps one `publisher_lead_totals_by_day()` row → entity.
class PublisherDailyLeadTotalDto {
  const PublisherDailyLeadTotalDto({required this.day, required this.total});

  final DateTime day;
  final int total;

  factory PublisherDailyLeadTotalDto.fromJson(Map<String, dynamic> json) {
    return PublisherDailyLeadTotalDto(
      day: _toDay(json['day']),
      total: _toInt(json['total']),
    );
  }

  PublisherDailyLeadTotal toEntity() {
    return PublisherDailyLeadTotal(day: day, total: total);
  }
}

/// Coerces a JSON scalar to a non-null int (Supabase BIGINT may arrive as int,
/// num, or String), defaulting to 0.
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Coerces a JSON value to a non-null bool, defaulting to false.
bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return false;
}

/// Parses a Postgres `date` value to a date-only [DateTime] (local), defaulting
/// to the epoch when unparseable. The RPC returns `day` as an ISO date string.
DateTime _toDay(dynamic value) {
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
