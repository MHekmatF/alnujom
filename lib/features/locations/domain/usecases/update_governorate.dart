import 'package:injectable/injectable.dart';

import '../entities/governorate.dart';
import '../repositories/locations_repository.dart';

@injectable
class UpdateGovernorate {
  const UpdateGovernorate(this.repository);

  final LocationsRepository repository;

  Future<Governorate> call(
    String id, {
    String? key,
    Map<String, String>? displayName,
    Map<String, String>? description,
    int? position,
    bool? isActive,
  }) => repository.updateGovernorate(
    id,
    key: key,
    displayName: displayName,
    description: description,
    position: position,
    isActive: isActive,
  );
}
