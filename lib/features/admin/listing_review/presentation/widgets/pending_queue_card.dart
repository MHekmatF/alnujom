import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/presentation/money_formatter.dart';
import '../../../../currencies/domain/entities/currency.dart';
import '../../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/pending_listing_summary.dart';

/// Phase 12 — one card on `PendingQueuePage`.
/// Composition per `contracts/phase12-admin-queue-page.md` §Card composition.
///
/// Constitution IX-clean: zero Supabase imports. The thumbnail URL was
/// pre-resolved in the datasource so this widget only needs the URL string.
class PendingQueueCard extends StatelessWidget {
  const PendingQueueCard({
    super.key,
    required this.summary,
    this.displayCurrency,
  });

  final PendingListingSummary summary;

  /// Phase 12 ships without per-card currency conversion. If the caller
  /// resolved a `Currency` for the listing's `primaryPrice.currencyCode`,
  /// the price line renders via Phase 9 `MoneyFormatter`; otherwise the
  /// price line is hidden defensively (Phase 14 will resolve currencies
  /// upfront for the search-results page).
  final Currency? displayCurrency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push('/admin/listing-review/preview/${summary.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: summary.mainImageUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.title.isEmpty ? '—' : summary.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MiniChip(
                          label: _purposeLabel(l10n, summary.purpose),
                        ),
                        _MiniChip(
                          label: _propertyTypeLabel(l10n, summary.propertyType),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${summary.governorateName} / '
                      '${summary.cityName} / '
                      '${summary.areaName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (summary.primaryPrice != null &&
                        displayCurrency != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        MoneyFormatter.format(
                          summary.primaryPrice!,
                          locale: locale,
                          currency: displayCurrency!,
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.adminQueuePublisherPrefix} '
                      '${summary.publisherDisplayName} • '
                      '${_timeAgo(l10n, summary.submittedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _purposeLabel(AppLocalizations l10n, ListingPurpose p) {
    // Phase 12 ships without per-purpose ARB labels (Phase 10 form uses
    // shared listing_enum_labels.dart); fall back to the enum's name so the
    // chip stays readable. A future spec may add the bilingual chip catalog.
    return p.name;
  }

  String _propertyTypeLabel(AppLocalizations l10n, PropertyType t) {
    return t.name;
  }

  String _timeAgo(AppLocalizations l10n, DateTime ts) {
    final diff = DateTime.now().toUtc().difference(ts.toUtc());
    if (diff.inMinutes < 1) return l10n.adminQueueSubmittedAtJustNow;
    if (diff.inMinutes < 60) {
      return l10n.adminQueueSubmittedAtMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.adminQueueSubmittedAtHours(diff.inHours);
    }
    return l10n.adminQueueSubmittedAtDays(diff.inDays);
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.home_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (url == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
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
