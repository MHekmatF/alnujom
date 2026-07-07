// Phase 23 (spec/023-app-settings) — T016
// SettingsSectionHeader: a simple titled divider used to group settings rows
// on the AppSettingsEditorPage.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../../core/theme/colors.dart';
import '../../../../../../core/theme/spacing.dart';
import '../../../../../../core/theme/typography.dart';

/// Renders a bold section title with a bottom divider for the settings editor.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: styles.titleMedium.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Divider(height: AppSpacing.sm, color: colors.divider),
        ],
      ),
    );
  }
}
