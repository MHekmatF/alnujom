import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/listing/rejection_reason.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 12 / US2 — Rejection-reason banner shown above each Rejected card
/// on `MyListingsPage`'s Rejected filter (extends Phase 10 in place).
///
/// Contract: `contracts/phase12-publisher-rejection-banner.md`.
///
/// FR-015 + Constitution VIII privacy: the banner displays "Admin team" via
/// ARB key `publisherRejectionAttribution`; it NEVER displays the admin's
/// actual name or UID. The data source query intentionally omits
/// `changed_by` from the SELECT.
///
/// Phase 12 uses the Material 3 `errorContainer` / `onErrorContainer`
/// tokens (Phase 2 design system); a future danger-container token rename
/// can swap these in one place.
class RejectionReasonBanner extends StatelessWidget {
  const RejectionReasonBanner({
    super.key,
    required this.listingId,
    required this.preset,
    required this.rejectedAt,
    this.detail,
  });

  final String listingId;
  final RejectionReason preset;
  final DateTime rejectedAt;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDetail = detail != null && detail!.trim().isNotEmpty;
    final timeAgo = _formatTimeAgo(l10n, rejectedAt);
    final presetLabel = _presetLabel(l10n, preset);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attribution line — admin identity NEVER exposed.
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.publisherRejectionAttribution(timeAgo),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Preset label.
          Text(
            presetLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Quoted detail block — defensive: omitted when detail is empty.
          if (hasDetail) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md,
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: scheme.onErrorContainer.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                detail!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // CTAs row.
          Row(
            children: [
              FilledButton.tonal(
                onPressed: () =>
                    context.push('/publisher/listings/$listingId/edit'),
                child: Text(l10n.publisherRejectionResubmit),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => context.push(
                  '/publisher/listings/$listingId/moderation-history',
                ),
                child: Text(l10n.publisherRejectionViewHistory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _presetLabel(AppLocalizations l10n, RejectionReason preset) {
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

  /// Compact localized time-ago string. Phase 12's first listing-domain
  /// time-ago formatter (mirrors Phase 3's queue-card pattern using the
  /// admin-side `adminQueueSubmittedAt*` keys; the publisher-side reuses
  /// those keys verbatim since the formatter shape is identical).
  String _formatTimeAgo(AppLocalizations l10n, DateTime when) {
    final delta = DateTime.now().difference(when);
    if (delta.inMinutes < 1) return l10n.adminQueueSubmittedAtJustNow;
    if (delta.inHours < 1) {
      return l10n.adminQueueSubmittedAtMinutes(delta.inMinutes);
    }
    if (delta.inDays < 1) {
      return l10n.adminQueueSubmittedAtHours(delta.inHours);
    }
    return l10n.adminQueueSubmittedAtDays(delta.inDays);
  }
}
