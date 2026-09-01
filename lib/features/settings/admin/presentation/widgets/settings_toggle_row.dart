// Phase 23 (spec/023-app-settings) — T016
// SettingsToggleRow: a labeled switch for boolean settings (maintenance_mode.on).
// Calls onSave immediately when the user flips the toggle.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../../core/theme/spacing.dart';
import '../../../../../../core/theme/typography.dart';
import '../../../../../../core/widgets/_widget_support.dart';
import '../../../../../../core/widgets/app_toggle.dart';

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
    // Batch-2: the label used `bodyMedium` (the DS *secondary* body token) even
    // though it is the row's primary copy — bumped to `bodyLarge`; the whole row
    // is now a 48dp-minimum, merged-Semantics toggle target.
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
      child: MergeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kAppMinTouchTarget),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: AppTextStyles.of(context).bodyLarge),
              ),
              isSaving
                  ? appInlineSpinner(context)
                  : AppToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
