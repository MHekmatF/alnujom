// Phase 20 (spec/020-admin-dashboard) — T013
// DashboardCountsDatasource: sole Supabase importer in the dashboard feature.
// Calls admin_dashboard_counts() RPC and returns the single row as a DTO.
// Constitution IX: all Supabase types are confined here.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/dashboard_counts_dto.dart';

@injectable
class DashboardCountsDatasource {
  DashboardCountsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Invokes the admin_dashboard_counts() SECURITY DEFINER function.
  /// Returns one [DashboardCountsDto]. Null fields = not permitted.
  Future<DashboardCountsDto> fetchCounts() async {
    final result = await _client.rpc('admin_dashboard_counts');
    // The RPC returns RETURNS TABLE → Supabase client gives a List<dynamic>
    // with one row (or empty if the function returns no rows).
    final rows = result as List<dynamic>;
    if (rows.isEmpty) {
      return const DashboardCountsDto();
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    return DashboardCountsDto.fromJson(row);
  }
}
