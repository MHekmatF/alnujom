// lib/features/map/presentation/bloc/map_bloc.dart
//
// Phase 15 Sub-Phase E (T044) — state machine driving `/map` per
// contracts/phase15-map-page-composition.md §BLoC contract.
//
// Lifetime: @injectable (NOT @lazySingleton) so every push of `/map`
// constructs a fresh BLoC. The page widget owns the BlocProvider; the
// orchestrating /map GoRoute hands the [MapEntryContext] off via the
// constructor of [MapPage] which feeds it into the first [MapOpened]
// event.
//
// Camera-fit derivation per [MapEntryContext] case:
//   • null OR MapEntryFromHome  → Syria-wide bbox.
//   • MapEntryFromListing       → centred on the listing's position,
//                                 zoom-15 (neighborhood) per FR-015b.
//   • MapEntryFromSearch        → fit-to-results when the filtered
//                                 dataset is non-empty; Syria-wide fallback
//                                 when empty so the user always sees a
//                                 sensible camera.
//
// Geolocation sub-state machine handlers (see phase15-geolocation-envelope.md):
// the FAB widget runs the permission_handler + Geolocator flow and
// dispatches the terminal event; the BLoC just maps the event to a
// MapLoaded.copyWith(geolocationStatus + optional cameraFit).
//
// FR-015c invariant: NO event handler ever sends the device's coordinates
// to Supabase. The grep gate in quickstart.md §8c verifies this.
import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart' show CameraFit, LatLngBounds;
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/errors/result.dart';
import '../../../search/domain/entities/filter_state.dart';
import '../../domain/entities/map_entry_context.dart';
import '../../domain/entities/map_marker.dart';
import '../../domain/entities/marker_coordinates.dart';
import '../../domain/usecases/load_map_markers.dart';
import 'map_event.dart';
import 'map_state.dart';

/// Syria-wide bbox per R-93 / FR-015a. Roughly:
///   • SW (32.3°N, 35.7°E) — south of Daraa, near the Israeli/Jordanian border.
///   • NE (37.3°N, 42.4°E) — north of Al-Hasakah, on the Turkish/Iraqi corner.
/// Default camera for the home + filtered-no-results entry points.
final _syriaSouthWest = const LatLng(32.3, 35.7);
final _syriaNorthEast = const LatLng(37.3, 42.4);

CameraFit _syriaWideFit() => CameraFit.bounds(
      bounds: LatLngBounds(_syriaSouthWest, _syriaNorthEast),
    );

CameraFit _centerOnFit(MarkerCoordinates position, {double maxZoom = 15}) =>
    CameraFit.coordinates(
      coordinates: [LatLng(position.latitude, position.longitude)],
      maxZoom: maxZoom,
    );

CameraFit _fitToMarkers(List<MapMarker> markers) {
  if (markers.isEmpty) return _syriaWideFit();
  if (markers.length == 1) {
    return _centerOnFit(markers.first.position);
  }
  return CameraFit.coordinates(
    coordinates: markers
        .map((m) => LatLng(m.position.latitude, m.position.longitude))
        .toList(growable: false),
    padding: const EdgeInsets.all(40),
  );
}

