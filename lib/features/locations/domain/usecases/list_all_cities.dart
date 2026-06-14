import 'package:injectable/injectable.dart';

import '../entities/city.dart';
import '../repositories/locations_repository.dart';

/// Lists EVERY active city across all governorates in one flat call.
///
/// Phase 031 (WS-D) — added so the smart-search assistant can match a city
/// name anywhere in the user's sentence without first having to resolve its
/// governorate (mirrors [ListGovernorates] in shape: a single cached read).
/// Each [City] already carries its `governorateId`, so a matched city also
/// pins the governorate. Unlike [ListCitiesForGovernorate] this is NOT scoped
/// to one governorate — it is the cheap "give me the whole gazetteer" path the
/// parser needs for longest-match city detection.
@injectable
class ListAllCities {
  const ListAllCities(this.repository);

  final LocationsRepository repository;

  Future<List<City>> call({bool includeInactive = false}) =>
      repository.listAllCities(includeInactive: includeInactive);
}
