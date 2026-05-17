import 'package:injectable/injectable.dart';

import '../entities/area.dart';
import '../repositories/locations_repository.dart';

@injectable
class LoadAreaDetail {
  const LoadAreaDetail(this.repository);

  final LocationsRepository repository;

  Future<Area> call(String id) => repository.loadArea(id);
}
