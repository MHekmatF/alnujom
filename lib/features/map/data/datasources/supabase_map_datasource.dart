// lib/features/map/data/datasources/supabase_map_datasource.dart
//
// Phase 15 — SOLE importer of the supabase_flutter package under
// `lib/features/map/` per Constitution IX (grep gate in `quickstart.md` §8c
// must show exactly ONE matching file).
//
// Two load paths:
//   - loadAll()             → SELECT * FROM v_listings_map_public
//   - loadFiltered(filter)  → RPC search_map(...) with 16 filter params
//
// R-75 — price-range currency conversion: mirrors Phase 14's
// `SupabaseSearchDatasource.fetchPage` for the non-USD/non-SYP fallback path
// (fetch rates via `latest_rates_for_base`, pre-convert min/max into both USD
// and SYP equivalents). Inline rather than via CurrencyRepository for
// consistency with Phase 14's existing convention.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../listing_form/domain/entities/listing.dart';
import '../../../search/domain/entities/count_filter_mode.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../../domain/entities/map_marker.dart';
import '../models/map_marker_dto.dart';

@injectable
class SupabaseMapDatasource {
  SupabaseMapDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Fetches every approved+visible marker via the unfiltered view.
  Future<List<MapMarker>> loadAll() async {
    final result = await _client.from('v_listings_map_public').select();
    return _rowsToMarkers(result as List<dynamic>);
  }

  /// Fetches markers narrowed by [filter] via the `search_map` RPC.
  Future<List<MapMarker>> loadFiltered(FilterState filter) async {
    final params = await _filterToRpcParams(filter);
    final result = await _client.rpc('search_map', params: params);
    return _rowsToMarkers(result as List<dynamic>);
  }

  Future<Map<String, dynamic>> _filterToRpcParams(FilterState filter) async {
    // R-75 — price-range currency conversion (Phase 14 parity).
    double? priceMinUsd;
    double? priceMaxUsd;
    double? priceMinSyp;
    double? priceMaxSyp;

    final priceFilterActive =
        filter.priceMin != null || filter.priceMax != null;
    if (priceFilterActive) {
      final selectedCurrency = filter.priceCurrency;
      if (selectedCurrency == 'USD') {
        priceMinUsd = filter.priceMin;
        priceMaxUsd = filter.priceMax;
      } else if (selectedCurrency == 'SYP') {
        priceMinSyp = filter.priceMin;
        priceMaxSyp = filter.priceMax;
      } else if (selectedCurrency != null) {
        final ratesResult = await _client.rpc(
          'latest_rates_for_base',
          params: {'p_base_currency': selectedCurrency},
        );
        final list = ratesResult as List<dynamic>;
        final rateMap = <String, double>{
          for (final r in list)
            (r as Map<String, dynamic>)['target_currency']
                as String: r['rate'] is num
                ? (r['rate'] as num).toDouble()
                : double.parse(r['rate'].toString()),
        };
        final usdRate = rateMap['USD'];
        final sypRate = rateMap['SYP'];
        if (usdRate != null) {
          if (filter.priceMin != null) {
            priceMinUsd = filter.priceMin! * usdRate;
          }
          if (filter.priceMax != null) {
            priceMaxUsd = filter.priceMax! * usdRate;
          }
        }
        if (sypRate != null) {
          if (filter.priceMin != null) {
            priceMinSyp = filter.priceMin! * sypRate;
          }
          if (filter.priceMax != null) {
            priceMaxSyp = filter.priceMax! * sypRate;
          }
        }
      }
    }

    final params = <String, dynamic>{};

    if (filter.query != null && filter.query!.trim().isNotEmpty) {
      params['p_query'] = filter.query!.trim();
    }
    if (filter.purpose != null) {
      params['p_purpose'] = filter.purpose!.toDbValue();
    }
    if (filter.propertyType != null) {
      params['p_property_type'] = filter.propertyType!.toDbValue();
    }
    if (filter.governorateId != null) {
      params['p_governorate_id'] = filter.governorateId;
    }
    if (filter.cityId != null) {
      params['p_city_id'] = filter.cityId;
    }
    if (filter.areaId != null) {
      params['p_area_id'] = filter.areaId;
    }
    if (priceMinUsd != null) params['p_price_min_usd'] = priceMinUsd;
    if (priceMaxUsd != null) params['p_price_max_usd'] = priceMaxUsd;
    if (priceMinSyp != null) params['p_price_min_syp'] = priceMinSyp;
    if (priceMaxSyp != null) params['p_price_max_syp'] = priceMaxSyp;

    if (filter.rooms != null) {
      params['p_rooms'] = filter.rooms;
      params['p_rooms_mode'] = filter.roomsMode == CountFilterMode.exactly
          ? 'exactly'
          : 'at_least';
    }
    if (filter.bathrooms != null) {
      params['p_bathrooms'] = filter.bathrooms;
      params['p_bathrooms_mode'] =
          filter.bathroomsMode == CountFilterMode.exactly
          ? 'exactly'
          : 'at_least';
    }
    if (filter.areaSizeMin != null) {
      params['p_area_size_min'] = filter.areaSizeMin;
    }
    if (filter.areaSizeMax != null) {
      params['p_area_size_max'] = filter.areaSizeMax;
    }

    return params;
  }

  List<MapMarker> _rowsToMarkers(List<dynamic> rows) {
    return rows.map((row) {
      final dto = MapMarkerDto.fromJson(Map<String, dynamic>.from(row as Map));
      final entity = dto.toEntity();
      final path = entity.mainImagePath;
      if (path == null || path.isEmpty || path.startsWith('http')) {
        return entity;
      }
      final url = _client.storage.from('listing-images').getPublicUrl(path);
      return MapMarker(
        id: entity.id,
        position: entity.position,
        title: entity.title,
        primaryAmount: entity.primaryAmount,
        primaryCurrencyCode: entity.primaryCurrencyCode,
        mainImagePath: url,
        propertyType: entity.propertyType,
        purpose: entity.purpose,
        isApproximate: entity.isApproximate,
        governorateNameAr: entity.governorateNameAr,
        governorateNameEn: entity.governorateNameEn,
      );
    }).toList();
  }
}
