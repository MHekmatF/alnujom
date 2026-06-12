import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/press_scale.dart';
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: () =>
            context.push('/admin/listing-review/preview/${summary.id}'),
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
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
                    style: styles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _MiniChip(label: _purposeLabel(l10n, summary.purpose)),
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
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
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
                      style: styles.labelLarge.copyWith(color: colors.primary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${l10n.adminQueuePublisherPrefix} '
                    '${summary.publisherDisplayName} • '
                    '${_timeAgo(l10n, summary.submittedAt)}',
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
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

  static const double _side = AppSpacing.xxxl + AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final placeholder = Container(
      width: _side,
      height: _side,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.sm),
      ),
      alignment: AlignmentDirectional.center,
      child: Icon(LucideIcons.house, color: colors.textMuted),
    );
    if (url == null) return placeholder;
    return ClipRRect(
      borderRadius: appRadius(AppRadii.sm),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: _side,
        height: _side,
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
