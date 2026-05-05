import 'package:flutter/material.dart';

import '../theme/colors.dart';

class AppToggle extends StatelessWidget {
  const AppToggle({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Switch(
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: colors.primary,
      activeTrackColor: colors.primaryContainer,
    );
  }
}
