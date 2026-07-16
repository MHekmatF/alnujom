// Phase 29 (029-crm-reels-growth) — W2: admin analytics datasource.
// Calls the four admin chart RPCs (each SECURITY DEFINER + permission-gated
// server-side) and returns their rows as DTO lists. A caller lacking a section
// permission gets ZERO rows from that RPC (empty list). Constitution IX:
// Supabase types confined here.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/admin_analytics_dto.dart';

@injectable
class AdminAnalyticsDatasource {
  AdminAnalyticsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// `admin_listings_by_month(p_months)` — gated by `listings.view_all`.
  Future<List<AdminMonthlyTotalDto>> fetchListingsByMonth({int months = 6}) async {
    final result = await _client.rpc(
      'admin_listings_by_month',
      params: {'p_months': months},
    );
    return (result as List<dynamic>)
        .map(
          (row) => AdminMonthlyTotalDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  /// `admin_profiles_by_month(p_months)` — gated by `users.view`.
  Future<List<AdminMonthlyTotalDto>> fetchProfilesByMonth({int months = 6}) async {
    final result = await _client.rpc(
      'admin_profiles_by_month',
      params: {'p_months': months},
    );
    return (result as List<dynamic>)
        .map(
          (row) => AdminMonthlyTotalDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  /// `admin_lead_events_by_day(p_days)` — gated by `inquiries.view_all`.
  Future<List<AdminDailyTotalDto>> fetchLeadEventsByDay({int days = 30}) async {
    final result = await _client.rpc(
      'admin_lead_events_by_day',
      params: {'p_days': days},
    );
    return (result as List<dynamic>)
        .map(
          (row) => AdminDailyTotalDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  /// `admin_listings_by_governorate()` — gated by `listings.view_all`.
  /// Invokes `admin_listings_by_category()` (SECURITY DEFINER, re-gated on
  /// `listings.view_all`). Returns (property_type, total) rows, busiest first.
  Future<List<AdminCategoryTotalDto>> fetchListingsByCategory() async {
    final result = await _client.rpc('admin_listings_by_category');
    final rows = result as List<dynamic>;
    return rows
        .map(
          (row) => AdminCategoryTotalDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  /// Invokes `admin_activity_by_dow_hour(p_days)` (SECURITY DEFINER, re-gated on
  /// `inquiries.view_all`). Returns one (dow, hour_bucket, total) row per
  /// non-empty cell.
  Future<List<AdminActivityCellDto>> fetchActivityByDowHour({
    int days = 30,
  }) async {
    final result = await _client.rpc(
      'admin_activity_by_dow_hour',
      params: {'p_days': days},
    );
    final rows = result as List<dynamic>;
    return rows
        .map(
          (row) => AdminActivityCellDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AdminGovernorateTotalDto>> fetchListingsByGovernorate() async {
    final result = await _client.rpc('admin_listings_by_governorate');
    return (result as List<dynamic>)
        .map(
          (row) => AdminGovernorateTotalDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }
}
