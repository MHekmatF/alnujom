import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// Phase 25 (Claude Design) — frosted dark pill for labels rendered *over* a
/// photo (e.g. the property type on a listing card / gallery). Theme-
/// independent on purpose: it always reads as a dark glass chip with white
/// text since it sits on imagery, not on a themed surface.
class GlassPill extends StatelessWidget {
  const GlassPill({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return ClipRRect(
      borderRadius: appRadius(AppRadii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: appRadius(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSpacing.md, color: Colors.white),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: styles.labelMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
