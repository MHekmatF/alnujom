import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/gradients.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/hero_tags.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/property_specs.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../agency/presentation/widgets/agency_badge.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/home_listing_card.dart';

/// Phase 13 home-feed card, restyled in Phase 33 to the photo-forward feed
/// card: a rounded (radius lg, hairline-outlined, softly-shadowed) card with a
/// 16:9 photo carrying a small purpose tag at the top-start and a coral
/// favourite heart at the top-end, then a body of title → location → a bold
/// blue price → a compact beds/baths/area spec row, with the verified-agency
/// footer preserved beneath. No data / routing / logic change — purely visual.
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final locale = Localizations.localeOf(context);

    final hasSpecs = PropertySpecsRow.hasAnyOf(
      rooms: card.rooms,
      bathrooms: card.bathrooms,
      areaSize: card.areaSize,
    );

    return PressScale(
      child: Container(
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: ClipRRect(
        borderRadius: appRadius(AppRadii.lg),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => context.go(AppRoutes.listingDetailsFor(card.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(
                  imageUrl: card.mainImageUrl,
                  l10n: l10n,
                  listingId: card.id,
                  purposeLabel: _purposeLabel(l10n, card.purpose),
                  purposeColor: _purposeColor(colors, card.purpose),
                  isFeatured: card.isFeatured,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title leads the body — a tight, bold listing name.
                      Text(
                        card.title.isEmpty ? '—' : card.title,
                        style: styles.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.map_pin,
                            size: AppSpacing.lg,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _locationLabel(card),
                              style: styles.bodyMedium.copyWith(
                                color: colors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Bold blue price — the loudest figure in the body.
                      _PriceLine(
                        text: _formatPrice(locale),
                        styles: styles,
                      ),
                      // Compact beds/baths/area row beneath the price.
                      if (hasSpecs) ...[
                        const SizedBox(height: AppSpacing.sm),
                        PropertySpecsRow(
                          rooms: card.rooms,
                          bathrooms: card.bathrooms,
                          areaSize: card.areaSize,
                          color: colors.textMuted,
                        ),
                      ],
                      // Phase 19 (FR-022) — verified-agency footer; rendered
                      // only for approved agencies (no reflow otherwise per
                      // FR-023), separated by a hairline divider.
                      if (card.agencyId != null && card.agencyName != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Divider(height: 1, color: colors.outline),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AgencyBadge(
                                agencyId: card.agencyId!,
                                agencyName: card.agencyName!,
                                logoUrl: card.agencyLogoUrl,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              _formatTimeSince(l10n, card.publishedAt),
                              style: styles.labelMedium.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _formatTimeSince(l10n, card.publishedAt),
                          style: styles.labelMedium.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Color _purposeColor(AppColors colors, ListingPurpose purpose) {
    switch (purpose) {
      case ListingPurpose.sale:
        return colors.primary;
      case ListingPurpose.rent:
        return colors.verified;
      case ListingPurpose.dailyRent:
        return colors.accent;
      case ListingPurpose.investment:
        return colors.tertiary;
    }
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

/// The card's blue price line. Rendered LTR (numerals + currency symbol read
/// left-to-right even in RTL) at the bold [AppTextStyles.priceMedium] scale —
/// the brand-primary colour reads it as money, not body text.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.text, required this.styles});

  final String text;
  final AppTextStyles styles;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // priceMedium defaults to the brand-primary colour so the amount reads as
      // money, not body text.
      style: styles.priceMedium,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.imageUrl,
    required this.l10n,
    required this.listingId,
    required this.purposeLabel,
    required this.purposeColor,
    required this.isFeatured,
  });

  final String? imageUrl;
  final AppLocalizations l10n;
  final String listingId;
  final String purposeLabel;
  final Color purposeColor;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    // Phase polish — AppNetworkImage handles the fade-in + null/error fallback,
    // and owns the Hero flight that morphs this image into the detail gallery.
    // A cinematic 16:9 hero reads more premium than the old 16:10 crop.
    final image = AspectRatio(
      aspectRatio: 16 / 9,
      child: AppNetworkImage(
        url: imageUrl,
        heroTag: listingImageHeroTag(listingId),
        semanticLabel: l10n.image_unavailable,
      ),
    );

    final gradients = AppGradients.of(context);

    return Stack(
      children: [
        image,
        // Bottom-anchored scrim so the purpose/type pills stay legible on
        // bright imagery (token gradient; transparent over the top half).
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradients.photoScrim),
          ),
        ),
        // Lighter top scrim so the favorite chip keeps contrast against a
        // bright sky in the photo.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: gradients.photoTopScrim),
          ),
        ),
        PositionedDirectional(
          top: AppSpacing.md,
          end: AppSpacing.md,
          child: FavoriteHeartButton(
            listingId: listingId,
            style: FavoriteHeartStyle.onImage,
          ),
        ),
        // Top-start: the purpose tag (sale/rent), with the gold "مميّز /
        // Featured" pill stacked above it for promoted listings so a featured
        // card still reads as special within the regular feed.
        PositionedDirectional(
          top: AppSpacing.md,
          start: AppSpacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFeatured) ...[
                StatusPill(
                  label: l10n.home_featured_badge,
                  // Premium "مميّز" signal — solid GOLD with dark ink (gold
                  // fails contrast under white). Matches AppBadge.featured.
                  color: AppColors.of(context).tertiary,
                  foreground: Theme.of(context).colorScheme.onTertiary,
                  icon: LucideIcons.star,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              StatusPill(label: purposeLabel, color: purposeColor),
            ],
          ),
        ),
      ],
    );
  }
}
