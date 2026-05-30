// lib/features/reports/presentation/widgets/my_reports_empty_state.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T044).
// Localized empty-state for MyReportsPage.
// Phase 2 tokens only; no inline hex/font-size/padding.
import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Centered illustration + localized message shown when the user has no
/// submitted reports (FR-022 / SC-012 analog).
class MyReportsEmptyState extends StatelessWidget {
  const MyReportsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              size: AppSpacing.xxxl * 2,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.reports_my_empty_state,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
