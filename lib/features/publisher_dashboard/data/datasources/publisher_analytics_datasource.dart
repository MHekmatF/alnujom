// Phase 25 premium uplift v2 — publisher lead analytics.
// PublisherAnalyticsDatasource: calls the two lead-analytics SECURITY DEFINER
// RPCs (both scoped to auth.uid()) and returns their rows as DTO lists. Mirrors
// PublisherDashboardCountsDatasource. Constitution IX: Supabase types confined
// here.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/publisher_lead_analytics_dto.dart';

@injectable
class PublisherAnalyticsDatasource {
  PublisherAnalyticsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Invokes `publisher_lead_analytics_by_listing()` (SECURITY DEFINER, scoped
  /// to `auth.uid()`). Returns one DTO per listing the publisher owns; an empty
  /// result (no listings yet) yields an empty list.
  Future<List<PublisherListingLeadAnalyticsDto>> fetchByListing() async {
    final result = await _client.rpc('publisher_lead_analytics_by_listing');
    final rows = result as List<dynamic>;
    return rows
        .map(
          (row) => PublisherListingLeadAnalyticsDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  /// Invokes `publisher_lead_totals_by_day(p_days)` (SECURITY DEFINER, scoped
  /// to `auth.uid()`). Days with zero events are omitted by the RPC — gaps are
  /// filled by the repository, not here.
  Future<List<PublisherDailyLeadTotalDto>> fetchTotalsByDay({
    int days = 30,
  }) async {
    final result = await _client.rpc(
      'publisher_lead_totals_by_day',
      params: {'p_days': days},
    );
    final rows = result as List<dynamic>;
    return rows
        .map(
          (row) => PublisherDailyLeadTotalDto.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }
}
