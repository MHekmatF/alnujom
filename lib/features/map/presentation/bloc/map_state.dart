// lib/features/map/presentation/bloc/map_state.dart
//
// Phase 15 Sub-Phase E (T043) — sealed `MapState` hierarchy emitted by
// [MapBloc] per contracts/phase15-map-page-composition.md §BLoC contract.
//
// 4 cases:
//   • MapInitial    — pre-first-load (the BlocProvider's create immediately
//                     dispatches MapOpened, so the UI almost never observes
//                     this state).
//   • MapLoading    — fetch in flight.
//   • MapLoaded     — main success state; holds markers, the desired
//                     camera fit, the optional selected marker for the
//                     popover, the active filter (for refresh + alert),
//                     the one-shot showFilterAlert flag, and the
//                     geolocation sub-state.
//   • MapError      — fetch failed (typed [Failure] preserved).
//
// `MapLoaded` uses an [Equatable] base so BlocBuilder/BlocConsumer can do
// rebuild diffing. [copyWith] supports partial updates from the BLoC
// handlers — sentinel `bool clearSelectedMarker` / `clearActiveFilter`
// allow explicit null clears.
import 'package:equatable/equatable.dart';
import 'package:flutter_map/flutter_map.dart' show CameraFit;

import '../../../../core/errors/failure.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../../domain/entities/map_bounds.dart';
import '../../domain/entities/map_marker.dart';

/// Geolocation sub-state machine per phase15-geolocation-envelope.md.
///
/// Drives nothing in the page chrome currently (the snackbars are surfaced
/// imperatively from the FAB widget) but is preserved on [MapLoaded] so
/// future polish (e.g., a persistent "location-on" affordance on the FAB)
/// can read it without reaching back into the FAB widget.
enum GeolocationStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  fixFailed,
}

sealed class MapState extends Equatable {
  const MapState();
}

final class MapInitial extends MapState {
  const MapInitial();
  @override
  List<Object?> get props => const [];
}

final class MapLoading extends MapState {
  const MapLoading();
  @override
  List<Object?> get props => const [];
}

final class MapLoaded extends MapState {
  const MapLoaded({
    required this.markers,
    required this.cameraFit,
    this.selectedMarker,
    this.activeFilter,
    required this.showFilterAlert,
    required this.geolocationStatus,
    this.loadedBounds,
    this.markersCapped = false,
  });

  final List<MapMarker> markers;

  /// Plan A17 — the box [markers] were fetched for. `null` means the fetch was
  /// unbounded, i.e. the whole country.
  final MapBounds? loadedBounds;

  /// The server returned a full page ([kMapMarkerCap]), so [markers] is a
  /// truncation of what is really in [loadedBounds] and cannot be reused for a
  /// smaller viewport — zooming in has to re-ask.
  final bool markersCapped;

  /// flutter_map's camera descriptor. Set by [MapOpened]
  /// (entry-context-driven), by [GeolocationPermissionGranted]
  /// (centre-on-device), and unchanged by other handlers.
  final CameraFit cameraFit;

  /// The marker whose popover is currently visible. `null` ⇒ popover hidden.
  final MapMarker? selectedMarker;

  /// The Phase 14 [FilterState] that produced the current marker dataset.
  /// `null` ⇒ full unfiltered dataset (entry from home, or after reset).
  final FilterState? activeFilter;

  /// One-shot flag: true on the FIRST [MapLoaded] emission of a session
  /// where the user came from the search page WITH active filters. The
  /// page tracks its own `_alertShown` boolean so the dialog cannot
  /// re-appear on subsequent rebuilds even if this stays true.
  final bool showFilterAlert;

  final GeolocationStatus geolocationStatus;

  MapLoaded copyWith({
    List<MapMarker>? markers,
    CameraFit? cameraFit,
    MapMarker? selectedMarker,
    bool clearSelectedMarker = false,
    FilterState? activeFilter,
    bool clearActiveFilter = false,
    bool? showFilterAlert,
    GeolocationStatus? geolocationStatus,
    MapBounds? loadedBounds,
    bool clearLoadedBounds = false,
    bool? markersCapped,
  }) {
    return MapLoaded(
      markers: markers ?? this.markers,
      cameraFit: cameraFit ?? this.cameraFit,
      selectedMarker: clearSelectedMarker
          ? null
          : (selectedMarker ?? this.selectedMarker),
      activeFilter: clearActiveFilter
          ? null
          : (activeFilter ?? this.activeFilter),
      showFilterAlert: showFilterAlert ?? this.showFilterAlert,
      geolocationStatus: geolocationStatus ?? this.geolocationStatus,
      loadedBounds: clearLoadedBounds
          ? null
          : (loadedBounds ?? this.loadedBounds),
      markersCapped: markersCapped ?? this.markersCapped,
    );
  }

  @override
  List<Object?> get props => [
    markers,
    loadedBounds,
    markersCapped,
    // CameraFit is not Equatable in flutter_map ^7 — identity-compare is
    // acceptable since handlers always emit a fresh instance.
    identityHashCode(cameraFit),
    selectedMarker,
    activeFilter,
    showFilterAlert,
    geolocationStatus,
  ];
}

final class MapError extends MapState {
  const MapError({required this.failure});
  final Failure failure;

  @override
  List<Object?> get props => [failure.message];
}
