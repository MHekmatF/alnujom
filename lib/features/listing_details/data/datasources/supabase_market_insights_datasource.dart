import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Spec 028 — datasource for the listing-details "Market insights" section.
///
/// One of the files under `lib/features/listing_details/` importing
/// `package:supabase_flutter` per Constitution IX (alongside the existing
/// details / similar-listings datasources).
///
/// Calls the `market_price_trend` SECURITY DEFINER RPC, which returns ONLY
/// k-anonymous monthly aggregates (avg price + listing count per month and
/// currency) — never row-level listing data. Executable by anon (details is an
/// anonymous-browsing surface).
@injectable
class SupabaseMarketInsightsDatasource {
  const SupabaseMarketInsightsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Fetches the monthly average asking-price trend for the listing's area.
  ///
  /// Rows: `{month: 'yyyy-MM-dd', currency_code, avg_price, listing_count}`,
  /// ordered month ASC then currency.
  Future<List<Map<String, dynamic>>> fetchPriceTrend({
    required String governorateId,
    required String propertyType,
    String? cityId,
    String? purpose,
    int months = 6,
  }) async {
    final rows = await _client.rpc(
      'market_price_trend',
      params: {
        'p_governorate_id': governorateId,
        'p_property_type': propertyType,
        'p_city_id': cityId,
        'p_purpose': purpose,
        'p_months': months,
      },
    );
    return (rows as List<dynamic>)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList(growable: false);
  }
}
