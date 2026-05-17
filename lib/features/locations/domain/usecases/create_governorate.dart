import 'package:injectable/injectable.dart';

import '../entities/governorate.dart';
import '../repositories/locations_repository.dart';

@injectable
class CreateGovernorate {
  const CreateGovernorate(this.repository);

  final LocationsRepository repository;

  Future<Governorate> call({
    required String key,
    required Map<String, String> displayName,
    Map<String, String>? description,
    int? position,
    bool isActive = true,
  }) => repository.createGovernorate(
    key: key,
    displayName: displayName,
    description: description,
    position: position,
    isActive: isActive,
  );
}
