import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../locations/domain/repositories/locations_repository.dart';

class AreaCentroid extends Equatable {
  const AreaCentroid({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}

@injectable
class DeriveAreaCentroid {
  const DeriveAreaCentroid(this._locationsRepository);

  final LocationsRepository _locationsRepository;

  /// Reads `public.areas.centroid_lat`/`centroid_lng` via the Phase 8
  /// locations repository. Per Q2 / R-07 / FR-013a, the Phase 10 publisher
  /// never edits these manually — the picked area_id deterministically
  /// resolves to a (lat, lng) pair which the form writes to the draft.
  /// Throws `CentroidMissingFailure` if the row is missing centroid columns
  /// (should never happen post-T008 seed).
  Future<AreaCentroid> call(String areaId) async {
    final pair = await _locationsRepository.getAreaCentroid(areaId);
    return AreaCentroid(latitude: pair.lat, longitude: pair.lng);
  }
}
