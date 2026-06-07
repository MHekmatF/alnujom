import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// Themed dropdown that matches [AppTextField] — it inherits the filled fill +
/// focus ring from the app's `inputDecorationTheme`, and adds the polish the
/// bare `DropdownButtonFormField` lacks: an overflow guard ([isExpanded]), a
/// themed caret, a rounded popup menu, and token text styling.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.label,
    required this.items,
    this.value,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final String? errorText;
  final bool enabled;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurfaceVariant),
      borderRadius: appRadius(AppRadii.md),
      dropdownColor: colors.card,
      style: styles.bodyLarge,
      decoration: InputDecoration(labelText: label, errorText: errorText),
    );
  }
}
