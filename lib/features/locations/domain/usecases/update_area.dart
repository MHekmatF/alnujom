import 'package:injectable/injectable.dart';

import '../entities/area.dart';
import '../repositories/locations_repository.dart';

@injectable
class UpdateArea {
  const UpdateArea(this.repository);

  final LocationsRepository repository;

  Future<Area> call(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) => repository.updateArea(
    id,
    key: key,
    displayName: displayName,
    description: description,
    position: position,
    isActive: isActive,
  );
}
