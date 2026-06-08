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
import '../../../../core/widgets/glass_pill.dart';
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

/// Phase 13 home-feed card, restyled in Phase 25 to the Claude Design
/// `an-card`: a photo-forward (16:10) hero with a frosted type pill and a
/// semantic sale/rent status pill over the image, a coral favorite chip, then
/// a body with a prominent price, title, location, and a green verified-agency
/// footer. No data / routing / logic change — purely visual.
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
        borderRadius: appRadius(AppRadii.xl),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level2,
      ),
      child: ClipRRect(
        borderRadius: appRadius(AppRadii.xl),
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
                  typeLabel: _propertyTypeLabel(l10n, card.propertyType),
                  purposeLabel: _purposeLabel(l10n, card.purpose),
                  purposeColor: _purposeColor(colors, card.purpose),
                  isFeatured: card.isFeatured,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price leads the body — the largest, boldest line on the
                      // card. Currency suffix is lighter so the amount carries.
                      _PriceLine(
                        text: _formatPrice(locale),
                        styles: styles,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        card.title.isEmpty ? '—' : card.title,
                        style: styles.titleLarge,
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
                      // Key facts sit in a recessed strip so the beds/baths/area
                      // read as a distinct, scannable block under the location.
                      if (hasSpecs) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: appRadius(AppRadii.md),
                          ),
                          child: PropertySpecsRow(
                            rooms: card.rooms,
                            bathrooms: card.bathrooms,
                            areaSize: card.areaSize,
                            color: colors.onSurface,
                          ),
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

/// The card's headline price. Rendered LTR (numerals + currency symbol read
/// left-to-right even in RTL) at the bold [AppTextStyles.priceLarge] scale so
/// the money is unmistakably the loudest element in the card body.
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
      // priceLarge defaults to the brand-primary colour so the amount reads as
      // money, not body text.
      style: styles.priceLarge,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.imageUrl,
    required this.l10n,
    required this.listingId,
    required this.typeLabel,
    required this.purposeLabel,
    required this.purposeColor,
    required this.isFeatured,
  });

  final String? imageUrl;
  final AppLocalizations l10n;
  final String listingId;
  final String typeLabel;
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
        // Featured-listings treatment — a small brand-tinted "مميّز / Featured"
        // pill at the top-start of the photo (opposite the favorite chip), so a
        // promoted listing reads as special even within the regular feed.
        if (isFeatured)
          PositionedDirectional(
            top: AppSpacing.md,
            start: AppSpacing.md,
            child: StatusPill(
              label: l10n.home_featured_badge,
              color: AppColors.of(context).primary,
              icon: LucideIcons.sparkles,
            ),
          ),
        PositionedDirectional(
          bottom: AppSpacing.md,
          start: AppSpacing.md,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusPill(label: purposeLabel, color: purposeColor),
              const SizedBox(width: AppSpacing.xs),
              GlassPill(label: typeLabel),
            ],
          ),
        ),
      ],
    );
  }
}
