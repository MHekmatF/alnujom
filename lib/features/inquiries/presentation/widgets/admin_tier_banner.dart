// lib/features/inquiries/presentation/widgets/admin_tier_banner.dart
//
// Phase 16 Sub-Phase F (T068) — Banner rendered at the top of the admin
// inquiry oversight page to visually distinguish it from the publisher inbox.
import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

class AdminTierBanner extends StatelessWidget {
  const AdminTierBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: AppSpacing.lg,
              color: colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.admin_inquiries_tier_banner,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
