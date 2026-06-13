// Phase 29 (029-crm-reels-growth) — shared, token-clean horizontal bar list.
//
// TokenHbarList: labeled horizontal bars for categorical data (viewings by
// status, listings by status/governorate, …). Each row is a leading label
// (start), a track (faint outline tint) holding a filled bar (primary, width
// proportional to value / max), and the trailing value (end). The value is
// passed pre-formatted by the caller (Arabic-Indic digits via NumberFormat) so
// this widget stays purely presentational.
//
// Token-clean: uses AppColors / AppTextStyles / AppSpacing / appRadius only — no
// inline colour, text-style, or numeric-padding literals. RTL-safe: directional
// padding, FractionallySizedBox aligned to centerStart so the fill grows from
// the leading edge in both LTR and RTL.
import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// A single categorical row: a [label], its raw [value] (drives the bar width
/// relative to the list max), the pre-formatted [valueLabel] shown at the end,
/// and an optional per-row [barColor] override.
class TokenHbarItem {
  const TokenHbarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.barColor,
  });

  final String label;
  final num value;
  final String valueLabel;
  final Color? barColor;
}

/// A vertical list of [TokenHbarItem] rows. Bar widths are normalized to the
/// largest [value] across [items]; when every value is zero each track shows a
/// faint minimum nib so the rows still read.
class TokenHbarList extends StatelessWidget {
  const TokenHbarList({
    super.key,
    required this.items,
    this.trackHeight = AppSpacing.sm,
  });

  final List<TokenHbarItem> items;

  /// Height of each bar track.
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(
      0,
      (peak, item) => item.value > peak ? item.value.toDouble() : peak,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _Row(item: items[i], maxValue: maxValue, trackHeight: trackHeight),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.maxValue,
    required this.trackHeight,
  });

  final TokenHbarItem item;
  final double maxValue;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final fill = item.barColor ?? colors.primary;

    // Smallest non-zero fraction so a genuine (but tiny) value is still visible.
    final double fraction = maxValue <= 0
        ? 0
        : (item.value <= 0 ? 0 : (item.value / maxValue).clamp(0.04, 1.0));

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.bodyMedium.copyWith(color: colors.onSurface),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 7,
          child: ClipRRect(
            borderRadius: appRadius(AppRadii.pill),
            child: Container(
              height: trackHeight,
              color: colors.outline.withValues(alpha: 0.35),
              child: fraction <= 0
                  ? null
                  : FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: fraction,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: appRadius(AppRadii.pill),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          item.valueLabel,
          style: styles.labelLarge.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }
}
