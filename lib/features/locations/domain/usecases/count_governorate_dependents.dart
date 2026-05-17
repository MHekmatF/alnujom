import 'package:injectable/injectable.dart';

import '../repositories/locations_repository.dart';

@injectable
class CountGovernorateDependents {
  const CountGovernorateDependents(this.repository);

  final LocationsRepository repository;

  Future<({int cities, int areas})> call(String governorateId) async {
    final cities = await repository.countCitiesInGovernorate(governorateId);
    final areas = await repository.countAreasInGovernorate(governorateId);
    return (cities: cities, areas: areas);
  }
}
