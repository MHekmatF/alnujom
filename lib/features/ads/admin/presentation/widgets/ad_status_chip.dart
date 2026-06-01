// Phase 21 (spec/021-ads-banners) — T024
// AdStatusChip: renders an AdStatus badge using Phase 2 theme tokens only.
// No inline hex / font-size / hardcoded padding (design-tokens linter gate).
// Constitution IX: zero supabase_flutter imports.
import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/ad_status.dart';

/// A small chip that reflects the derived [AdStatus] of an [Ad].
///
/// Colors are sourced exclusively from the ambient [ThemeData] (Phase 2 tokens).
/// No inline hex codes.
class AdStatusChip extends StatelessWidget {
  const AdStatusChip(this.status, {super.key});

  final AdStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (label, background, foreground) = switch (status) {
      AdStatus.active => (
          l10n.adStatusActive,
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      AdStatus.scheduled => (
          l10n.adStatusScheduled,
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
      AdStatus.expired => (
          l10n.adStatusExpired,
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
        ),
      AdStatus.inactive => (
          l10n.adStatusInactive,
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
      AdStatus.archived => (
          l10n.adStatusArchived,
          colorScheme.surfaceContainerHighest,
          colorScheme.outline,
        ),
    };

    return Chip(
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
      backgroundColor: background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
