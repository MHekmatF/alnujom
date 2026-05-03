import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'dimens.dart';

enum AppTabsVariant { segmented, underline }

class AppTabs extends StatelessWidget {
  const AppTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.variant = AppTabsVariant.segmented,
    this.enabled = true,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final AppTabsVariant variant;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (variant == AppTabsVariant.segmented) {
      return SegmentedButton<int>(
        segments: [
          for (var i = 0; i < labels.length; i += 1)
            ButtonSegment(value: i, label: Text(labels[i])),
        ],
        selected: {selectedIndex},
        onSelectionChanged: enabled
            ? (selected) => onChanged(selected.first)
            : null,
      );
    }

    return Row(
      children: [
        for (var i = 0; i < labels.length; i += 1)
          Expanded(
            child: InkWell(
              onTap: enabled ? () => onChanged(i) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                    child: Text(labels[i]),
                  ),
                  Container(
                    height: AppDimens.strokeMedium,
                    color: i == selectedIndex
                        ? colors.primary
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
