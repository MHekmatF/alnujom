import '../../../../core/errors/result.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../entities/map_marker.dart';

/// Phase 15 — abstract domain interface for loading the public map dataset.
/// Concrete impl in lib/features/map/data/repositories/map_repository_impl.dart.
abstract class MapRepository {
  /// Load every approved+visible marker. When [filter] is null, calls the bare
  /// v_listings_map_public view; when non-null, calls the search_map RPC with
  /// the filter parameters.
  Future<Result<List<MapMarker>>> loadMarkers({FilterState? filter});
}
