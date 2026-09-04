import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../entities/map_bounds.dart';
import '../entities/map_marker.dart';
import '../repositories/map_repository.dart';

@injectable
class LoadMapMarkers {
  const LoadMapMarkers(this._repository);
  final MapRepository _repository;

  Future<Result<List<MapMarker>>> call({
    FilterState? filter,
    MapBounds? bounds,
  }) => _repository.loadMarkers(filter: filter, bounds: bounds);
}
