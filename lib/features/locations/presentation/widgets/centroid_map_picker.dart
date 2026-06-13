// lib/features/locations/presentation/widgets/centroid_map_picker.dart
//
// Phase 29 (W5) — admin centroid picker for the area form.
//
// Closes the create-area blocker: `areas.centroid_lat/centroid_lng` are NOT
// NULL with a CHECK (lat 32..37, lng 35..43), but the form had no way to
// input them. This widget provides:
//   • an embedded FlutterMap using the EXACT same OSM TileLayer +
//     attribution config as map_page.dart (urlTemplate, userAgentPackageName),
//   • the center-pin pattern — a fixed pin icon centered over the map; the
//     map pans under it and the map center is read on every move,
//   • two manual lat/lng AppTextField inputs kept two-way in sync with the map.
//
// Emits the captured coordinate to the parent via [onChanged] (wired to the
// LocationFormBloc's CentroidChanged event).
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';

/// Default map center when no centroid is supplied — roughly the geographic
/// center of Syria, comfortably inside the DB bounds (lat 32..37, lng 35..43).
const LatLng _syriaCenter = LatLng(34.8, 38.9);

class CentroidMapPicker extends StatefulWidget {
  const CentroidMapPicker({
    super.key,
    required this.onChanged,
    this.initialLat,
    this.initialLng,
  });

  /// Called whenever the centroid changes (map pan-end or a valid manual edit).
  final void Function(double lat, double lng) onChanged;

  /// Existing centroid (area edit). When null the map opens on Syria's center.
  final double? initialLat;
  final double? initialLng;

  @override
  State<CentroidMapPicker> createState() => _CentroidMapPickerState();
}

class _CentroidMapPickerState extends State<CentroidMapPicker> {
  static const double _initialZoom = 7;
  static const double _minZoom = 6;
  static const double _maxZoom = 18;

  late final MapController _controller;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  /// Guards against the map→fields→map feedback loop: set true while we drive
  /// the map from a manual text edit so the resulting onPositionChanged does
  /// not overwrite what the user is typing.
  bool _syncingFromFields = false;

  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    final hasInitial = widget.initialLat != null && widget.initialLng != null;
    _center = hasInitial
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _syriaCenter;
    _latController = TextEditingController(
      text: hasInitial ? _format(widget.initialLat!) : '',
    );
    _lngController = TextEditingController(
      text: hasInitial ? _format(widget.initialLng!) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  String _format(double v) => v.toStringAsFixed(5);

  // ── Map → fields ───────────────────────────────────────────────────────────

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    // Only respond to user gestures on the map; programmatic moves (from a
    // manual field edit) are suppressed so we don't fight the text cursor.
    if (_syncingFromFields) return;
    if (!hasGesture) return;
    final c = camera.center;
    _center = c;
    _latController.text = _format(c.latitude);
    _lngController.text = _format(c.longitude);
    widget.onChanged(c.latitude, c.longitude);
  }

  // ── Fields → map ─────────────────────────────────────────────────────────

  void _onLatChanged(String raw) => _applyFieldEdit(latRaw: raw);
  void _onLngChanged(String raw) => _applyFieldEdit(lngRaw: raw);

  void _applyFieldEdit({String? latRaw, String? lngRaw}) {
    final lat = double.tryParse((latRaw ?? _latController.text).trim());
    final lng = double.tryParse((lngRaw ?? _lngController.text).trim());
    if (lat == null || lng == null) {
      // One field still incomplete — nothing to sync yet. The bloc's save-time
      // validation will surface "centroid required" if the user never finishes.
      return;
    }
    _center = LatLng(lat, lng);
    widget.onChanged(lat, lng);
    // Drive the map to the typed point without re-triggering a field update.
    _syncingFromFields = true;
    final zoom = _controller.camera.zoom;
    _controller.move(_center, zoom);
    // Release the guard after the move settles (next frame).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncingFromFields = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.map_pin,
              size: AppSpacing.lg,
              color: colors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(l10n.locationCentroidLabel, style: styles.labelLarge),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.locationCentroidHelper,
          style: styles.bodyMedium.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: appRadius(AppRadii.lg),
          child: SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _initialZoom,
                    minZoom: _minZoom,
                    maxZoom: _maxZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: _onPositionChanged,
                  ),
                  children: [
                    // EXACT reuse of map_page.dart's OSM tile config (R-94).
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'app.alnujom.realestate',
                      maxZoom: _maxZoom,
                      errorTileCallback: (_, __, ___) {},
                    ),
                  ],
                ),
                // Fixed center pin — the map pans beneath it; its tip marks the
                // captured centroid. IgnorePointer so map gestures pass through.
                IgnorePointer(
                  child: Padding(
                    // Lift the glyph so its tip (bottom) sits on the exact
                    // map center rather than its visual middle.
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.xl,
                    ),
                    child: Icon(
                      LucideIcons.map_pin,
                      size: AppSpacing.xxl,
                      color: colors.primary,
                    ),
                  ),
                ),
                // OSM attribution (R-94 / FR-019) — bottom-start.
                PositionedDirectional(
                  bottom: AppSpacing.xs,
                  start: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.85),
                      borderRadius: appRadius(AppRadii.sm),
                    ),
                    child: Text(
                      l10n.map_osm_attribution,
                      style: styles.labelMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.locationCentroidLatLabel,
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: _onLatChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: l10n.locationCentroidLngLabel,
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: _onLngChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
