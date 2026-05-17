import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';

/// A DropdownButtonFormField wrapper that renders (id, label) option pairs.
/// The caller is responsible for providing pre-localized label strings so
/// this widget stays locale-agnostic and reusable across all three cascade levels.
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
    if (isLoading) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        child: const SizedBox(height: 24, child: LinearProgressIndicator()),
      );
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        border: const OutlineInputBorder(),
      ),
      isEmpty: value == null,
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
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
