// lib/features/search/data/datasources/supabase_search_datasource.dart
//
// Phase 14 — SOLE importer of the supabase_flutter package under
// `lib/features/search/` per Constitution IX (grep gate 2 in
// `quickstart.md` Step 4 must show exactly ONE matching file).
//
// Composes the `search_listings` RPC call from a [FilterState] + [SortOrder]
// + optional [SearchCursor] per contracts/phase14-search-listings-rpc.md.
//
// R-75 — price-range currency conversion: when the user picks a non-USD /
// non-SYP currency, fetch latest exchange rates via the Phase 9
// `latest_rates_for_base` RPC and pre-convert min/max bounds into both
// USD and SYP equivalents so the RPC's per-currency gating (see migration
// 20260525120003 Bug-1 fix) compares apples-to-apples against each listing's
// `primary_currency`.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/count_filter_mode.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/search_cursor.dart';
import '../../domain/entities/search_result_item.dart';
import '../../domain/entities/sort_order.dart';
import '../dtos/search_result_item_dto.dart';

@injectable
class SupabaseSearchDatasource {
  SupabaseSearchDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Fetches one page of search results. Returns at most [limit] items.
  ///
  /// Throws on transport / RPC failure — the repository layer wraps any
  /// exception in a [Failure] sealed-class value via [Result<T>].
  Future<List<SearchResultItem>> fetchPage({
    required FilterState filters,
    required SortOrder sort,
    SearchCursor? cursor,
    int limit = 20,
  }) async {
    // ---------------------------------------------------------------
    // R-75 — price-range currency conversion
    // ---------------------------------------------------------------
    double? priceMinUsd;
    double? priceMaxUsd;
    double? priceMinSyp;
    double? priceMaxSyp;

    final priceFilterActive =
        filters.priceMin != null || filters.priceMax != null;
    if (priceFilterActive) {
      final selectedCurrency = filters.priceCurrency;
      if (selectedCurrency == 'USD') {
        priceMinUsd = filters.priceMin;
        priceMaxUsd = filters.priceMax;
      } else if (selectedCurrency == 'SYP') {
        priceMinSyp = filters.priceMin;
        priceMaxSyp = filters.priceMax;
      } else if (selectedCurrency != null) {
        // Non-USD / non-SYP currency: fetch rates and convert.
        final ratesResult = await _client.rpc(
          'latest_rates_for_base',
          params: {'p_base_currency': selectedCurrency},
        );
        final list = ratesResult as List<dynamic>;
        final rateMap = <String, double>{
          for (final r in list)
            (r as Map<String, dynamic>)['target_currency'] as String:
                // NUMERIC may arrive as String on some Supabase driver versions.
                r['rate'] is num
                ? (r['rate'] as num).toDouble()
                : double.parse(r['rate'].toString()),
        };
        final usdRate = rateMap['USD'];
        final sypRate = rateMap['SYP'];

        if (usdRate != null) {
          if (filters.priceMin != null) {
            priceMinUsd = filters.priceMin! * usdRate;
          }
          if (filters.priceMax != null) {
            priceMaxUsd = filters.priceMax! * usdRate;
          }
        }
        if (sypRate != null) {
          if (filters.priceMin != null) {
            priceMinSyp = filters.priceMin! * sypRate;
          }
          if (filters.priceMax != null) {
            priceMaxSyp = filters.priceMax! * sypRate;
          }
        }
        // If both rates are missing we silently fall through with all four
        // price bounds null — i.e. the price filter becomes inactive. The
        // RPC contract treats null bounds as "no filter for this currency".
      }
    }

    // ---------------------------------------------------------------
    // Build the param map — include only non-null entries so the RPC's
    // DEFAULT NULL behaviour drives "filter inactive" semantics.
    // ---------------------------------------------------------------
    final params = <String, dynamic>{};

    if (filters.query != null && filters.query!.trim().isNotEmpty) {
      params['p_query'] = filters.query!.trim();
    }
    if (filters.purpose != null) {
      params['p_purpose'] = filters.purpose!.toDbValue();
    }
    if (filters.propertyType != null) {
      params['p_property_type'] = filters.propertyType!.toDbValue();
    }
    if (filters.governorateId != null) {
      params['p_governorate_id'] = filters.governorateId;
    }
    if (filters.cityId != null) {
      params['p_city_id'] = filters.cityId;
    }
    if (filters.areaId != null) {
      params['p_area_id'] = filters.areaId;
    }
    if (priceMinUsd != null) params['p_price_min_usd'] = priceMinUsd;
    if (priceMaxUsd != null) params['p_price_max_usd'] = priceMaxUsd;
    if (priceMinSyp != null) params['p_price_min_syp'] = priceMinSyp;
    if (priceMaxSyp != null) params['p_price_max_syp'] = priceMaxSyp;

    if (filters.rooms != null) {
      params['p_rooms'] = filters.rooms;
      params['p_rooms_mode'] = filters.roomsMode == CountFilterMode.exactly
          ? 'exactly'
          : 'at_least';
    }
    if (filters.bathrooms != null) {
      params['p_bathrooms'] = filters.bathrooms;
      params['p_bathrooms_mode'] =
          filters.bathroomsMode == CountFilterMode.exactly
          ? 'exactly'
          : 'at_least';
    }
    if (filters.areaSizeMin != null) {
      params['p_area_size_min'] = filters.areaSizeMin;
    }
    if (filters.areaSizeMax != null) {
      params['p_area_size_max'] = filters.areaSizeMax;
    }
    // Phase 031 (WS-D) — feature flags + amenity containment. Each is sent only
    // when constrained so the RPC's DEFAULT NULL drives "filter inactive".
    // `p_amenities` is a JSON array; the RPC casts it to jsonb and tests
    // containment (`ld.amenities @> p_amenities`) so every listed amenity must
    // be present on the listing.
    if (filters.furnished != null) {
      params['p_furnished'] = filters.furnished;
    }
    if (filters.parking != null) {
      params['p_parking'] = filters.parking;
    }
    if (filters.amenities.isNotEmpty) {
      params['p_amenities'] = filters.amenities.toList();
    }
    // Owner-vs-agency lister filter (DEFAULT NULL ⇒ all listers).
    if (filters.isAgency != null) {
      params['p_is_agency'] = filters.isAgency;
    }

    params['p_sort'] = _sortToRpc(sort);

    if (cursor is NewestCursor) {
      params['p_cursor_published_at'] = cursor.publishedAt
          .toUtc()
          .toIso8601String();
      params['p_cursor_id_newest'] = cursor.id;
    } else if (cursor is PriceCursor) {
      params['p_cursor_price_amount'] = cursor.priceAmount;
      params['p_cursor_id_price'] = cursor.id;
    }

    params['p_limit'] = limit;

    // ---------------------------------------------------------------
    // Call the RPC + map rows to entities.
    //
    // Image URL post-processing mirrors Phase 13's
    // `SupabaseHomeFeedDatasource.fetchPage` — the RPC returns a raw storage
    // path (e.g. `listings/<uuid>/image.jpg`); we rewrite it to a full public
    // URL here so the presentation layer can hand it straight to
    // `CachedNetworkImage` without itself importing supabase_flutter
    // (preserves Constitution IX / FR-030 isolation: this file is the SOLE
    // supabase_flutter importer under `lib/features/search/`).
    // ---------------------------------------------------------------
    final result = await _client.rpc('search_listings', params: params);
    final rows = result as List<dynamic>;
    return rows.map((row) {
      final entity = SearchResultItemDto.fromJson(
        Map<String, dynamic>.from(row as Map),
      ).toEntity();
      final path = entity.mainImagePath;
      if (path == null || path.isEmpty || path.startsWith('http')) {
        return entity;
      }
      final url = _client.storage.from('listing-images').getPublicUrl(path);
      return entity.copyWith(mainImagePath: url);
    }).toList();
  }

  static String _sortToRpc(SortOrder sort) {
    switch (sort) {
      case SortOrder.newest:
        return 'newest';
      case SortOrder.priceAsc:
        return 'price_asc';
      case SortOrder.priceDesc:
        return 'price_desc';
    }
  }
}
