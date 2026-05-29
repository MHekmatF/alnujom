// Phase 18 (spec/018-reports-moderation) — T055
// ReportQueueCard: one card in the admin reports queue list.
// Shows listing title/location, report reason + status chip, reporter user-id
// (admin-visible), and optional note.
//
// Note: Phase 8 (concurrent wave-mate) owns the canonical
// `lib/features/reports/presentation/widgets/report_status_chip.dart`.
// Until Phase 8 is merged, a local `_ReportStatusChip` pill is included here.
// The orchestrator re-runs build_runner after merge.
//
// Constitution IX: zero Supabase imports.
// Constitution VI: design tokens only; no inline hex/font/padding.
import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../../domain/entities/report_queue_item.dart';

class ReportQueueCard extends StatelessWidget {
  const ReportQueueCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final ReportQueueItem item;
  final VoidCallback onTap;

  String _reasonLabel(AppLocalizations l10n, ReportReason r) {
    switch (r) {
      case ReportReason.fakeListing:
        return l10n.report_reason_fake_listing;
      case ReportReason.wrongPrice:
        return l10n.report_reason_wrong_price;
      case ReportReason.alreadySoldOrRented:
        return l10n.report_reason_already_sold_or_rented;
      case ReportReason.duplicate:
        return l10n.report_reason_duplicate;
      case ReportReason.spam:
        return l10n.report_reason_spam;
      case ReportReason.wrongLocation:
        return l10n.report_reason_wrong_location;
      case ReportReason.inappropriateContent:
        return l10n.report_reason_inappropriate_content;
      case ReportReason.other:
        return l10n.report_reason_other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final locationParts = [
      if (item.governorateNameAr != null || item.governorateNameEn != null)
        Localizations.localeOf(context).languageCode == 'ar'
            ? item.governorateNameAr
            : item.governorateNameEn,
      if (item.cityNameAr != null || item.cityNameEn != null)
        Localizations.localeOf(context).languageCode == 'ar'
            ? item.cityNameAr
            : item.cityNameEn,
    ].whereType<String>().join(' / ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: listing title + status chip ──────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.listingTitle.isEmpty ? '—' : item.listingTitle,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ReportStatusChip(status: item.status),
                ],
              ),
              if (locationParts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  locationParts,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              // ── Reason chip ───────────────────────────────────────────────
              _MiniChip(label: _reasonLabel(l10n, item.reason)),
              if (item.note != null && item.note!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              // ── Reporter ID (admin-visible) + reviewer soft-lock notice ──
              Text(
                'Reporter: ${item.reporterUserId}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.reviewingBy != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.report_being_reviewed_by(item.reviewingBy!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Local status chip (Phase 8 ships the canonical version) ─────────────────

/// Minimal status pill used by [ReportQueueCard] and [ReportDetailPage] until
/// Phase 8's `report_status_chip.dart` is merged. The orchestrator will
/// replace this with the canonical import after the Wave 4 merge.
class _ReportStatusChip extends StatelessWidget {
  const _ReportStatusChip({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final (label, bg, fg) = switch (status) {
      ReportStatus.newReport => (
          l10n.report_status_new,
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      ReportStatus.reviewing => (
          l10n.report_status_reviewing,
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        ),
      ReportStatus.resolved => (
          l10n.report_status_resolved,
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      ReportStatus.dismissed => (
          l10n.report_status_dismissed,
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

// ─── Mini chip (reason label) ─────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
