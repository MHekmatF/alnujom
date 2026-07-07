// lib/features/reports/presentation/widgets/report_status_chip.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T043).
// Canonical localized ReportStatus pill. Phase 9 reuses this widget.
// Phase 33 — restyled to the royal-blue design system: a soft-tinted status
// pill (token color at low alpha background + the same token as foreground)
// using AppColors / AppTextStyles / AppSpacing / appRadius only.
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/report_status.dart';

/// A small status chip that visualises a [ReportStatus] using token colors.
///
/// Phase 33 DS mapping (soft-tinted pill — tinted background + token ink):
///   newReport   → primary (the active/just-filed state)
///   reviewing   → warning (admin is looking at it)
///   resolved    → success (closed favourably)
///   dismissed   → muted (closed, no action)
class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip(this.status, {super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final label = switch (status) {
      ReportStatus.newReport => l10n.report_status_new,
      ReportStatus.reviewing => l10n.report_status_reviewing,
      ReportStatus.resolved => l10n.report_status_resolved,
      ReportStatus.dismissed => l10n.report_status_dismissed,
    };

    final tint = switch (status) {
      ReportStatus.newReport => colors.primary,
      ReportStatus.reviewing => colors.warning,
      ReportStatus.resolved => colors.success,
      ReportStatus.dismissed => colors.textMuted,
    };

    // The muted 'dismissed' tint is the lowest-contrast state; lift its ink to
    // onSurfaceVariant so the label stays legible (AA) while the background and
    // border keep the muted look. Other states read fine using the tint itself.
    final ink = status == ReportStatus.dismissed
        ? colors.onSurfaceVariant
        : tint;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(color: ink),
      ),
    );
  }
}
