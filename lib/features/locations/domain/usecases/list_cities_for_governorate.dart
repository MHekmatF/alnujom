import 'package:injectable/injectable.dart';

import '../entities/city_with_area_count.dart';
import '../repositories/locations_repository.dart';

@injectable
class ListCitiesForGovernorate {
  const ListCitiesForGovernorate(this.repository);

  final LocationsRepository repository;

  Future<List<CityWithAreaCount>> call({
    required String governorateId,
    required bool includeInactive,
  }) => repository.listCitiesForGovernorate(
    governorateId,
    includeInactive: includeInactive,
  );
}
