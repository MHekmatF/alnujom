import 'package:injectable/injectable.dart';

import '../entities/city.dart';
import '../repositories/locations_repository.dart';

@injectable
class CreateCity {
  const CreateCity(this.repository);

  final LocationsRepository repository;

  Future<City> call({
    required String governorateId,
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) => repository.createCity(
    governorateId: governorateId,
    key: key,
    displayName: displayName,
    description: description,
    position: position,
    isActive: isActive,
  );
}