@injectable
class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc(this._loadMapMarkers) : super(const MapInitial()) {
    on<MapOpened>(_onOpened);
    on<MarkersRefreshRequested>(_onRefresh);
    on<MarkerTapped>(_onMarkerTapped);
    on<PopoverDismissed>(_onPopoverDismissed);
    on<CenterOnMyLocationRequested>(_onCenterOnMyLocationRequested);
    on<GeolocationPermissionGranted>(_onGeolocationGranted);
    on<GeolocationPermissionDenied>(_onGeolocationDenied);
    on<GeolocationFixFailed>(_onGeolocationFixFailed);
    on<FilterAlertDismissed>(_onFilterAlertDismissed);
    on<FilterResetRequested>(_onFilterResetRequested);
  }

  final LoadMapMarkers _loadMapMarkers;

  Future<void> _onOpened(MapOpened event, Emitter<MapState> emit) async {
    emit(const MapLoading());

    final context = event.context;
    final FilterState? filter = switch (context) {
      MapEntryFromSearch(filterState: final f) => f,
      _ => null,
    };
    final bool showFilterAlert = switch (context) {
      MapEntryFromSearch(showFilterAlert: final s) => s,
      _ => false,
    };

    final result = await _loadMapMarkers(filter: filter);

    switch (result) {
      case Success<List<MapMarker>>(:final value):
        final cameraFit = _initialCameraFit(context, value);
        final selected = _initialSelectedMarker(context, value);
        emit(MapLoaded(
          markers: value,
          cameraFit: cameraFit,
          selectedMarker: selected,
          activeFilter: filter,
          showFilterAlert: showFilterAlert,
          geolocationStatus: GeolocationStatus.unknown,
        ));
      case FailureResult<List<MapMarker>>(:final failure):
        emit(MapError(failure: failure));
    }
  }

  Future<void> _onRefresh(
    MarkersRefreshRequested event,
    Emitter<MapState> emit,
  ) async {
    final current = state;
    if (current is! MapLoaded) return;
    final filter = current.activeFilter;
    emit(const MapLoading());
    final result = await _loadMapMarkers(filter: filter);
    switch (result) {
      case Success<List<MapMarker>>(:final value):
        emit(MapLoaded(
          markers: value,
          // Preserve the user's current camera per contract §Transitions.
          cameraFit: current.cameraFit,
          activeFilter: filter,
          // showFilterAlert flips false on refresh — the alert is a
          // one-shot UX moment tied to the search-handoff entry.
          showFilterAlert: false,
          geolocationStatus: current.geolocationStatus,
        ));
      case FailureResult<List<MapMarker>>(:final failure):
        emit(MapError(failure: failure));
    }
  }

  void _onMarkerTapped(MarkerTapped event, Emitter<MapState> emit) {
    final current = state;
    if (current is! MapLoaded) return;
    final marker = current.markers.where((m) => m.id == event.listingId);
    if (marker.isEmpty) return;
    emit(current.copyWith(selectedMarker: marker.first));
  }

  void _onPopoverDismissed(PopoverDismissed event, Emitter<MapState> emit) {
    final current = state;
    if (current is! MapLoaded) return;
    if (current.selectedMarker == null) return;
    emit(current.copyWith(clearSelectedMarker: true));
  }

  void _onCenterOnMyLocationRequested(
    CenterOnMyLocationRequested event,
    Emitter<MapState> emit,
  ) {
    // No-op at the BLoC layer; the FAB widget orchestrates the
    // permission_handler + Geolocator flow and dispatches one of
    // GeolocationPermissionGranted / GeolocationPermissionDenied /
    // GeolocationFixFailed as the terminal outcome.
  }

  void _onGeolocationGranted(
    GeolocationPermissionGranted event,
    Emitter<MapState> emit,
  ) {
    final current = state;
    if (current is! MapLoaded) return;
    emit(current.copyWith(
      cameraFit: _centerOnFit(event.devicePosition),
      geolocationStatus: GeolocationStatus.granted,
    ));
  }

  void _onGeolocationDenied(
    GeolocationPermissionDenied event,
    Emitter<MapState> emit,
  ) {
    final current = state;
    if (current is! MapLoaded) return;
    emit(current.copyWith(
      geolocationStatus: event.permanentlyDenied
          ? GeolocationStatus.permanentlyDenied
          : GeolocationStatus.denied,
    ));
  }

  void _onGeolocationFixFailed(
    GeolocationFixFailed event,
    Emitter<MapState> emit,
  ) {
    final current = state;
    if (current is! MapLoaded) return;
    emit(current.copyWith(geolocationStatus: GeolocationStatus.fixFailed));
  }

  void _onFilterAlertDismissed(
    FilterAlertDismissed event,
    Emitter<MapState> emit,
  ) {
    final current = state;
    if (current is! MapLoaded) return;
    if (!current.showFilterAlert) return;
    emit(current.copyWith(showFilterAlert: false));
  }

  Future<void> _onFilterResetRequested(
    FilterResetRequested event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapLoading());
    final result = await _loadMapMarkers(filter: null);
    switch (result) {
      case Success<List<MapMarker>>(:final value):
        emit(MapLoaded(
          markers: value,
          cameraFit: _syriaWideFit(),
          activeFilter: null,
          showFilterAlert: false,
          geolocationStatus: GeolocationStatus.unknown,
        ));
      case FailureResult<List<MapMarker>>(:final failure):
        emit(MapError(failure: failure));
    }
  }

  CameraFit _initialCameraFit(
    MapEntryContext? context,
    List<MapMarker> markers,
  ) {
    return switch (context) {
      null => _syriaWideFit(),
      MapEntryFromHome() => _syriaWideFit(),
      MapEntryFromListing(position: final p) => _centerOnFit(p),
      MapEntryFromSearch() => _fitToMarkers(markers),
    };
  }

  MapMarker? _initialSelectedMarker(
    MapEntryContext? context,
    List<MapMarker> markers,
  ) {
    if (context is MapEntryFromListing) {
      final hit = markers.where((m) => m.id == context.listingId);
      return hit.isEmpty ? null : hit.first;
    }
    return null;
  }
}
