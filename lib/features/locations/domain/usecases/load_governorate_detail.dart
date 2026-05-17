import 'package:injectable/injectable.dart';

import '../entities/governorate.dart';
import '../repositories/locations_repository.dart';

@injectable
class LoadGovernorateDetail {
  const LoadGovernorateDetail(this.repository);

  final LocationsRepository repository;

  Future<Governorate> call(String id) => repository.loadGovernorate(id);
}
