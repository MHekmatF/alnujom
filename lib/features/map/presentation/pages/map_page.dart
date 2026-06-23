// lib/features/map/presentation/pages/map_page.dart
//
// Phase 15 Sub-Phase E (T052 + T053) — full MapPage composition replacing
// the Sub-Phase A stub per contracts/phase15-map-page-composition.md
// §Widget tree + §Marker builder.
//
// StatefulWidget per the contract: the `_alertShown` flag enforces the
// once-per-session show-once behavior of the filter-active alert
// (FR-007a / SC-013) without depending on BLoC state to remember whether
// the dialog already fired.
//
// Widget tree (top-to-bottom):
//   BlocProvider<MapBloc>(
//     create: getIt<MapBloc>()..add(MapOpened(entryContext)),
//     child: Scaffold(
//       appBar: AppBar(
//         leading: DeepLinkAwareBackButton,          // R-71 / R-96
//         title: l10n.map_page_title,
//         actions: [MapRefreshButton],               // R-89
//       ),
//       body: BlocConsumer<MapBloc, MapState>(
//         listener: filter-alert show-once gating,
//         builder: switch over states
//           MapLoaded → Stack(
//             FlutterMap(
//               TileLayer (OSM, R-94),
//               MarkerClusterLayerWidget (R-93),
//             ),
//             PositionedDirectional(OsmAttributionWidget) bottom-start,
//             PositionedDirectional(CenterOnMyLocationFab) bottom-end,
//             if (selectedMarker) Positioned(MarkerPreviewPopover) bottom,
//           ),
//       ),
//     ),
//   )
//
// Camera-fit changes: when the BLoC emits a new MapLoaded with a different
// `cameraFit` (e.g., from a `GeolocationPermissionGranted` event), the page
// commands the MapController to fit the new camera via
// `_controller.fitCamera(...)`. flutter_map's `initialCameraFit` is only
// honored on first build, so a controller-driven update is required.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/di/injection.dart';
import '../../../../core/settings/lite_mode.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/map_entry_context.dart';
import '../../domain/entities/map_marker.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../widgets/center_on_my_location_fab.dart';
import '../widgets/filter_active_alert_dialog.dart';
import '../widgets/map_refresh_button.dart';
import '../widgets/marker_pins.dart';
import '../widgets/marker_preview_popover.dart';
import '../widgets/osm_attribution_widget.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.entryContext});

  final MapEntryContext? entryContext;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  /// One-shot gate for the filter-active alert dialog (FR-007a, SC-013).
  /// `BlocConsumer.listener` flips this true on the FIRST observation of
  /// `MapLoaded.showFilterAlert == true` so the alert cannot re-show after
  /// rebuilds.
  bool _alertShown = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (_) =>
          getIt<MapBloc>()..add(MapOpened(context: widget.entryContext)),
      child: const _MapView(),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.map_page_title),
        actions: const [MapRefreshButton()],
      ),
      body: BlocConsumer<MapBloc, MapState>(
        listenWhen: (prev, curr) => curr is MapLoaded,
        listener: (context, state) {
          // Use Element-tree access to the _MapPageState ancestor so the
          // _alertShown gate survives BLoC rebuilds. NOTE: relies on
          // _MapView being a direct descendant of MapPage — any future
          // refactor that hoists _MapView out of this file must port
          // _alertShown into an InheritedWidget / Provider.
          final pageState = context.findAncestorStateOfType<_MapPageState>();
          if (state is MapLoaded &&
              state.showFilterAlert &&
              pageState != null &&
              !pageState._alertShown) {
            pageState._alertShown = true;
            final bloc = context.read<MapBloc>();
            showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (_) =>
                  FilterActiveAlertDialog(filterState: state.activeFilter!),
            ).then((_) {
              // Barrier-tap dismiss does NOT call either action's onPressed;
              // dispatch FilterAlertDismissed unconditionally on any close
              // path so the BLoC's showFilterAlert flag flips to false. The
              // Reset path has already mutated state (filter cleared) by the
              // time this runs, so a no-op extra Dismissed is harmless.
              bloc.add(const FilterAlertDismissed());
            });
          }
        },
        builder: (context, state) {
          return switch (state) {
            MapInitial() => const AppSpinner.page(),
            MapLoading() => const AppSpinner.page(),
            MapError(failure: final f) => _ErrorBody(message: f.message),
            MapLoaded() => _LoadedBody(state: state),
          };
        },
      ),
    );
  }
}

/// The Stack that holds the FlutterMap + overlay chrome. Owns a
/// MapController so subsequent `MapLoaded.cameraFit` updates can imperatively
/// move the camera (e.g., the "center on my location" flow).
class _LoadedBody extends StatefulWidget {
  const _LoadedBody({required this.state});
  final MapLoaded state;

  @override
  State<_LoadedBody> createState() => _LoadedBodyState();
}

