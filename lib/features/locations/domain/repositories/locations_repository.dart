import '../entities/area.dart';
import '../entities/city.dart';
import '../entities/city_with_area_count.dart';
import '../entities/governorate.dart';
import '../entities/governorate_with_city_count.dart';

abstract class LocationsRepository {
  // Read — governorates
  Future<List<GovernorateWithCityCount>> listGovernorates({
    required bool includeInactive,
  });
  Future<Governorate> loadGovernorate(String id);

  // Read — cities
  Future<List<CityWithAreaCount>> listCitiesForGovernorate(
    String governorateId, {
    required bool includeInactive,
  });
  Future<City> loadCity(String id);

  // Read — areas
  Future<List<Area>> listAreasForCity(
    String cityId, {
    required bool includeInactive,
  });
  Future<Area> loadArea(String id);

  // Write — governorates
  Future<Governorate> createGovernorate({
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  });
  Future<Governorate> updateGovernorate(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  });
  Future<void> deleteGovernorate(String id);

  // Write — cities
  Future<City> createCity({
    required String governorateId,
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  });
  Future<City> updateCity(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  });
  Future<void> deleteCity(String id);

  // Write — areas
  Future<Area> createArea({
    required String cityId,
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  });
  Future<Area> updateArea(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  });
  Future<void> deleteArea(String id);

  // Count helpers for delete-confirmation dialogs (FR-017)
  Future<int> countCitiesInGovernorate(String governorateId);
  Future<int> countAreasInCity(String cityId);
  Future<int> countAreasInGovernorate(String governorateId);
}
