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
    final content = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: opacity,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? colors.card,
          borderRadius: appRadius(radius),
          border: Border.all(color: borderColor ?? colors.outline),
          boxShadow: elevated ? elevation.level1 : elevation.level0,
        ),
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: appRadius(radius),
        onTap: onTap,
        child: content,
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

Widget appInlineSpinner(BuildContext context) {
  final colors = AppColors.of(context);
  return SizedBox.square(
    dimension: AppSpacing.lg,
    child: CircularProgressIndicator(
      strokeWidth: AppDimens.strokeThin,
      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
    ),
  );
}
