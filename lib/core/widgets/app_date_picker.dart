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
              final firstDate = DateTime(now.year - 100, 1, 1);
              final lastDate = DateTime(now.year + 100, 12, 31);
              final candidate = value ?? now;
              final initialDate = switch (candidate) {
                final v when v.isBefore(firstDate) => firstDate,
                final v when v.isAfter(lastDate) => lastDate,
                final v => v,
              };
              final selected = await showDatePicker(
                context: context,
                firstDate: firstDate,
                lastDate: lastDate,
                initialDate: initialDate,
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
