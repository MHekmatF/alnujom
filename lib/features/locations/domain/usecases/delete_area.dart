import 'package:injectable/injectable.dart';

import '../repositories/locations_repository.dart';

@injectable
class DeleteArea {
  const DeleteArea(this.repository);

  final LocationsRepository repository;

  Future<void> call(String id) => repository.deleteArea(id);
}
