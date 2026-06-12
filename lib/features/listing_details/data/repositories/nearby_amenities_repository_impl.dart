import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/nearby_amenity.dart';
import '../../domain/repositories/nearby_amenities_repository.dart';
import '../datasources/overpass_nearby_amenities_datasource.dart';

/// Spec 028 — concrete [NearbyAmenitiesRepository] over the Overpass/OSM
/// datasource.
///
/// Best-effort by design: any datasource failure (timeout, non-200, malformed
/// JSON) surfaces as a [NetworkFailure] and the "Nearby" section collapses; an
/// empty neighborhood is a [Success] with an empty list.
@LazySingleton(as: NearbyAmenitiesRepository)
class NearbyAmenitiesRepositoryImpl implements NearbyAmenitiesRepository {
  const NearbyAmenitiesRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'NearbyAmenitiesRepositoryImpl';

  final OverpassNearbyAmenitiesDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<List<NearbyAmenity>>> fetchNearby({
    required String listingId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final amenities = await _datasource.fetchNearby(
        listingId: listingId,
        latitude: latitude,
        longitude: longitude,
      );
      return Success(amenities);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchNearby failed for id=$listingId',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
