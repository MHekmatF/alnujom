// Phase 23 (spec/023-app-settings) — T016
// SettingsDropdownRow: a labeled DropdownButtonFormField for enum/string pickers.
// Used for default_language, default_currency, and the two visibility defaults.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../../core/theme/spacing.dart';

/// A single-row labeled dropdown for an enum or string setting value.
///
/// [label]    — localised label text.
/// [value]    — the currently selected string value.
/// [items]    — list of (value, label) pairs to present.
/// [isSaving] — disables the dropdown while a save is in progress.
/// [onSave]   — called with the new value when the user selects an option.
class SettingsDropdownRow extends StatelessWidget {
  const SettingsDropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.isSaving,
    required this.onSave,
  });

  final String label;
  final String? value;
  final List<({String value, String label})> items;
  final bool isSaving;
  final ValueChanged<String?> onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        initialValue: value,
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
                value: e.value,
                child: Text(e.label),
              ),
            )
            .toList(),
        onChanged: isSaving ? null : onSave,
      ),
    );
  }
}
