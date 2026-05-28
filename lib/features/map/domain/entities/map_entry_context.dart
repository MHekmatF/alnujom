import 'package:equatable/equatable.dart';

import '../../../search/domain/entities/filter_state.dart';
import 'marker_coordinates.dart';

/// The navigation envelope passed to MapPage via go_router state.extra.
/// Sub-Phase A creates this; Sub-Phase E (MapBloc) and Sub-Phase G (entry-point
/// widgets) consume it.
sealed class MapEntryContext extends Equatable {
  const MapEntryContext();
}

/// Entered from the home shell's map tile. No payload.
final class MapEntryFromHome extends MapEntryContext {
  const MapEntryFromHome();
  @override
  List<Object?> get props => const [];
}

/// Entered from a listing details page's "View on map" affordance.
/// Carries the listing id (for marker pre-selection) and the listing's
/// coordinates (for camera centering).
final class MapEntryFromListing extends MapEntryContext {
  const MapEntryFromListing({required this.listingId, required this.position});
  final String listingId;
  final MarkerCoordinates position;
  @override
  List<Object?> get props => [listingId, position];
}

/// Entered from the Phase 14 search results "Show on map" affordance.
/// Carries the active FilterState; the map honors the filters and shows the
/// FilterActiveAlertDialog when showFilterAlert is true.
final class MapEntryFromSearch extends MapEntryContext {
  const MapEntryFromSearch({
    required this.filterState,
    required this.showFilterAlert,
  });
  final FilterState filterState;
  final bool showFilterAlert;
  @override
  List<Object?> get props => [filterState, showFilterAlert];
}
