import 'package:injectable/injectable.dart';

import '../entities/governorate_with_city_count.dart';
import '../repositories/locations_repository.dart';

@injectable
class ListGovernorates {
  const ListGovernorates(this.repository);

  final LocationsRepository repository;

  Future<List<GovernorateWithCityCount>> call({
    required bool includeInactive,
  }) => repository.listGovernorates(includeInactive: includeInactive);
}
