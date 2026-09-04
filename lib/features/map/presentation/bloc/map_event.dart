// lib/features/map/presentation/bloc/map_event.dart
//
// Phase 15 Sub-Phase E (T042) — sealed `MapEvent` hierarchy consumed by
// [MapBloc] per contracts/phase15-map-page-composition.md §BLoC contract.
//
// 10 events split into 3 logical clusters:
//   • Lifecycle / data:    MapOpened, MarkersRefreshRequested
//   • Marker interaction:  MarkerTapped, PopoverDismissed
//   • Geolocation FAB sub-state machine (per phase15-geolocation-envelope.md):
//                          CenterOnMyLocationRequested,
//                          GeolocationPermissionGranted,
//                          GeolocationPermissionDenied,
//                          GeolocationFixFailed
//   • Filter alert (US6):  FilterAlertDismissed, FilterResetRequested
import '../../domain/entities/map_bounds.dart';
import '../../domain/entities/map_entry_context.dart';
import '../../domain/entities/marker_coordinates.dart';

sealed class MapEvent {
  const MapEvent();
}

/// Fired on `BlocProvider.create`. Determines the initial camera + filter +
/// pre-selected marker per [MapEntryContext] case.
final class MapOpened extends MapEvent {
  const MapOpened({this.context});
  final MapEntryContext? context;
}

/// Fired from [MapRefreshButton] tap. Re-fetches using the cached
/// [MapLoaded.activeFilter] (preserving the camera).
final class MarkersRefreshRequested extends MapEvent {
  const MarkersRefreshRequested();
}

/// Plan A17 — fired when the camera has settled somewhere new (the widget
/// debounces `onMapEvent`). Carries the visible viewport so the BLoC can fetch
/// the markers for it instead of the whole country. The camera is NOT touched
/// by the handler: the user moved it, not us.
final class MapViewportChanged extends MapEvent {
  const MapViewportChanged({required this.bounds});
  final MapBounds bounds;
}

/// Fired when the user taps any marker on the map.
final class MarkerTapped extends MapEvent {
  const MarkerTapped({required this.listingId});
  final String listingId;
}

/// Fired when the popover is dismissed (tap on map outside marker or close).
final class PopoverDismissed extends MapEvent {
  const PopoverDismissed();
}

/// Fired from the [CenterOnMyLocationFab] tap, BEFORE the permission flow.
/// Reserved for future BLoC-side bookkeeping; the FAB widget currently does
/// not need to dispatch this — it dispatches one of the three terminal
/// outcomes below. Kept in the event surface for completeness per contract.
final class CenterOnMyLocationRequested extends MapEvent {
  const CenterOnMyLocationRequested();
}

/// Fired from the FAB handler after a successful permission + location fix.
/// Carries the device's current coordinates so the BLoC can update
/// [MapLoaded.cameraFit] to centre on the device location.
final class GeolocationPermissionGranted extends MapEvent {
  const GeolocationPermissionGranted({required this.devicePosition});
  final MarkerCoordinates devicePosition;
}

/// Fired from the FAB handler on user denial. [permanentlyDenied] is true
/// when the OS returned `Permission.permanentlyDenied` (user selected
/// "Don't ask again" or denied twice) — the snackbar surfaces an
/// "Open settings" recovery action in that case.
final class GeolocationPermissionDenied extends MapEvent {
  const GeolocationPermissionDenied({required this.permanentlyDenied});
  final bool permanentlyDenied;
}

/// Fired from the FAB handler when permission was granted but
/// `Geolocator.getCurrentPosition` did not return a fix within the 10s
/// deadline (TimeoutException). The FAB widget surfaces the localized
/// "location unavailable" snackbar.
final class GeolocationFixFailed extends MapEvent {
  const GeolocationFixFailed();
}

/// Fired on "Keep filters" tap or tap-outside in the filter-active alert.
/// Just hides the alert; does not touch the marker dataset.
final class FilterAlertDismissed extends MapEvent {
  const FilterAlertDismissed();
}

/// Fired on "Reset filters" tap in the filter-active alert. Re-fetches the
/// full marker dataset (no filter) and clears [MapLoaded.activeFilter].
final class FilterResetRequested extends MapEvent {
  const FilterResetRequested();
}
