import 'package:injectable/injectable.dart';

import '../entities/city.dart';
import '../repositories/locations_repository.dart';

@injectable
class LoadCityDetail {
  const LoadCityDetail(this.repository);

  final LocationsRepository repository;

  Future<City> call(String id) => repository.loadCity(id);
}
