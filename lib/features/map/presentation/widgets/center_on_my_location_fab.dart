// lib/features/map/presentation/widgets/center_on_my_location_fab.dart
//
// Phase 15 Sub-Phase E (T051) — FloatingActionButton at the bottom-end of
// the map overlay per contracts/phase15-geolocation-envelope.md §FAB widget.
//
// Permission lifecycle (see envelope contract §Permission lifecycle):
//   denied (never asked)   → permission_handler.request() → grant / deny / pd
//   granted (fast path)    → Geolocator.getCurrentPosition()
//   permanentlyDenied      → snackbar with "Open settings" action
//
// FR-015c invariant: the obtained position is dispatched ONLY into the BLoC
// event surface; NEVER sent to Supabase, NEVER persisted, NEVER logged.
// The BLoC consumes the coordinate to update the camera and discards it on
// page dispose.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/marker_coordinates.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';

class CenterOnMyLocationFab extends StatelessWidget {
  const CenterOnMyLocationFab({super.key});

  static const _kFixTimeout = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FloatingActionButton(
      heroTag: 'centerOnMyLocationFab',
      tooltip: l10n.map_fab_center_on_me_tooltip,
      onPressed: () => _handleTap(context),
      child: const Icon(Icons.my_location),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final bloc = context.read<MapBloc>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    // .request() is idempotent against an already-granted permission: it
    // returns the current status without re-prompting per Android's
    // permission semantics.
    final status = await Permission.locationWhenInUse.request();

    if (status.isPermanentlyDenied) {
      bloc.add(const GeolocationPermissionDenied(permanentlyDenied: true));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.map_geolocation_permission_permanently_denied_message,
          ),
          action: SnackBarAction(
            label: l10n.map_geolocation_open_settings_action,
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    if (!status.isGranted) {
      bloc.add(const GeolocationPermissionDenied(permanentlyDenied: false));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.map_geolocation_permission_denied_message)),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _kFixTimeout,
        ),
      );
      bloc.add(
        GeolocationPermissionGranted(
          devicePosition: MarkerCoordinates(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        ),
      );
    } on TimeoutException {
      bloc.add(const GeolocationFixFailed());
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.map_geolocation_fix_unavailable_message)),
      );
    } on LocationServiceDisabledException {
      bloc.add(const GeolocationFixFailed());
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.map_geolocation_fix_unavailable_message)),
      );
    }
  }
}
