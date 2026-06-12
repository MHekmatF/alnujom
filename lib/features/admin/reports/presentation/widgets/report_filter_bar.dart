// Phase 18 (spec/018-reports-moderation) — T054
// ReportFilterBar: status + reason dropdowns for the admin reports queue.
// `reviewing` is selectable (FR-036). Logical insets for RTL/LTR.
// Constitution VI: design tokens only; Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../bloc/reports_queue_bloc.dart';

/// Filter-bar widget displayed above the reports queue list.
/// Emits [ReportsQueueFilterChanged] events via the provided [onStatusChanged]
/// and [onReasonChanged] callbacks (the parent page connects these to the bloc).
class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    super.key,
    required this.selectedStatus,
    required this.selectedReason,
    required this.onStatusChanged,
    required this.onReasonChanged,
  });

  final ReportStatus? selectedStatus;
  final ReportReason? selectedReason;
  final ValueChanged<ReportStatus?> onStatusChanged;
  final ValueChanged<ReportReason?> onReasonChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return Container(
      color: colors.surfaceVariant,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatusDropdown(
              label: l10n.report_filter_status_label,
              value: selectedStatus,
              onChanged: onStatusChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ReasonDropdown(
              label: l10n.report_filter_reason_label,
              value: selectedReason,
              onChanged: onReasonChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status dropdown ─────────────────────────────────────────────────────────

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final ReportStatus? value;
  final ValueChanged<ReportStatus?> onChanged;

  String _statusLabel(AppLocalizations l10n, ReportStatus s) {
    switch (s) {
      case ReportStatus.newReport:
        return l10n.report_status_new;
      case ReportStatus.reviewing:
        return l10n.report_status_reviewing;
      case ReportStatus.resolved:
        return l10n.report_status_resolved;
      case ReportStatus.dismissed:
        return l10n.report_status_dismissed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DropdownButtonFormField<ReportStatus?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      items: [
        DropdownMenuItem<ReportStatus?>(
          value: null,
          child: Text(
            l10n.report_filter_any_dash,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // All statuses including `reviewing` are selectable (FR-036).
        for (final s in ReportStatus.values)
          DropdownMenuItem<ReportStatus?>(
            value: s,
            child: Text(_statusLabel(l10n, s), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

// ─── Reason dropdown ─────────────────────────────────────────────────────────

class _ReasonDropdown extends StatelessWidget {
  const _ReasonDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final ReportReason? value;
  final ValueChanged<ReportReason?> onChanged;

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
    return DropdownButtonFormField<ReportReason?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      items: [
        DropdownMenuItem<ReportReason?>(
          value: null,
          child: Text(
            l10n.report_filter_any_dash,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final r in ReportReason.values)
          DropdownMenuItem<ReportReason?>(
            value: r,
            child: Text(_reasonLabel(l10n, r), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