class _LoadedBodyState extends State<_LoadedBody> {
  // Tile-zoom caps: full fidelity vs. Data saver (fewer high-detail tiles).
  static const int _fullMapMaxZoom = 18;
  static const int _liteMapMaxZoom = 15;

  late final MapController _controller;
  CameraFit? _appliedFit;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    _appliedFit = widget.state.cameraFit;
  }

  @override
  void didUpdateWidget(_LoadedBody old) {
    super.didUpdateWidget(old);
    // Identity-compare suffices because the BLoC always allocates a fresh
    // CameraFit instance when emitting a camera change.
    if (!identical(widget.state.cameraFit, _appliedFit)) {
      _appliedFit = widget.state.cameraFit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.fitCamera(widget.state.cameraFit);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LiteMode.notifier,
      builder: (context, lite, _) => _buildMap(context, lite),
    );
  }

  Widget _buildMap(BuildContext context, bool lite) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    // Data saver: cap the tile zoom so the map never fetches the densest
    // high-detail tile levels on a slow connection. The camera + clustering
    // honour the same cap so nothing requests tiles that won't be served.
    final tileMaxZoom = lite ? _liteMapMaxZoom : _fullMapMaxZoom;

    Widget clusterLayer = MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 80,
        // Defaults: spiderfyCluster=true, disableClusteringAtZoom=20,
        // so at max-zoom (18) co-located markers still cluster but a
        // tap spiderfies them — matches R-93 conditional behavior.
        zoomToBoundsOnClick: true,
        centerMarkerOnClick: true,
        showPolygon: false,
        size: const Size(40, 40),
        padding: const EdgeInsets.all(
          AppSpacing.xxl + AppSpacing.sm,
        ), // 32+8=40
        maxZoom: tileMaxZoom.toDouble(),
        markers: state.markers
            .map((m) => _buildMarker(context, m))
            .toList(growable: false),
        builder: (context, markers) => ClusterBadge(count: markers.length),
      ),
    );
    // One-shot reveal of the pins as the dataset first lands. `_LoadedBody`
    // only rebuilds on state changes (camera fit, selection, refresh) — never
    // on pan/zoom — and flutter_animate's State persists across those rebuilds,
    // so the fade plays once and never re-triggers while panning.
    if (!reduceMotion(context)) {
      clusterLayer = clusterLayer.animate().fadeIn(duration: AppMotion.slow);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: state.cameraFit,
            minZoom: 6,
            maxZoom: tileMaxZoom.toDouble(),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            // Tap outside any marker dismisses the popover.
            onTap: (_, __) {
              if (state.selectedMarker != null) {
                context.read<MapBloc>().add(const PopoverDismissed());
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.alnujom.realestate',
              maxZoom: tileMaxZoom.toDouble(),
              errorTileCallback: (_, __, ___) {
                // Per spec: render the default grey error tile (no custom
                // widget needed; the empty callback satisfies the
                // signature while flutter_map renders its built-in
                // placeholder).
              },
            ),
            clusterLayer,
          ],
        ),
        const PositionedDirectional(
          bottom: AppSpacing.sm,
          start: AppSpacing.sm,
          child: OsmAttributionWidget(),
        ),
        const PositionedDirectional(
          bottom: 80,
          end: AppSpacing.lg,
          child: CenterOnMyLocationFab(),
        ),
        if (state.selectedMarker != null)
          PositionedDirectional(
            bottom: AppSpacing.lg,
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            child: MarkerPreviewPopover(marker: state.selectedMarker!),
          ),
        if (state.markers.isEmpty)
          PositionedDirectional(
            top: AppSpacing.lg,
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            child: _EmptyDatasetBanner(
              message: l10n.map_empty_state_no_listings,
            ),
          ),
      ],
    );
  }

  /// T053 — marker builder helper per contract §Marker builder.
  Marker _buildMarker(BuildContext context, MapMarker marker) {
    final isApprox = marker.isApproximate;
    return Marker(
      point: LatLng(marker.position.latitude, marker.position.longitude),
      width: isApprox ? 48 : 40,
      height: isApprox ? 48 : 40,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () =>
            context.read<MapBloc>().add(MarkerTapped(listingId: marker.id)),
        child: isApprox ? const ApproximateMarkerPin() : const ExactMarkerPin(),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ErrorState(
      title: l10n.map_error_load_failed,
      message: message,
      variant: ErrorStateVariant.network,
      onRetry: () =>
          context.read<MapBloc>().add(const MarkersRefreshRequested()),
    );
  }
}

class _EmptyDatasetBanner extends StatelessWidget {
  const _EmptyDatasetBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    // DS floating chrome over the tiles — a rounded `surface` pill with a
    // hairline outline and the token shadow so it reads as the same family as
    // the other on-map controls.
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.96),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level2,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.info,
              size: AppSpacing.lg,
              color: colors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: styles.labelMedium.copyWith(color: colors.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
