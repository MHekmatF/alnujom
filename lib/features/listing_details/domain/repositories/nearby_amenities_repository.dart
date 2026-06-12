import '../../../../core/errors/result.dart';
import '../entities/nearby_amenity.dart';

/// Spec 028 — abstract repository for the listing-details "Nearby" section.
///
/// Returns up to a small batch of points of interest around the listing's
/// coordinates (schools / hospitals / pharmacies / markets / mosques), sorted
/// nearest-first. Best-effort: a fetch failure surfaces as a [FailureResult]
/// and the section simply collapses.
abstract class NearbyAmenitiesRepository {
  Future<Result<List<NearbyAmenity>>> fetchNearby({
    required String listingId,
    required double latitude,
    required double longitude,
  });
}
