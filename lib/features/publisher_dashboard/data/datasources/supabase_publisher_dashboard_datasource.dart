import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dtos/publisher_listing_dto.dart';

/// Sole importer of `package:supabase_flutter` in
/// `lib/features/publisher_dashboard/` per Constitution IX.
///
/// Reads the SQL view `public.v_publisher_listings` (created in Phase 2
/// migration 8). The view does the most-recent-history-row + primary-price
/// joins server-side, so this datasource is a single PostgREST query. RLS
/// inheritance on the view means the calling user only sees their own rows
/// (or all rows if they hold `listings.view_all` — admin path).
@injectable
class SupabasePublisherDashboardDatasource {
  SupabasePublisherDashboardDatasource(this._client);

  final SupabaseClient _client;

  Future<List<PublisherListingDto>> listMyListings({
    String? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    var query = _client.from('v_publisher_listings').select();
    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((r) => PublisherListingDto.fromMap(r)).toList();
  }
}
