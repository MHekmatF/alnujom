import 'package:injectable/injectable.dart';

import '../repositories/locations_repository.dart';

@injectable
class DeleteCity {
  const DeleteCity(this.repository);

  final LocationsRepository repository;

  Future<void> call(String id) => repository.deleteCity(id);
}
