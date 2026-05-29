// lib/features/reports/presentation/widgets/report_status_chip.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T043).
// Canonical localized ReportStatus pill. Phase 9 reuses this widget.
// Phase 2 tokens only; no inline hex/font-size/padding.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/report_status.dart';

/// A small status chip that visualises a [ReportStatus] using token colors.
///
/// Token mapping (Phase 2 colorScheme):
///   newReport   → secondaryContainer / onSecondaryContainer
///   reviewing   → tertiaryContainer  / onTertiaryContainer
///   resolved    → primaryContainer   / onPrimaryContainer
///   dismissed   → surfaceContainerHighest / onSurface (muted)
class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip(this.status, {super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final label = switch (status) {
      ReportStatus.newReport => l10n.report_status_new,
      ReportStatus.reviewing => l10n.report_status_reviewing,
      ReportStatus.resolved => l10n.report_status_resolved,
      ReportStatus.dismissed => l10n.report_status_dismissed,
    };

    final (background, foreground) = switch (status) {
      ReportStatus.newReport => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      ReportStatus.reviewing => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      ReportStatus.resolved => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      ReportStatus.dismissed => (
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
