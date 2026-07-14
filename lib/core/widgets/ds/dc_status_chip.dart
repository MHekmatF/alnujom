import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// The four DC status tones (`AlNujom - Publisher.dc.html`).
enum DcStatusTone {
  /// Live / approved / confirmed / resolved — green container.
  green,

  /// Rejected / declined — red container.
  red,

  /// Pending / expired / neutral — surface2 container.
  neutral,

  /// Draft / "required" — transparent with a hairline outline.
  outline,
}

/// DC "Blue Crown" status chip — a soft tonal pill for a listing/viewing/report/
/// document status. Two shapes: the default soft chip (radius-sm, optional
/// leading icon) and a [dot] pill (radius-pill, a leading colour dot) used by the
/// CRM stage indicator. [label] is pre-localized by the caller.
class DcStatusChip extends StatelessWidget {
  const DcStatusChip({
    required this.label,
    required this.tone,
    this.icon,
    this.dot = false,
    super.key,
  });

  final String label;
  final DcStatusTone tone;

  /// Optional leading icon (soft-chip shape only). Ignored when [dot] is true.
  final IconData? icon;

  /// Render the CRM stage "dot pill" shape (pill radius + a leading colour dot)
  /// instead of the default soft chip.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final (bg, fg, strong, border) = switch (tone) {
      DcStatusTone.green => (
        colors.verifiedContainer,
        colors.onSuccess,
        colors.verified,
        null,
      ),
      DcStatusTone.red => (
        colors.errorContainer,
        colors.onErrorContainer,
        colors.error,
        null,
      ),
      DcStatusTone.neutral => (
        colors.surfaceVariant,
        colors.textMuted,
        colors.textMuted,
        null,
      ),
      DcStatusTone.outline => (
        Colors.transparent,
        colors.textMuted,
        colors.textMuted,
        colors.outlineStrong,
      ),
    };

    final labelStyle = styles.labelSmall.copyWith(
      color: fg,
      fontWeight: FontWeight.w700,
    );

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: appRadius(dot ? AppRadii.pill : AppRadii.sm),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: strong, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(label, style: labelStyle),
        ],
      ),
    );
  }
}
