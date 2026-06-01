// Phase 21 (spec/021-ads-banners) — SupabaseAdsServingDatasource.
//
// SOLE importer of supabase_flutter for the public serving surface.
// Per Constitution IX: domain/ and data/dtos/ have ZERO supabase_flutter imports.
//
// Responsibilities:
//   - v_ads_serving SELECT per placement (FR-009 / FR-013)
//   - record_ad_event RPC (FR-016 / R-167)

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/serving_ad_dto.dart';

@injectable
class SupabaseAdsServingDatasource {
  SupabaseAdsServingDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // Serving read
  // ---------------------------------------------------------------------------

  /// Queries `public.v_ads_serving` filtered to [placementKey], ordered by
  /// `priority DESC` then `ad_id` (stable tie-break — FR-013 / R-173).
  ///
  /// The SECURITY DEFINER view returns only eligible ads (active + in-window +
  /// not archived) and is accessible to anon + authenticated (R-166 / FR-020).
  ///
  /// Throws [supabase.PostgrestException] on query failure.
  Future<List<ServingAdDto>> loadServingAds(String placementKey) async {
    final rows = await _client
        .from('v_ads_serving')
        .select(
          'ad_id, image_path, caption_ar, caption_en, link_kind, link_value, '
          'placement_key, priority',
        )
        .eq('placement_key', placementKey)
        .order('priority', ascending: false)
        .order('ad_id');

    return (rows as List<dynamic>)
        .map((r) => ServingAdDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Click recorder
  // ---------------------------------------------------------------------------

  /// Calls `record_ad_event(p_ad_id, p_placement_key)` SECURITY DEFINER RPC.
  ///
  /// Returns the new event UUID. Best-effort — callers MUST proceed to open
  /// the link target even if this throws (FR-017).
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - 23514 ad_not_eligible (ad no longer eligible at tap time)
  Future<String> recordAdEvent({
    required String adId,
    required String placementKey,
  }) async {
    final result = await _client.rpc(
      'record_ad_event',
      params: {
        'p_ad_id': adId,
        'p_placement_key': placementKey,
      },
    );
    return result as String;
  }
}
