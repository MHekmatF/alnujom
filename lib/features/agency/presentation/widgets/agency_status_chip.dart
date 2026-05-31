// lib/features/agency/presentation/widgets/agency_status_chip.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T050).
// Canonical localized AgencyStatus pill. Mirrors report_status_chip.dart.
// Phase 2 tokens only; no inline hex/font-size/padding.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency_status.dart';

/// A small status chip visualising an [AgencyStatus] using token colors.
///
/// Token mapping (Phase 2 colorScheme):
///   pending   → secondaryContainer / onSecondaryContainer
///   approved  → primaryContainer   / onPrimaryContainer
///   rejected  → errorContainer     / onErrorContainer
///   suspended → surfaceContainerHighest / onSurface (muted)
class AgencyStatusChip extends StatelessWidget {
  const AgencyStatusChip(this.status, {super.key});

  final AgencyStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final label = switch (status) {
      AgencyStatus.pending => l10n.agency_status_pending,
      AgencyStatus.approved => l10n.agency_status_approved,
      AgencyStatus.rejected => l10n.agency_status_rejected,
      AgencyStatus.suspended => l10n.agency_status_suspended,
    };

    final (background, foreground) = switch (status) {
      AgencyStatus.pending => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      AgencyStatus.approved => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      AgencyStatus.rejected => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      AgencyStatus.suspended => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
        ),
    };

    return Chip(
      label: Text(label),
      backgroundColor: background,
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
          ),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
