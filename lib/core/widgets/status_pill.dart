import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// Phase 25 — a solid, semantic status/purpose pill (the Figma graft:
/// visually distinct sale vs rent). The caller picks the token colour
/// (e.g. sale → primary, rent → verified-green) so this stays domain-free
/// and reusable on cards, the listing detail, and filter chips.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    this.foreground,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final Color? foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    final fg = foreground ?? Colors.white;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.md, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: styles.labelMedium.copyWith(color: fg)),
        ],
      ),
    );
  }
}
