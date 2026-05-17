import 'package:injectable/injectable.dart';

import '../repositories/locations_repository.dart';

@injectable
class DeleteGovernorate {
  const DeleteGovernorate(this.repository);

  final LocationsRepository repository;

  Future<void> call(String id) => repository.deleteGovernorate(id);
}
