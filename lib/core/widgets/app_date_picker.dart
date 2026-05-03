import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_text_field.dart';

class AppDatePicker extends StatelessWidget {
  const AppDatePicker({
    required this.label,
    this.value,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime>? onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return GestureDetector(
      onTap: enabled
          ? () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 100),
                lastDate: DateTime(now.year + 100),
                initialDate: value ?? now,
              );
              if (selected != null) onChanged?.call(selected);
            }
          : null,
      child: AbsorbPointer(
        child: AppTextField(
          label: label,
          enabled: enabled,
          initialValue: value == null
              ? ''
              : DateFormat.yMd(locale).format(value!),
        ),
      ),
    );
  }
}
