import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '_widget_support.dart';

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AppTapTarget(
      child: Checkbox(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: colors.primary,
      ),
    );
  }
}
