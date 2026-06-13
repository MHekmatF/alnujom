// Phase 29 (029-crm-reels-growth) — W2: admin analytics DTOs.
// Maps the chart RPC rows to domain entities. Constitution IX: only data/dtos
// imports the domain entities; Supabase scalar coercion (BIGINT may arrive as
// int/num/String; date as ISO string) is confined here.
import '../../domain/entities/admin_analytics.dart';

/// Maps one `admin_listings_by_month()` / `admin_profiles_by_month()` row.
class AdminMonthlyTotalDto {
  const AdminMonthlyTotalDto({required this.month, required this.total});

  final DateTime month;
  final int total;

  factory AdminMonthlyTotalDto.fromJson(Map<String, dynamic> json) {
    return AdminMonthlyTotalDto(
      month: _toDay(json['month']),
      total: _toInt(json['total']),
    );
  }

  AdminMonthlyTotal toEntity() =>
      AdminMonthlyTotal(month: month, total: total);
}

/// Maps one `admin_lead_events_by_day()` row.
class AdminDailyTotalDto {
  const AdminDailyTotalDto({required this.day, required this.total});

  final DateTime day;
  final int total;

  factory AdminDailyTotalDto.fromJson(Map<String, dynamic> json) {
    return AdminDailyTotalDto(
      day: _toDay(json['day']),
      total: _toInt(json['total']),
    );
  }

  AdminDailyTotal toEntity() => AdminDailyTotal(day: day, total: total);
}

/// Maps one `admin_listings_by_governorate()` row.
class AdminGovernorateTotalDto {
  const AdminGovernorateTotalDto({
    required this.nameAr,
    required this.nameEn,
    required this.total,
  });

  final String nameAr;
  final String nameEn;
  final int total;

  factory AdminGovernorateTotalDto.fromJson(Map<String, dynamic> json) {
    return AdminGovernorateTotalDto(
      nameAr: (json['governorate_name_ar'] ?? '').toString(),
      nameEn: (json['governorate_name_en'] ?? '').toString(),
      total: _toInt(json['total']),
    );
  }

  AdminGovernorateTotal toEntity() =>
      AdminGovernorateTotal(nameAr: nameAr, nameEn: nameEn, total: total);
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

/// Parses a Postgres `date` value to a date-only [DateTime], defaulting to the
/// epoch when unparseable.
DateTime _toDay(dynamic value) {
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
