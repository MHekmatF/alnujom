import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'dimens.dart';

const double kAppMinTouchTarget = AppSpacing.xxxl;

BorderRadius appRadius([double radius = AppRadii.md]) {
  return BorderRadius.circular(radius);
}

EdgeInsetsDirectional appPadding({
  double horizontal = AppSpacing.lg,
  double vertical = AppSpacing.md,
}) {
  return EdgeInsetsDirectional.symmetric(
    horizontal: horizontal,
    vertical: vertical,
  );
}

/// Reserves a 48×48 dp layout slot around [child].
///
/// Layout helper only — does NOT install a gesture detector. The actual
/// hit area still depends on the *interactive* widget inside the slot
/// (e.g., `IconButton`, `TextButton`, `FloatingActionButton`, all of which
/// already enforce a 48 dp minimum). Wrapping a non-interactive child
/// here will not enlarge the tap region; for that case use a wrapper
/// that owns the gesture (`InkWell`, `GestureDetector`) and apply these
/// constraints directly to the interactive widget instead.
class AppTapTarget extends StatelessWidget {
  const AppTapTarget({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kAppMinTouchTarget,
        minHeight: kAppMinTouchTarget,
      ),
      child: Center(child: child),
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.radius = AppRadii.md,
    this.elevated = false,
    this.onTap,
    this.opacity = 1,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;
  final VoidCallback? onTap;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);
    final surfaceColor = color ?? colors.card;
    final outlineColor = borderColor ?? colors.outline;
    final shape = RoundedRectangleBorder(
      borderRadius: appRadius(radius),
      side: BorderSide(color: outlineColor),
    );

    final paddedChild = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    if (onTap == null) {
      // Non-interactive surface — no Material/InkWell needed.
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: appRadius(radius),
            border: Border.all(color: outlineColor),
            boxShadow: elevated ? elevation.level1 : elevation.level0,
          ),
          child: paddedChild,
        ),
      );
    }

    // Interactive surface — Material owns the colour so InkWell splash
    // paints on top of the surface, not behind it.
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: opacity,
      child: Material(
        color: surfaceColor,
        shape: shape,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: appRadius(radius),
            boxShadow: elevated ? elevation.level1 : elevation.level0,
          ),
          child: InkWell(
            borderRadius: appRadius(radius),
            onTap: onTap,
            child: paddedChild,
          ),
        ),
      ),
    );
  }
}

class AppSectionText extends StatelessWidget {
  const AppSectionText({
    required this.text,
    this.secondary = false,
    this.maxLines,
    super.key,
  });

  final String text;
  final bool secondary;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: secondary ? styles.bodyMedium : styles.bodyLarge,
    );
  }
}

Widget appInlineSpinner(BuildContext context, {Color? color}) {
  final colors = AppColors.of(context);
  return SizedBox.square(
    dimension: AppSpacing.lg,
    child: CircularProgressIndicator(
      strokeWidth: AppDimens.strokeThin,
      valueColor: AlwaysStoppedAnimation<Color>(color ?? colors.primary),
    ),
  );
}
