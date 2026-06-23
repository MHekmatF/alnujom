import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/listing/rejection_reason.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/moderation_history_entry.dart';
import '../bloc/moderation_history_cubit.dart';
import '../bloc/moderation_history_state.dart';

/// Phase 12 / US6 — Read-only publisher-facing moderation history page.
///
/// Contract: `contracts/phase12-moderation-history-page.md`.
///
/// Shows a chronological list of status-transition entries for a single
/// listing. Admin identity is NEVER displayed — every entry attributes to
/// "Admin team" via [AppLocalizations.publisherHistoryAdminTeam].
///
/// Owner-only access is enforced server-side by Phase 10's RLS on
/// `public.listing_status_history` (`publisher_user_id = auth.uid()`).
/// No extra frontend gate is needed beyond the login redirect in the route.
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.publisherHistoryTitle)),
      body: BlocBuilder<ModerationHistoryCubit, ModerationHistoryState>(
        builder: (context, state) {
          return switch (state) {
            ModerationHistoryInitial() ||
            ModerationHistoryLoading() => const AppSpinner.page(),
            ModerationHistoryLoaded(:final entries) when entries.isEmpty =>
              Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                  child: Text(
                    l10n.publisherHistoryEmpty,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(context).bodyLarge,
                  ),
                ),
              ),
            ModerationHistoryLoaded(:final entries) => ListView.builder(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _HistoryEntryCard(entry: entries[index], l10n: l10n),
            ),
            ModerationHistoryError() => Center(
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
                      onPressed: () => context
                          .read<ModerationHistoryCubit>()
                          .load(listingId),
                    ),
                  ],
                ),
              ),
            ),
          };
        },
      ),
    );
  }
}

/// A single history entry card showing the status arc + attribution.
class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry, required this.l10n});

  final ModerationHistoryEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final hasDetail =
        entry.rejectionDetail != null &&
        entry.rejectionDetail!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status arc: Previous → New
          Row(
            children: [
              if (entry.previousStatus == null)
                _StatusPill(label: l10n.publisherHistoryFirstEntry)
              else ...[
                _StatusPill(label: _statusLabel(entry.previousStatus!)),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Icon(
                    LucideIcons.move_right,
                    size: AppSpacing.lg,
                    color: colors.textMuted,
                  ),
                ),
              ],
              _StatusPill(label: _statusLabel(entry.newStatus), isNew: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Timestamp + admin attribution (NEVER the admin's actual name).
          Text(
            '${_formatTimestamp(entry.changedAt)} • ${l10n.publisherHistoryAdminTeam}',
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
          // Rejection preset + detail block.
          if (entry.hasRejection) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _presetLabel(entry.rejectionPreset!),
              style: styles.titleMedium.copyWith(color: colors.onSurface),
            ),
            if (hasDetail) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.md,
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: colors.textMuted.withValues(alpha: 0.5),
                      width: AppSpacing.xxs,
                    ),
                  ),
                ),
                child: Text(
                  entry.rejectionDetail!,
                  style: styles.bodyMedium.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Localized status label for the arc rendering.
  String _statusLabel(ListingStatus status) {
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

  /// Localized rejection preset label — reuses Phase 4 [rejectPreset*] keys.
  String _presetLabel(RejectionReason preset) {
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

  /// Compact ISO-like timestamp for display (e.g. "2026-04-16 11:00").
  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }
}

/// Small status label chip for the arc row.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.isNew = false});

  final String label;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    // The resulting (new) status reads as the active brand state; the previous
    // status is a neutral, muted soft-tint.
    final tint = isNew ? colors.primary : colors.textMuted;
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
        style: styles.labelMedium.copyWith(color: tint),
      ),
    );
  }
}
