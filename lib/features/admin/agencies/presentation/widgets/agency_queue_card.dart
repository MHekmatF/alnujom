// Phase 19 (spec/019-agencies) — T065
// AgencyQueueCard: one card in the admin agency verification queue list.
// Shows agency name + owner + submitted-at + status chip.
// Mirrors ReportQueueCard (Phase 18).
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
import '../../../../agency/domain/entities/agency_status.dart';
import '../../domain/entities/agency_verification_item.dart';

class AgencyQueueCard extends StatelessWidget {
  const AgencyQueueCard({super.key, required this.item, required this.onTap});

  final AgencyVerificationItem item;
  final VoidCallback onTap;

  String _statusLabel(AppLocalizations l10n, AgencyStatus status) {
    switch (status) {
      case AgencyStatus.pending:
        return l10n.agency_status_pending;
      case AgencyStatus.approved:
        return l10n.agency_status_approved;
      case AgencyStatus.rejected:
        return l10n.agency_status_rejected;
      case AgencyStatus.suspended:
        return l10n.agency_status_suspended;
    }
  }

  Color _statusColor(AppColors colors, AgencyStatus status) {
    switch (status) {
      case AgencyStatus.pending:
        return colors.warning;
      case AgencyStatus.approved:
        return colors.success;
      case AgencyStatus.rejected:
        return colors.error;
      case AgencyStatus.suspended:
        return colors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final agency = item.agency;
    final request = item.request;

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: agency name + status chip ────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    agency.name,
                    style: styles.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _AgencyStatusChip(
                  label: _statusLabel(l10n, agency.status),
                  color: _statusColor(colors, agency.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // ── Owner display name ────────────────────────────────────────
            if (item.ownerDisplayName != null)
              Text(
                item.ownerDisplayName!,
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.sm),
            // ── Submitted-at ─────────────────────────────────────────────
            Text(
              request.submittedAt.toLocal().toString().substring(0, 16),
              style: styles.labelMedium.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mini status chip ─────────────────────────────────────────────────────────

class _AgencyStatusChip extends StatelessWidget {
  const _AgencyStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: color),
      ),
      child: Text(label, style: styles.labelMedium.copyWith(color: color)),
    );
  }
}
