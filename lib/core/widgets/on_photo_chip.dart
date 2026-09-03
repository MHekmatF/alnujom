import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/spacing.dart';

/// A round, near-opaque chip for an icon button that sits **on top of a photo**.
///
/// A bare icon over a photograph is a coin toss: it disappears against a pale
/// sky and again against a dark interior, and no single foreground colour fixes
/// both. The app already solved this for the favourite heart — a white disc with
/// a dark glyph — and this is that treatment, extracted so every on-photo
/// control can use it instead of each one re-inventing a scrim.
///
/// It also makes a control readable once the photo behind it is *gone*: the
/// listing gallery collapses into an opaque header, and a chip stays legible
/// there in both themes, where a fixed white glyph would vanish in light mode.
class OnPhotoChip extends StatelessWidget {
  const OnPhotoChip({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconColor,
  });

  final Widget icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// Defaults to [AppColors.photoOverlay] — the dark glyph the disc is sized for.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppElevation.of(context).level1,
      ),
      child: Material(
        color: colors.onPhoto.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: IconTheme.merge(
              data: IconThemeData(
                size: AppSpacing.xl,
                color: iconColor ?? colors.photoOverlay,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
