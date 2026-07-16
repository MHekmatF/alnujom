import 'package:flutter/material.dart';

import '../../shared/util/arabic_digits.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Token-only star-rating widget with two modes:
///
///  * [RatingStars] — read-only display of a fractional [value] (0..5) as
///    full / half / empty stars, with an optional numeric value beside them.
///  * [RatingStars.input] — an interactive 1..5 selector that calls [onChanged]
///    when a star is tapped.
///
/// Tone: filled stars use the warning/amber token; empty stars use the muted
/// outline tone. RTL-safe (stars laid out in a [Row] which mirrors naturally).
class RatingStars extends StatelessWidget {
  /// Read-only display.
  const RatingStars({
    required this.value,
    this.size,
    this.showValue = false,
    super.key,
  }) : onChanged = null,
       _interactive = false;

  /// Interactive 1..5 selector. [value] is the current selection (0 = none).
  const RatingStars.input({
    required this.value,
    required ValueChanged<int> this.onChanged,
    this.size,
    super.key,
  }) : showValue = false,
       _interactive = true;

  /// Current rating (0..5). For [RatingStars.input] only whole stars matter.
  final double value;

  /// Star glyph size. Defaults to [AppSpacing.lg] (display) / [AppSpacing.xxl]
  /// (input) when null.
  final double? size;

  /// When true (display mode only) renders the numeric value beside the stars.
  final bool showValue;

  /// Tap callback for [RatingStars.input]; null in display mode.
  final ValueChanged<int>? onChanged;

  final bool _interactive;

  static const int _starCount = 5;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final glyphSize =
        size ?? (_interactive ? AppSpacing.xxl : AppSpacing.lg);
    final filledColor = colors.warning;
    final emptyColor = colors.outlineStrong;

    final stars = List<Widget>.generate(_starCount, (i) {
      final star = _interactive
          ? _starForInput(i, glyphSize, filledColor, emptyColor)
          : _starForDisplay(i, glyphSize, filledColor, emptyColor);

      if (!_interactive) return star;

      // Interactive star — wrap each in a tappable, accessible target.
      return Semantics(
        button: true,
        label: '${i + 1}',
        child: InkResponse(
          radius: glyphSize,
          onTap: () => onChanged!(i + 1),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xxs,
            ),
            child: star,
          ),
        ),
      );
    });

    final row = Row(mainAxisSize: MainAxisSize.min, children: stars);

    if (!showValue) return row;

    // Fixed one-decimal rating ("4.0"), post-processed to Arabic-Indic digits
    // under `ar` so the value matches the locale's digit system.
    final raw = value.toStringAsFixed(1);
    final ratingLabel =
        Localizations.localeOf(context).languageCode == 'ar'
        ? toArabicIndicNumerals(raw)
        : raw;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const SizedBox(width: AppSpacing.xs),
        Text(
          ratingLabel,
          style: styles.labelLarge.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }

  Widget _starForDisplay(
    int index,
    double glyphSize,
    Color filled,
    Color empty,
  ) {
    // Threshold: full if value >= index+1, half if value >= index+0.5.
    final position = index + 1;
    if (value >= position) {
      return Icon(Icons.star_rounded, size: glyphSize, color: filled);
    }
    if (value >= position - 0.5) {
      return Icon(Icons.star_half_rounded, size: glyphSize, color: filled);
    }
    return Icon(Icons.star_outline_rounded, size: glyphSize, color: empty);
  }

  Widget _starForInput(
    int index,
    double glyphSize,
    Color filled,
    Color empty,
  ) {
    final selected = value >= index + 1;
    return Icon(
      selected ? Icons.star_rounded : Icons.star_outline_rounded,
      size: glyphSize,
      color: selected ? filled : empty,
    );
  }
}
