// Phase 23 (spec/023-app-settings) — T016
// SettingsSectionHeader: a simple titled divider used to group settings rows
// on the AppSettingsEditorPage.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../../core/theme/spacing.dart';

/// Renders a bold section title with a bottom divider for the settings editor.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
