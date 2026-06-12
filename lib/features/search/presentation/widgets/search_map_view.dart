// lib/features/search/presentation/widgets/search_map_view.dart
//
// Phase 25 premium uplift — the embedded map presentation of the search
// results. Reuses the map feature's MapBloc + FlutterMap rendering (cluster
// layer, marker pins, preview popover, OSM attribution) WITHOUT the full
// MapPage chrome (no app bar, no filter-active alert). Honors the same
// [FilterState] the list view does via the `search_map` RPC (MapBloc →
// LoadMapMarkers → search_map). A "View full map" affordance hands off to the
// standalone /map route for the richer experience (geolocation FAB, refresh).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/settings/lite_mode.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../map/domain/entities/map_entry_context.dart';
import '../../../map/domain/entities/map_marker.dart';
import '../../../map/presentation/bloc/map_bloc.dart';
import '../../../map/presentation/bloc/map_event.dart';
import '../../../map/presentation/bloc/map_state.dart';
import '../../../map/presentation/widgets/marker_pins.dart';
import '../../../map/presentation/widgets/marker_preview_popover.dart';
import '../../../map/presentation/widgets/osm_attribution_widget.dart';
import '../../domain/entities/filter_state.dart';

class SearchMapView extends StatelessWidget {
  const SearchMapView({super.key, required this.filters});

  final FilterState filters;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (_) => getIt<MapBloc>()
        ..add(
          MapOpened(
            context: MapEntryFromSearch(
              filterState: filters,
              showFilterAlert: false,
            ),
          ),
        ),
      child: _SearchMapBody(filters: filters),
    );
  }
}

class _SearchMapBody extends StatefulWidget {
  const _SearchMapBody({required this.filters});

  final FilterState filters;

  @override
  State<_SearchMapBody> createState() => _SearchMapBodyState();
}

class _SearchMapBodyState extends State<_SearchMapBody> {
  late final MapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
  }

  @override
  void didUpdateWidget(_SearchMapBody old) {
    super.didUpdateWidget(old);
    // Re-fetch markers when the filter set changes while the map is showing.
    if (widget.filters != old.filters) {
      context.read<MapBloc>().add(
        MapOpened(
          context: MapEntryFromSearch(
            filterState: widget.filters,
            showFilterAlert: false,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        return switch (state) {
          MapInitial() || MapLoading() => const AppSpinner.page(),
          MapError(failure: final f) => _MapErrorBody(message: f.message),
          MapLoaded() => _LoadedMap(controller: _controller, state: state),
        };
      },
    );
  }
}

class _LoadedMap extends StatefulWidget {
  const _LoadedMap({required this.controller, required this.state});

  final MapController controller;
  final MapLoaded state;

  @override
  State<_LoadedMap> createState() => _LoadedMapState();
}

class _LoadedMapState extends State<_LoadedMap> {
  // Tile-zoom caps: full fidelity vs. Data saver (fewer high-detail tiles).
  static const int _fullMapMaxZoom = 18;
  static const int _liteMapMaxZoom = 15;

  CameraFit? _appliedFit;

  @override
  void initState() {
    super.initState();
    _appliedFit = widget.state.cameraFit;
  }

  @override
  void didUpdateWidget(_LoadedMap old) {
    super.didUpdateWidget(old);
    if (!identical(widget.state.cameraFit, _appliedFit)) {
      _appliedFit = widget.state.cameraFit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.fitCamera(widget.state.cameraFit);
      });
    }
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
    // Data saver: cap the tile zoom so the embedded map never pulls the densest
    // high-detail tiles on a slow connection. Camera + clustering share the cap.
    final tileMaxZoom = lite ? _liteMapMaxZoom : _fullMapMaxZoom;

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCameraFit: state.cameraFit,
            minZoom: 6,
            maxZoom: tileMaxZoom.toDouble(),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
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
              errorTileCallback: (_, __, ___) {},
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                zoomToBoundsOnClick: true,
                centerMarkerOnClick: true,
                showPolygon: false,
                size: const Size(40, 40),
                padding: const EdgeInsets.all(AppSpacing.xxl + AppSpacing.sm),
                maxZoom: tileMaxZoom.toDouble(),
                markers: state.markers
                    .map((m) => _buildMarker(context, m))
                    .toList(growable: false),
                builder: (context, markers) =>
                    ClusterBadge(count: markers.length),
              ),
            ),
          ],
        ),
        const PositionedDirectional(
          bottom: AppSpacing.sm,
          start: AppSpacing.sm,
          child: OsmAttributionWidget(),
        ),
        // "View full map" handoff — opens the standalone route with the same
        // filters (full chrome: refresh, geolocation FAB).
        PositionedDirectional(
          top: AppSpacing.md,
          end: AppSpacing.md,
          child: _ViewFullMapButton(filters: widget.state.activeFilter),
        ),
        if (state.markers.isEmpty)
          PositionedDirectional(
            top: AppSpacing.lg,
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            child: _EmptyMapBanner(message: l10n.map_empty_state_no_listings),
          ),
        if (state.selectedMarker != null)
          PositionedDirectional(
            bottom: AppSpacing.lg,
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            child: MarkerPreviewPopover(marker: state.selectedMarker!),
          ),
      ],
    );
  }

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

class _ViewFullMapButton extends StatelessWidget {
  const _ViewFullMapButton({required this.filters});

  final FilterState? filters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: colors.surface.withValues(alpha: 0.94),
      borderRadius: appRadius(AppRadii.pill),
      elevation: 2,
      child: InkWell(
        borderRadius: appRadius(AppRadii.pill),
        onTap: () => context.go(
          AppRoutes.map,
          extra: MapEntryFromSearch(
            filterState: filters ?? const FilterState(),
            showFilterAlert: false,
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_full,
                size: AppSpacing.lg,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.search_view_full_map,
                style: styles.labelLarge.copyWith(color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMapBanner extends StatelessWidget {
  const _EmptyMapBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      elevation: 2,
      borderRadius: appRadius(AppRadii.md),
      color: colors.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: AppSpacing.lg,
              color: colors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(message, style: styles.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _MapErrorBody extends StatelessWidget {
  const _MapErrorBody({required this.message});

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
