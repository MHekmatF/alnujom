import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

class StepperIndicator extends StatelessWidget {
  const StepperIndicator({
    required this.steps,
    required this.currentIndex,
    super.key,
  });

  final int steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps; i += 1)
          Expanded(
            child: Container(
              margin: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              height: AppSpacing.sm,
              decoration: BoxDecoration(
                color: i < currentIndex
                    ? colors.success
                    : i == currentIndex
                    ? colors.primary
                    : colors.outline,
                borderRadius: appRadius(AppRadii.pill),
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Text('(${currentIndex + 1}/$steps)', style: styles.labelMedium),
      ],
    );
  }
}
