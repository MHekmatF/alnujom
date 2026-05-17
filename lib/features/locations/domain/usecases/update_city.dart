import 'package:injectable/injectable.dart';

import '../entities/city.dart';
import '../repositories/locations_repository.dart';

@injectable
class UpdateCity {
  const UpdateCity(this.repository);

  final LocationsRepository repository;

  Future<City> call(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) => repository.updateCity(
    id,
    key: key,
    displayName: displayName,
    description: description,
    position: position,
    isActive: isActive,
  );
}
