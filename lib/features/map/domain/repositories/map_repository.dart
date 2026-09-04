import '../../../../core/errors/result.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../entities/map_bounds.dart';
import '../entities/map_marker.dart';

/// Phase 15 — abstract domain interface for loading the public map dataset.
/// Concrete impl in lib/features/map/data/repositories/map_repository_impl.dart.
abstract class MapRepository {
  /// Load the approved+visible markers for [bounds], narrowed by [filter].
  ///
  /// Plan A17 — both arguments are optional and both go to the same
  /// `search_map` RPC: a null [filter] means no narrowing, a null [bounds]
  /// means the whole country. Either way the server caps the result at
  /// [kMapMarkerCap], so a result of that length should be read as "there may
  /// be more here" rather than as the complete set.
  Future<Result<List<MapMarker>>> loadMarkers({
    FilterState? filter,
    MapBounds? bounds,
  });
}
