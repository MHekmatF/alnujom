import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Phase 25 uplift — a labeled range-slider field for search filters.
///
/// Renders a header [Row] (the [label] leading, the current selected range
/// trailing) above a Material [RangeSlider] themed to the design tokens
/// (primary active track + thumbs, outline inactive track). The trailing
/// range text is derived from [formatValue] when provided, otherwise the raw
/// values. RTL-safe via [EdgeInsetsDirectional]; the header lays out leading /
/// trailing so it mirrors correctly in Arabic.
class RangeSliderField extends StatelessWidget {
  const RangeSliderField({
    required this.label,
    required this.min,
    required this.max,
    required this.values,
    required this.onChanged,
    this.divisions,
    this.formatValue,
    super.key,
  });

  final String label;
  final double min;
  final double max;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final int? divisions;

  /// Formats a single bound for the header text + thumb labels. When null the
  /// rounded value is shown verbatim.
  final String Function(double)? formatValue;

  String _format(double value) =>
      formatValue?.call(value) ?? value.round().toString();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final rangeText = '${_format(values.start)} — ${_format(values.end)}';

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: styles.labelLarge)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  rangeText,
                  style: styles.labelMedium.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.outline,
              thumbColor: colors.primary,
              overlayColor: colors.primary.withAlpha(0x29),
              valueIndicatorColor: colors.primary,
              valueIndicatorTextStyle: styles.labelMedium.copyWith(
                color: colors.onPrimary,
              ),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: AppSpacing.md,
              ),
              trackHeight: AppSpacing.xs,
              rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
              showValueIndicator: ShowValueIndicator.onlyForDiscrete,
            ),
            child: RangeSlider(
              min: min,
              max: max,
              values: values,
              divisions: divisions,
              labels: divisions != null
                  ? RangeLabels(
                      _format(values.start),
                      _format(values.end),
                    )
                  : null,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
