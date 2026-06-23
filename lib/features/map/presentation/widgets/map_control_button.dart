// lib/features/map/presentation/widgets/map_control_button.dart
//
// Phase-33 royal-blue DS pass — the shared on-map control button. A circular
// chip that floats over the tiles as quiet chrome: a `surface` fill, a hairline
// `outline`, and an `onSurface` icon, lifted off the map by the token shadow.
// Used for the "center on my location" control (and any future map control)
// instead of the loud brand-primary FloatingActionButton.
//
// Purely visual: it owns no map logic, only the tap callback handed to it.
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/_widget_support.dart';

class MapControlButton extends StatelessWidget {
  const MapControlButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// 48 dp diameter — meets the minimum tap target while staying compact over
  /// the map.
  static const double _diameter = kAppMinTouchTarget;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);

    final button = Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.pill),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _diameter,
          height: _diameter,
          child: Icon(icon, size: AppSpacing.xl, color: colors.onSurface),
        ),
      ),
    );

    // The token shadow lifts the control off the tiles; wrap the same circular
    // footprint so the shadow stays a clean disc.
    final lifted = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: elevation.level2,
      ),
      child: button,
    );

    if (tooltip == null) return lifted;
    return Tooltip(message: tooltip!, child: lifted);
  }
}
