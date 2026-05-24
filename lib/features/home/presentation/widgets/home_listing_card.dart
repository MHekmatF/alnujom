import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/home_listing_card.dart';

/// Phase 13 — one card on HomePage feed per FR-017 + R-65 (Phase-13-
/// specific; not reusing Phase 2's generic `ListingCard`).
///
/// Layout (top-to-bottom):
/// - 16:9 hero image via [CachedNetworkImage] against the Phase 11
///   `listing-images` Storage bucket. Defensive: zero-image listings render
///   the Phase 2 placeholder (FR-031).
/// - Title (max 2 lines + ellipsis).
/// - Type + purpose badges.
/// - Governorate / city joined per Phase 8 conventions.
/// - Primary price via [MoneyFormatter] in the user's display currency.
/// - Time-since-publish (Phase 3 `intl` dependency consumed for the first
///   time per R-67).
///
/// Tap → `context.go('/listings/${card.id}')`. The route is added by Phase
/// 13 Sub-Phase F (`app_router.dart` rewire); the path string is forward-
/// stated here per R-69.
///
/// The image URL is pre-resolved by [SupabaseHomeFeedDatasource] via
/// `getPublicUrl()` so this widget remains Constitution IX-clean (no
/// supabase_flutter import per FR-030 + SC-013).
class HomeListingCardTile extends StatelessWidget {
  const HomeListingCardTile({
    super.key,
    required this.card,
    required this.currenciesByCode,
    required this.displayCurrencyCode,
  });

  final HomeListingCard card;

  /// Phase 9 currency catalog keyed by ISO code. Provided by the page-level
  /// FutureBuilder so the card can resolve [Currency] for [MoneyFormatter].
  final Map<String, Currency> currenciesByCode;

  /// User's display currency (from Phase 9 `display_currency` preference).
  /// Currently we render the listing's own currency rather than converting —
  /// cross-currency conversion lives in Phase 14 for the search-results page.
  /// This parameter is preserved for future-phase wire-up.
  final String? displayCurrencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: () => context.go(AppRoutes.listingDetailsFor(card.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(
              imageUrl: card.mainImageUrl,
              l10n: l10n,
              scheme: scheme,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title.isEmpty ? '—' : card.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _Badge(label: _propertyTypeLabel(l10n, card.propertyType)),
                      _Badge(label: _purposeLabel(l10n, card.purpose)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _locationLabel(card),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _formatPrice(locale),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _formatTimeSince(l10n, card.publishedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _locationLabel(HomeListingCard c) {
    final parts = <String>[
      if (c.governorateNameLocalized.isNotEmpty &&
          c.governorateNameLocalized != '—')
        c.governorateNameLocalized,
      if (c.cityNameLocalized.isNotEmpty && c.cityNameLocalized != '—')
        c.cityNameLocalized,
    ];
    return parts.isEmpty ? '—' : parts.join(' • ');
  }

  String _formatPrice(Locale locale) {
    final currency = currenciesByCode[card.primaryPrice.currencyCode];
    if (currency == null) {
      return '${card.primaryPrice.amount} ${card.primaryPrice.currencyCode}';
    }
    return MoneyFormatter.format(
      Money(
        amount: card.primaryPrice.amount,
        currencyCode: card.primaryPrice.currencyCode,
      ),
      locale: locale,
      currency: currency,
    );
  }

  String _formatTimeSince(AppLocalizations l10n, DateTime when) {
    // R-67 — Phase 3 `intl` dependency consumed via a relative-time helper.
    // We reuse the same convention as Phase 12's `rejection_reason_banner.dart`
    // `_formatTimeAgo` to maintain l10n consistency across the project.
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

  String _propertyTypeLabel(AppLocalizations l10n, PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return l10n.propertyTypeApartment;
      case PropertyType.villa:
        return l10n.propertyTypeVilla;
      case PropertyType.land:
        return l10n.propertyTypeLand;
      case PropertyType.shop:
        return l10n.propertyTypeShop;
      case PropertyType.office:
        return l10n.propertyTypeOffice;
      case PropertyType.farm:
        return l10n.propertyTypeFarm;
      case PropertyType.warehouse:
        return l10n.propertyTypeWarehouse;
      case PropertyType.other:
        return l10n.propertyTypeOther;
    }
  }

  String _purposeLabel(AppLocalizations l10n, ListingPurpose purpose) {
    switch (purpose) {
      case ListingPurpose.sale:
        return l10n.listingPurposeSale;
      case ListingPurpose.rent:
        return l10n.listingPurposeRent;
      case ListingPurpose.dailyRent:
        return l10n.listingPurposeDailyRent;
      case ListingPurpose.investment:
        return l10n.listingPurposeInvestment;
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.imageUrl,
    required this.l10n,
    required this.scheme,
  });

  final String? imageUrl;
  final AppLocalizations l10n;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: scheme.onSurfaceVariant,
              semanticLabel: l10n.image_unavailable,
            ),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, _) => ColoredBox(
          color: scheme.surfaceContainerHighest,
        ),
        errorWidget: (context, _, __) => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
              semanticLabel: l10n.image_unavailable,
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
