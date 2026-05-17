import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/area.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/city_with_area_count.dart';
import '../../domain/entities/governorate.dart';
import '../../domain/entities/governorate_with_city_count.dart';
import '../../domain/failures.dart';
import '../../domain/repositories/locations_repository.dart';
import '../datasources/supabase_locations_datasource.dart';

@LazySingleton(as: LocationsRepository)
class LocationsRepositoryImpl implements LocationsRepository {
  LocationsRepositoryImpl(this._ds, this._logger);

  static const _tag = 'LocationsRepositoryImpl';

  final SupabaseLocationsDatasource _ds;
  final AppLogger _logger;

  @override
  Future<List<GovernorateWithCityCount>> listGovernorates({
    required bool includeInactive,
  }) async {
    try {
      final dtos = await _ds.listGovernorates(includeInactive: includeInactive);
      return dtos.map((d) => d.toEntity()).toList();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Governorate> loadGovernorate(String id) async {
    try {
      return (await _ds.loadGovernorate(id)).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<List<CityWithAreaCount>> listCitiesForGovernorate(
    String governorateId, {
    required bool includeInactive,
  }) async {
    try {
      final dtos = await _ds.listCitiesForGovernorate(
        governorateId,
        includeInactive: includeInactive,
      );
      return dtos.map((d) => d.toEntity()).toList();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<City> loadCity(String id) async {
    try {
      return (await _ds.loadCity(id)).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<List<Area>> listAreasForCity(
    String cityId, {
    required bool includeInactive,
  }) async {
    try {
      final dtos = await _ds.listAreasForCity(
        cityId,
        includeInactive: includeInactive,
      );
      return dtos.map((d) => d.toEntity()).toList();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Governorate> createGovernorate({
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) async {
    try {
      return (await _ds.createGovernorate(
        key: key,
        displayName: displayName,
        description: description,
        position: position,
        isActive: isActive,
      )).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Governorate> updateGovernorate(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) async {
    try {
      return (await _ds.updateGovernorate(
        id,
        key: key,
        displayName: displayName,
        description: description,
        position: position,
        isActive: isActive,
      )).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<void> deleteGovernorate(String id) async {
    try {
      await _ds.deleteGovernorate(id);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<City> createCity({
    required String governorateId,
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) async {
    try {
      return (await _ds.createCity(
        governorateId: governorateId,
        key: key,
        displayName: displayName,
        description: description,
        position: position,
        isActive: isActive,
      )).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<City> updateCity(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) async {
    try {
      return (await _ds.updateCity(
        id,
        key: key,
        displayName: displayName,
        description: description,
        position: position,
        isActive: isActive,
      )).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<void> deleteCity(String id) async {
    try {
      await _ds.deleteCity(id);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Area> createArea({
    required String cityId,
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) async {
    try {
      return (await _ds.createArea(
        cityId: cityId,
        key: key,
        displayName: displayName,
        description: description,
        position: position,
        isActive: isActive,
      )).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<Area> updateArea(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) async {
    try {
      return (await _ds.updateArea(
        id,
        key: key,
        displayName: displayName,
        description: description,
        position: position,
        isActive: isActive,
      )).toEntity();
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<void> deleteArea(String id) async {
    try {
      await _ds.deleteArea(id);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<int> countCitiesInGovernorate(String governorateId) async {
    try {
      return await _ds.countCitiesInGovernorate(governorateId);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<int> countAreasInCity(String cityId) async {
    try {
      return await _ds.countAreasInCity(cityId);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  @override
  Future<int> countAreasInGovernorate(String governorateId) async {
    try {
      return await _ds.countAreasInGovernorate(governorateId);
    } on PostgrestException catch (e, st) {
      throw _mapPostgrest(e, st);
    } on Object catch (e, st) {
      throw _mapUnknown(e, st);
    }
  }

  LocationsFailure _mapPostgrest(PostgrestException e, StackTrace st) {
    _logger.warning(
      'Locations data error.',
      error: e,
      stackTrace: st,
      tag: _tag,
    );
    final code = e.code ?? '';
    final msg = e.message;
    if (code == '42501') {
      if (msg.contains('_system_immutable')) {
        return const SystemRowProtectedFailure();
      }
      return NotAuthorizedFailure(msg);
    }
    if (code == '23505') return const KeyAlreadyUsedFailure();
    if (code == '23503') return const ForeignKeyViolationFailure();
    return LocationsUnknownFailure(msg, cause: e, stackTrace: st);
  }

  LocationsFailure _mapUnknown(Object e, StackTrace st) {
    _logger.warning(
      'Locations unexpected error.',
      error: e,
      stackTrace: st,
      tag: _tag,
    );
    return LocationsUnknownFailure(e.toString(), cause: e, stackTrace: st);
  }
}
