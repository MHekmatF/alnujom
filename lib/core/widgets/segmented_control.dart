import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/motion.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// One option in an [AppSegmentedControl]: an icon + label paired with the
/// [value] this segment selects when tapped.
///
/// Generic over [T] so the control can drive any value type (an enum, a string
/// key, etc.). Display strings are caller-localized — this widget adds no l10n.
@immutable
class AppSegmentedSegment<T> {
  const AppSegmentedSegment({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final T value;
}

/// Phase 25 uplift — an icon+label segmented toggle (e.g. List | Map).
///
/// A pill container ([AppColors.surfaceVariant] background) holding equal-width
/// segments. The selected segment lifts onto a [card]/[primary] fill with
/// [onPrimary] text+icon and a soft shadow; unselected segments read as
/// [textMuted]. Selection animates via [AppMotion]. RTL-safe.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<AppSegmentedSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final segment in segments)
              Expanded(
                child: _Segment<T>(
                  segment: segment,
                  selected: segment.value == value,
                  onTap: () => onChanged(segment.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final AppSegmentedSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    final foreground = selected ? colors.onPrimary : colors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: segment.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: appRadius(AppRadii.pill),
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            constraints: const BoxConstraints(minHeight: AppSpacing.xxl),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: appRadius(AppRadii.pill),
              boxShadow: selected ? elevation.level1 : elevation.level0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Icon(
                    segment.icon,
                    key: ValueKey<bool>(selected),
                    size: AppSpacing.lg,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.base,
                    curve: AppMotion.curve,
                    style: styles.labelLarge.copyWith(color: foreground),
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
