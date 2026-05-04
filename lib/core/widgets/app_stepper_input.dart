import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_button.dart';

class AppStepperInput extends StatelessWidget {
  const AppStepperInput({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.enabled = true,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton.iconButton(
          icon: LucideIcons.minus,
          onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Text('$value', style: styles.bodyLarge),
        ),
        AppButton.iconButton(
          icon: LucideIcons.plus,
          onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
