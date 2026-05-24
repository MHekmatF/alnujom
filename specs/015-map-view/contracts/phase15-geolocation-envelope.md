# Contract: Geolocation envelope (permission + fix lifecycle + no-persistence rule)

**Phase**: 15 — Map View
**Owner**: Sub-Phase E (presentation) — `CenterOnMyLocationFab` widget + `MapBloc` handlers
**Files**: `lib/features/map/presentation/widgets/center_on_my_location_fab.dart`, `lib/features/map/presentation/bloc/map_bloc.dart`
**Spec refs**: FR-015b, FR-015c, FR-019, SC-014, SC-015
**Research refs**: R-88 (plugin choice)
**Manifest entries**: `android/app/src/main/AndroidManifest.xml` adds `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>` and `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>` (Sub-Phase A)

## Permission lifecycle

```
First tap on FAB:
  → permission_handler.Permission.locationWhenInUse.status
    ├ denied (never asked)        → request → user prompt appears
    │   ├ granted                  → call Geolocator.getCurrentPosition()
    │   │   ├ fix obtained         → dispatch GeolocationPermissionGranted(coords)
    │   │   └ fix failed (timeout) → dispatch GeolocationFixFailed
    │   ├ denied (one-time)        → dispatch GeolocationPermissionDenied(permanentlyDenied: false)
    │   └ permanentlyDenied        → dispatch GeolocationPermissionDenied(permanentlyDenied: true)
    ├ granted                       → call Geolocator.getCurrentPosition() (skip prompt)
    │   ├ fix obtained             → dispatch GeolocationPermissionGranted(coords)
    │   └ fix failed (timeout)     → dispatch GeolocationFixFailed
    └ permanentlyDenied            → dispatch GeolocationPermissionDenied(permanentlyDenied: true)
                                       (no prompt — OS suppresses)

Subsequent taps:
  Same flow; the `granted` branch is the fast path.

GeolocationPermissionDenied(permanentlyDenied: true) UX:
  Show localized snackbar with action "Open settings" that calls
  permission_handler.openAppSettings(). User returns from settings;
  if they granted, the next tap proceeds normally.
```

## FAB widget implementation sketch

```dart
class CenterOnMyLocationFab extends StatelessWidget {
  const CenterOnMyLocationFab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FloatingActionButton(
      tooltip: l10n.map_fab_center_on_me_tooltip,
      onPressed: () => _handleTap(context),
      child: const Icon(Icons.my_location),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final bloc = context.read<MapBloc>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final status = await Permission.locationWhenInUse.request();
    if (status.isPermanentlyDenied) {
      bloc.add(const GeolocationPermissionDenied(permanentlyDenied: true));
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.map_geolocation_permission_permanently_denied_message),
        action: SnackBarAction(
          label: l10n.map_geolocation_open_settings_action,
          onPressed: openAppSettings,
        ),
      ));
      return;
    }
    if (!status.isGranted) {
      bloc.add(const GeolocationPermissionDenied(permanentlyDenied: false));
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.map_geolocation_permission_denied_message),
      ));
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      bloc.add(GeolocationPermissionGranted(
        MarkerCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      ));
    } on TimeoutException {
      bloc.add(const GeolocationFixFailed());
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.map_geolocation_fix_unavailable_message),
      ));
    }
  }
}
```

## BLoC handler

```dart
on<GeolocationPermissionGranted>((event, emit) {
  final current = state;
  if (current is! MapLoaded) return;
  emit(current.copyWith(
    cameraFit: CameraFit.coordinates(
      coordinates: [event.devicePosition],
      maxZoom: 15,  // neighborhood-level zoom per FR-015b
    ),
    geolocationStatus: GeolocationStatus.granted,
  ));
});
```

(The `flutter_map` `MapController` is notified of the camera change via a controller listener on `MapLoaded` state.cameraFit changes — implementation detail in the page; the bloc just sets the desired camera.)

## Behavioral contract

1. **First tap triggers prompt** (FR-015b): When `Permission.locationWhenInUse.status` is `denied (never asked)`, the FAB tap MUST call `.request()` and surface the Android runtime prompt.
2. **Subsequent taps after grant skip prompt** (FR-015b, SC-014): When status is `granted`, the FAB tap MUST proceed directly to `getCurrentPosition` without any prompt — Android does NOT re-show the prompt for an already-granted permission.
3. **Permanently denied → OS-settings recovery** (FR-015b): When the user has selected "Don't ask again" or denied twice, the status returns `permanentlyDenied`. The snackbar surfaces an "Open settings" action that calls `permission_handler.openAppSettings()` — this is the user's recovery path.
4. **Fix timeout** (SC-015 edge case): `Geolocator.getCurrentPosition` MUST be called with `timeLimit: Duration(seconds: 10)`. On `TimeoutException`, dispatch `GeolocationFixFailed` and surface the localized "location unavailable" snackbar.
5. **No server-side persistence** (FR-015c): The device's position MUST NEVER be sent to Supabase. No INSERT to any table. No audit-log entry. No query parameter. The position is consumed only by the bloc's `cameraFit` update and discarded on page dispose.
6. **No background location** (R-88): The permission requested is `locationWhenInUse`, not `locationAlways`. The map does NOT request background location.
7. **No geocoding**: The device's `(lat, lng)` is NOT reverse-geocoded to an address — that's out of Phase 15 scope and would require a separate plugin.
8. **Anonymous + authenticated parity** (FR-015c): The flow is identical for both anonymous and signed-in users. No auth check.

## Verification (manual, Infinix Note 8)

- Fresh install (or app data cleared). Open map. Tap FAB. Confirm Android prompt appears. Tap "Allow." Confirm map pans + zooms to your current location within 3 seconds.
- Tap FAB again immediately. Confirm no prompt; map re-pans to current location (within 1 second).
- Open Android Settings → Apps → AlNujom → Permissions → Location → "Don't allow." Return to app. Tap FAB. Confirm snackbar with "Open settings" action. Tap "Open settings." Confirm OS settings app opens at the AlNujom permission screen.
- Disable device location services entirely (Quick Settings → Location toggle off). Tap FAB. Confirm permission grants (already granted state) but `getCurrentPosition` times out → snackbar "Location unavailable."
- Inspect Supabase logs (via MCP `get_logs`) during the entire flow. Confirm zero requests carry the device's coordinates as a query parameter or body field.

## Wire-level grep gate

```bash
# Phase 15 G code path MUST NOT include the device's coords in any Supabase call.
grep -RE "latitude|longitude" lib/features/map/data/datasources/ \
  | grep -v "marker_lat\|marker_lng\|MapMarkerDto\|MarkerCoordinates"
# Expected: zero matches (the only lat/lng references are the view's marker_lat/marker_lng
# column reads, NOT user-position writes).
```
