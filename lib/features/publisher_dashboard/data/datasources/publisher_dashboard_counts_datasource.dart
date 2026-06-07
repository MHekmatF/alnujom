// Phase 25 premium uplift v2 — publisher summary dashboard.
// PublisherDashboardCountsDatasource: calls the publisher_dashboard_counts()
// RPC and returns the single row as a DTO. Mirrors the admin
// DashboardCountsDatasource. Constitution IX: Supabase types confined here.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/publisher_dashboard_counts_dto.dart';

@injectable
class PublisherDashboardCountsDatasource {
  PublisherDashboardCountsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Invokes the `publisher_dashboard_counts()` SECURITY DEFINER function,
  /// scoped to `auth.uid()`. Returns one [PublisherDashboardCountsDto];
  /// an empty result (no listings yet) yields all-zero counters.
  Future<PublisherDashboardCountsDto> fetchCounts() async {
    final result = await _client.rpc('publisher_dashboard_counts');
    // RETURNS TABLE → the client gives a List<dynamic> with one row.
    final rows = result as List<dynamic>;
    if (rows.isEmpty) {
      return const PublisherDashboardCountsDto(
        totalListings: 0,
        activeListings: 0,
        pendingListings: 0,
        rejectedListings: 0,
        totalInquiries: 0,
        newInquiries: 0,
        leadEventsTotal: 0,
      );
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    return PublisherDashboardCountsDto.fromJson(row);
  }
}
