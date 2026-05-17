import 'package:injectable/injectable.dart';

import '../entities/area.dart';
import '../repositories/locations_repository.dart';

@injectable
class ListAreasForCity {
  const ListAreasForCity(this.repository);

  final LocationsRepository repository;

  Future<List<Area>> call({
    required String cityId,
    required bool includeInactive,
  }) => repository.listAreasForCity(cityId, includeInactive: includeInactive);
}
