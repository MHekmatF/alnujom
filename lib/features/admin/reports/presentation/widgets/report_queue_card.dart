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

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/press_scale.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/presentation/widgets/report_status_chip.dart';
import '../../domain/entities/report_queue_item.dart';

class ReportQueueCard extends StatelessWidget {
  const ReportQueueCard({super.key, required this.item, required this.onTap});

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
      case ReportReason.harassment:
        return l10n.report_reason_harassment;
      case ReportReason.scam:
        return l10n.report_reason_scam;
      case ReportReason.impersonation:
        return l10n.report_reason_impersonation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

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

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: listing title + status chip ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.displayTitle.isEmpty ? '—' : item.displayTitle,
                    style: styles.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ReportStatusChip(item.status),
              ],
            ),
            if (locationParts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                locationParts,
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
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
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            // ── Reporter ID (admin-visible) + reviewer soft-lock notice ──
            Text(
              l10n.admin_report_reporter_with_id(item.reporterUserId),
              style: styles.labelMedium.copyWith(color: colors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.reviewingBy != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.report_being_reviewed_by(item.reviewingBy!),
                style: styles.labelMedium.copyWith(color: colors.primary),
              ),
            ],
          ],
        ),
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(color: colors.primary),
      ),
    );
  }
}
