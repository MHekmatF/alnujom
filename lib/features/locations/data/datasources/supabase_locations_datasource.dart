import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/failures.dart';
import '../dtos/area_dto.dart';
import '../dtos/city_dto.dart';
import '../dtos/city_with_area_count_dto.dart';
import '../dtos/governorate_dto.dart';
import '../dtos/governorate_with_city_count_dto.dart';

@injectable
class SupabaseLocationsDatasource {
  SupabaseLocationsDatasource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  // ── Governorates ──────────────────────────────────────────────────────────

  Future<List<GovernorateWithCityCountDto>> listGovernorates({
    required bool includeInactive,
  }) async {
    var query = _client.from('governorates').select('*, cities(count)');
    final response =
        await (includeInactive ? query : query.eq('is_active', true))
            .order('position', ascending: true, nullsFirst: false)
            .order('key', ascending: true);
    return response.map(GovernorateWithCityCountDto.fromJson).toList();
  }

  Future<GovernorateDto> loadGovernorate(String id) async {
    final response = await _client
        .from('governorates')
        .select()
        .eq('id', id)
        .single();
    return GovernorateDto.fromJson(response);
  }

  Future<GovernorateDto> createGovernorate({
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) async {
    final response = await _client
        .from('governorates')
        .insert({
          'key': key,
          'display_name': displayName,
          if (description != null) 'description': description,
          if (position != null) 'position': position,
          'is_active': isActive,
        })
        .select()
        .single();
    return GovernorateDto.fromJson(response);
  }

  Future<GovernorateDto> updateGovernorate(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      if (key != null) 'key': key,
      if (displayName != null) 'display_name': displayName,
      if (description != null) 'description': description,
      if (position != null) 'position': position,
      if (isActive != null) 'is_active': isActive,
    };
    final response = await _client
        .from('governorates')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return GovernorateDto.fromJson(response);
  }

  Future<void> deleteGovernorate(String id) async {
    await _client.from('governorates').delete().eq('id', id);
  }

  // ── Cities ─────────────────────────────────────────────────────────────────

  Future<List<CityWithAreaCountDto>> listCitiesForGovernorate(
    String governorateId, {
    required bool includeInactive,
  }) async {
    var query = _client
        .from('cities')
        .select('*, areas(count)')
        .eq('governorate_id', governorateId);
    final response =
        await (includeInactive ? query : query.eq('is_active', true))
            .order('position', ascending: true, nullsFirst: false)
            .order('key', ascending: true);
    return response.map(CityWithAreaCountDto.fromJson).toList();
  }

  Future<CityDto> loadCity(String id) async {
    final response = await _client
        .from('cities')
        .select()
        .eq('id', id)
        .single();
    return CityDto.fromJson(response);
  }

  Future<CityDto> createCity({
    required String governorateId,
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) async {
    final response = await _client
        .from('cities')
        .insert({
          'governorate_id': governorateId,
          'key': key,
          'display_name': displayName,
          if (description != null) 'description': description,
          if (position != null) 'position': position,
          'is_active': isActive,
        })
        .select()
        .single();
    return CityDto.fromJson(response);
  }

  Future<CityDto> updateCity(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      if (key != null) 'key': key,
      if (displayName != null) 'display_name': displayName,
      if (description != null) 'description': description,
      if (position != null) 'position': position,
      if (isActive != null) 'is_active': isActive,
    };
    final response = await _client
        .from('cities')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return CityDto.fromJson(response);
  }

  Future<void> deleteCity(String id) async {
    await _client.from('cities').delete().eq('id', id);
  }

  // ── Areas ──────────────────────────────────────────────────────────────────

  Future<List<AreaDto>> listAreasForCity(
    String cityId, {
    required bool includeInactive,
  }) async {
    var query = _client.from('areas').select().eq('city_id', cityId);
    final response =
        await (includeInactive ? query : query.eq('is_active', true))
            .order('position', ascending: true, nullsFirst: false)
            .order('key', ascending: true);
    return response.map(AreaDto.fromJson).toList();
  }

  Future<AreaDto> loadArea(String id) async {
    final response = await _client.from('areas').select().eq('id', id).single();
    return AreaDto.fromJson(response);
  }

  Future<AreaDto> createArea({
    required String cityId,
    required String key,
    required Map<String, String> displayName,
    // centroid_lat / centroid_lng are NOT NULL on `areas` (CHECK lat 32..37,
    // lng 35..43). Omitting them previously caused a 23502 on insert — they
    // are now required by the create flow (validated upstream in the bloc).
    required double centroidLat,
    required double centroidLng,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) async {
    final response = await _client
        .from('areas')
        .insert({
          'city_id': cityId,
          'key': key,
          'display_name': displayName,
          'centroid_lat': centroidLat,
          'centroid_lng': centroidLng,
          if (description != null) 'description': description,
          if (position != null) 'position': position,
          'is_active': isActive,
        })
        .select()
        .single();
    return AreaDto.fromJson(response);
  }

  Future<AreaDto> updateArea(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
    double? centroidLat,
    double? centroidLng,
  }) async {
    final updates = <String, dynamic>{
      if (key != null) 'key': key,
      if (displayName != null) 'display_name': displayName,
      if (description != null) 'description': description,
      if (position != null) 'position': position,
      if (isActive != null) 'is_active': isActive,
      if (centroidLat != null) 'centroid_lat': centroidLat,
      if (centroidLng != null) 'centroid_lng': centroidLng,
    };
    final response = await _client
        .from('areas')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return AreaDto.fromJson(response);
  }

  Future<void> deleteArea(String id) async {
    await _client.from('areas').delete().eq('id', id);
  }

  // ── Count helpers (for delete-confirmation dialogs, FR-017) ────────────────

  Future<int> countCitiesInGovernorate(String governorateId) async {
    final response = await _client
        .from('cities')
        .select('id')
        .eq('governorate_id', governorateId);
    return response.length;
  }

  Future<int> countAreasInCity(String cityId) async {
    final response = await _client
        .from('areas')
        .select('id')
        .eq('city_id', cityId);
    return response.length;
  }

  Future<int> countAreasInGovernorate(String governorateId) async {
    final cityIds = await _client
        .from('cities')
        .select('id')
        .eq('governorate_id', governorateId);
    if (cityIds.isEmpty) return 0;
    final ids = cityIds.map((row) => row['id'] as String).toList();
    final areas = await _client
        .from('areas')
        .select('id')
        .inFilter('city_id', ids);
    return areas.length;
  }

  // Phase 10 — area-centroid lookup for FR-013a (Q2 auto-fill).
  Future<({double lat, double lng})> getAreaCentroid(String areaId) async {
    final row = await _client
        .from('areas')
        .select('centroid_lat, centroid_lng')
        .eq('id', areaId)
        .single();
    final lat = row['centroid_lat'];
    final lng = row['centroid_lng'];
    if (lat == null || lng == null) {
      throw const CentroidMissingFailure();
    }
    final latD = lat is num ? lat.toDouble() : double.parse(lat as String);
    final lngD = lng is num ? lng.toDouble() : double.parse(lng as String);
    return (lat: latD, lng: lngD);
  }

  // ── Error code mapping (consumed by repository impl) ─────────────────────
  // SQLSTATE 42501: either RLS deny or immutability trigger
  //   → message contains '_system_immutable' → SystemRowProtected
  //   → otherwise → NotAuthorized
  // SQLSTATE 23505: unique violation → KeyAlreadyUsed
  // SQLSTATE 23503: FK violation → ForeignKeyViolation
}
