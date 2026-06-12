// Phase 23 (spec/023-app-settings) — T016
// SettingsToggleRow: a labeled switch for boolean settings (maintenance_mode.on).
// Calls onSave immediately when the user flips the toggle.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../../core/theme/spacing.dart';
import '../../../../../../core/theme/typography.dart';
import '../../../../../../core/widgets/app_spinner.dart';

/// A single-row labeled toggle for a boolean setting value.
///
/// [label]     — localised label text.
/// [value]     — current boolean value.
/// [isSaving]  — disables the switch while a save is in progress.
/// [onChanged] — called with the new bool when the user flips the toggle.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.isSaving,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.of(context).bodyMedium),
          ),
          isSaving
              ? const AppSpinner()
              : Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
