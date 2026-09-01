import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';

/// A DropdownButtonFormField wrapper that renders (id, label) option pairs.
/// The caller is responsible for providing pre-localized label strings so
/// this widget stays locale-agnostic and reusable across all three cascade levels.
///
/// Batch-2 restyle: the raw `EdgeInsets.symmetric` content paddings became
/// directional, the loading state swapped its full-width
/// [LinearProgressIndicator] bar for the DS inline spinner, and the dropdown
/// itself now carries the [AppDropdown] chrome (themed caret, rounded token
/// popup, card popup surface, token text). The control type is unchanged.
class LocationPickerDropdown extends StatelessWidget {
  const LocationPickerDropdown({
    super.key,
    required this.label,
    required this.items,
    this.value,
    required this.onChanged,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final List<(String id, String displayLabel)> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    if (isLoading) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: styles.bodyMedium,
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        child: SizedBox(
          height: AppSpacing.xl,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: appInlineSpinner(context),
          ),
        ),
      );
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: styles.bodyMedium,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      isEmpty: value == null,
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurfaceVariant),
        borderRadius: appRadius(AppRadii.md),
        dropdownColor: colors.card,
        style: styles.bodyLarge,
        onChanged: enabled && items.isNotEmpty ? onChanged : null,
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.$1,
                child: Text(item.$2),
              ),
            )
            .toList(),
      ),
    );
  }
}
