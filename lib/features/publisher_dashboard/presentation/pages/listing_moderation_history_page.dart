import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/listing/rejection_reason.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
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
            ModerationHistoryInitial() || ModerationHistoryLoading() =>
              const Center(child: CircularProgressIndicator()),
            ModerationHistoryLoaded(:final entries) when entries.isEmpty =>
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.publisherHistoryEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ModerationHistoryLoaded(:final entries) => ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _HistoryEntryCard(entry: entries[index], l10n: l10n),
            ),
            ModerationHistoryError() => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.adminErrorUnknown,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context
                          .read<ModerationHistoryCubit>()
                          .load(listingId),
                      child: Text(l10n.errorRetryAction),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDetail =
        entry.rejectionDetail != null &&
        entry.rejectionDetail!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status arc: Previous → New
            Row(
              children: [
                if (entry.previousStatus == null)
                  _StatusPill(
                    label: l10n.publisherHistoryFirstEntry,
                    scheme: scheme,
                    theme: theme,
                  )
                else ...[
                  _StatusPill(
                    label: _statusLabel(entry.previousStatus!),
                    scheme: scheme,
                    theme: theme,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                _StatusPill(
                  label: _statusLabel(entry.newStatus),
                  scheme: scheme,
                  theme: theme,
                  isNew: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Timestamp + admin attribution (NEVER the admin's actual name).
            Text(
              '${_formatTimestamp(entry.changedAt)} • ${l10n.publisherHistoryAdminTeam}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            // Rejection preset + detail block.
            if (entry.hasRejection) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _presetLabel(entry.rejectionPreset!),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
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
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    entry.rejectionDetail!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
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
  const _StatusPill({
    required this.label,
    required this.scheme,
    required this.theme,
    this.isNew = false,
  });

  final String label;
  final ColorScheme scheme;
  final ThemeData theme;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isNew ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isNew ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
