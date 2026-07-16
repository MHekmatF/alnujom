import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/listing/rejection_reason.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../core/widgets/ds/dc_timeline.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/moderation_history_entry.dart';
import '../bloc/moderation_history_cubit.dart';
import '../bloc/moderation_history_state.dart';

/// Phase 12 / US6 — Read-only publisher-facing moderation history page,
/// restyled to the DC "Blue Crown" system (`AlNujom - Publisher.dc.html`
/// «سجل المراجعة») as a connected [DcModerationTimeline].
///
/// Admin identity is NEVER displayed — every entry attributes to "Admin team"
/// via [AppLocalizations.publisherHistoryAdminTeam]. Owner-only access is
/// enforced server-side by Phase 10's RLS on `public.listing_status_history`.
class ListingModerationHistoryPage extends StatelessWidget {
  const ListingModerationHistoryPage({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ModerationHistoryCubit>(
      create: (_) => getIt<ModerationHistoryCubit>()..load(listingId),
      child: _ModerationHistoryView(listingId: listingId),
    );
  }
}

class _ModerationHistoryView extends StatelessWidget {
  const _ModerationHistoryView({required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.publisherHistoryTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: BlocBuilder<ModerationHistoryCubit, ModerationHistoryState>(
        builder: (context, state) {
          return switch (state) {
            ModerationHistoryInitial() ||
            ModerationHistoryLoading() => Center(
              child: appInlineSpinner(context),
            ),
            ModerationHistoryLoaded(:final entries) when entries.isEmpty =>
              _CenteredMessage(message: l10n.publisherHistoryEmpty),
            ModerationHistoryLoaded(:final entries) => SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: DcModerationTimeline(
                nodes: [
                  for (final e in entries) _nodeFor(e, l10n),
                ],
              ),
            ),
            ModerationHistoryError() => _ErrorBody(listingId: listingId),
          };
        },
      ),
    );
  }

  DcTimelineNode _nodeFor(ModerationHistoryEntry entry, AppLocalizations l10n) {
    return DcTimelineNode(
      icon: _iconFor(entry.newStatus),
      tone: _toneFor(entry.newStatus),
      title: _statusLabel(entry.newStatus, l10n),
      time: '${_formatTimestamp(entry.changedAt)} · '
          '${l10n.publisherHistoryAdminTeam}',
      body: entry.hasRejection ? _rejectionBody(entry, l10n) : null,
    );
  }

  DcStatusTone _toneFor(ListingStatus status) {
    switch (status) {
      case ListingStatus.approved:
        return DcStatusTone.green;
      case ListingStatus.rejected:
        return DcStatusTone.red;
      case ListingStatus.draft:
      case ListingStatus.pendingReview:
      case ListingStatus.paused:
      case ListingStatus.sold:
      case ListingStatus.rented:
      case ListingStatus.expired:
      case ListingStatus.deleted:
        return DcStatusTone.neutral;
    }
  }

  IconData _iconFor(ListingStatus status) {
    switch (status) {
      case ListingStatus.approved:
        return Icons.check_circle;
      case ListingStatus.rejected:
        return Icons.cancel;
      case ListingStatus.pendingReview:
        return Icons.upload_file;
      case ListingStatus.draft:
        return Icons.edit_note;
      case ListingStatus.paused:
        return Icons.pause_circle_outline;
      case ListingStatus.sold:
      case ListingStatus.rented:
        return Icons.task_alt;
      case ListingStatus.expired:
        return Icons.history;
      case ListingStatus.deleted:
        return Icons.delete_outline;
    }
  }

  String _rejectionBody(ModerationHistoryEntry entry, AppLocalizations l10n) {
    final preset = _presetLabel(entry.rejectionPreset!, l10n);
    final detail = entry.rejectionDetail?.trim();
    if (detail == null || detail.isEmpty) return preset;
    return '$preset\n$detail';
  }

  String _statusLabel(ListingStatus status, AppLocalizations l10n) {
    switch (status) {
      case ListingStatus.draft:
        return l10n.publisherHistoryStatusDraft;
      case ListingStatus.pendingReview:
        return l10n.publisherHistoryStatusPendingReview;
      case ListingStatus.approved:
        return l10n.publisherHistoryStatusApproved;
      case ListingStatus.rejected:
        return l10n.publisherHistoryStatusRejected;
      case ListingStatus.paused:
        return l10n.publisherHistoryStatusPaused;
      case ListingStatus.sold:
        return l10n.publisherHistoryStatusSold;
      case ListingStatus.rented:
        return l10n.publisherHistoryStatusRented;
      case ListingStatus.expired:
        return l10n.publisherHistoryStatusExpired;
      case ListingStatus.deleted:
        return l10n.publisherHistoryStatusDeleted;
    }
  }

  String _presetLabel(RejectionReason preset, AppLocalizations l10n) {
    switch (preset) {
      case RejectionReason.missingOrLowQualityPhotos:
        return l10n.rejectPresetMissingOrLowQualityPhotos;
      case RejectionReason.incorrectLocation:
        return l10n.rejectPresetIncorrectLocation;
      case RejectionReason.unrealisticPrice:
        return l10n.rejectPresetUnrealisticPrice;
      case RejectionReason.incompleteDescription:
        return l10n.rejectPresetIncompleteDescription;
      case RejectionReason.duplicateListing:
        return l10n.rejectPresetDuplicateListing;
      case RejectionReason.other:
        return l10n.rejectPresetOther;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.of(context).bodyLarge.copyWith(
            color: AppColors.of(context).textMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.adminErrorUnknown,
              textAlign: TextAlign.center,
              style: AppTextStyles.of(context).bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.errorRetryAction,
              variant: AppButtonVariant.outlined,
              onPressed: () =>
                  context.read<ModerationHistoryCubit>().load(listingId),
            ),
          ],
        ),
      ),
    );
  }
}
