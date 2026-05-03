import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '_widget_support.dart';

class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    required this.values,
    required this.labels,
    required this.groupValue,
    required this.onChanged,
    this.segmented = false,
    this.enabled = true,
    super.key,
  });

  final List<T> values;
  final List<String> labels;
  final T groupValue;
  final bool segmented;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (segmented) {
      return SegmentedButton<T>(
        segments: [
          for (var i = 0; i < values.length; i += 1)
            ButtonSegment(value: values[i], label: Text(labels[i])),
        ],
        selected: {groupValue},
        onSelectionChanged: enabled
            ? (selected) => onChanged(selected.first)
            : null,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < values.length; i += 1)
          InkWell(
            onTap: enabled ? () => onChanged(values[i]) : null,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  AppTapTarget(
                    child: Icon(
                      values[i] == groupValue
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: values[i] == groupValue
                          ? colors.primary
                          : colors.outlineStrong,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(labels[i]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
