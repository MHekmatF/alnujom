import 'package:injectable/injectable.dart';

import '../entities/area.dart';
import '../repositories/locations_repository.dart';

@injectable
class CreateArea {
  const CreateArea(this.repository);

  final LocationsRepository repository;

  Future<Area> call({
    required String cityId,
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) => repository.createArea(
    cityId: cityId,
    key: key,
    displayName: displayName,
    description: description,
    position: position,
    isActive: isActive,
  );
}
