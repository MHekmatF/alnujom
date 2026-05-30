// lib/features/reports/presentation/widgets/reporter_status_banner.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T048).
// Renders l10n.report_banner_status + ReportStatusChip when a report exists;
// renders nothing for non-reporters / anon / error. FR-023. Phase 2 tokens.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/report_status.dart';
import '../cubit/listing_report_status_cubit.dart';
import 'report_status_chip.dart';

/// Hosts its own [ListingReportStatusCubit] and loads the reporter's status
/// for [listingId].  Callers simply embed it at the desired position in the
/// listing-details body — no BlocProvider wrapping needed.
///
/// Renders nothing when:
///   - The user is not authenticated (null report from RLS self-filter).
///   - The user has no report for this listing.
///   - The cubit is loading or errored.
class ReporterStatusBanner extends StatelessWidget {
  const ReporterStatusBanner({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ListingReportStatusCubit>(
      create: (_) =>
          getIt<ListingReportStatusCubit>()..load(listingId),
      child: const _BannerBody(),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListingReportStatusCubit, ListingReportStatusState>(
      builder: (context, state) {
        if (state is! ListingReportStatusLoaded) return const SizedBox.shrink();
        final report = state.report;
        if (report == null) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Container(
          width: double.infinity,
          margin: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                size: AppSpacing.lg,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.report_banner_status(_statusLabel(l10n, report.status)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ReportStatusChip(report.status),
            ],
          ),
        );
      },
    );
  }
}

String _statusLabel(AppLocalizations l10n, ReportStatus status) {
  return switch (status) {
    ReportStatus.newReport => l10n.report_status_new,
    ReportStatus.reviewing => l10n.report_status_reviewing,
    ReportStatus.resolved => l10n.report_status_resolved,
    ReportStatus.dismissed => l10n.report_status_dismissed,
  };
}
