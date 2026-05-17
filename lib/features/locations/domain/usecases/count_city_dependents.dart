import 'package:injectable/injectable.dart';

import '../repositories/locations_repository.dart';

@injectable
class CountCityDependents {
  const CountCityDependents(this.repository);

  final LocationsRepository repository;

  Future<int> call(String cityId) => repository.countAreasInCity(cityId);
}
