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
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/property_specs.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/similar_listing_card.dart';

/// Premium uplift v2 — a fixed-width compact card for the "similar listings"
/// carousel. Reuses the home/property-card visual language (photo-forward hero
/// with frosted type pill + semantic purpose pill, then a body with a prominent
/// price, title, key facts and location) at a narrower footprint so several fit
/// in a horizontal scroller. Tapping routes to that listing's detail page.
class SimilarListingCardTile extends StatelessWidget {
  const SimilarListingCardTile({
    super.key,
    required this.card,
    required this.currenciesByCode,
    required this.width,
  });

  final SimilarListingCard card;
  final Map<String, Currency> currenciesByCode;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final locale = Localizations.localeOf(context);

    return PressScale(
      child: SizedBox(
        width: width,
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: appRadius(AppRadii.lg),
            border: Border.all(color: colors.outline),
            boxShadow: elevation.level2,
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
                      typeLabel: _propertyTypeLabel(l10n, card.propertyType),
                      purposeLabel: _purposeLabel(l10n, card.purpose),
                      purposeColor: _purposeColor(colors, card.purpose),
                      imageUnavailableLabel: l10n.image_unavailable,
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatPrice(locale),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.start,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: styles.priceMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            card.title.isEmpty ? '—' : card.title,
                            style: styles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (PropertySpecsRow.hasAnyOf(
                            rooms: card.rooms,
                            bathrooms: card.bathrooms,
                            areaSize: card.areaSize,
                          )) ...[
                            const SizedBox(height: AppSpacing.sm),
                            PropertySpecsRow(
                              rooms: card.rooms,
                              bathrooms: card.bathrooms,
                              areaSize: card.areaSize,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.map_pin,
                                size: AppSpacing.md,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  _locationLabel(card),
                                  style: styles.labelMedium.copyWith(
                                    color: colors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

  String _locationLabel(SimilarListingCard c) {
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
    required this.typeLabel,
    required this.purposeLabel,
    required this.purposeColor,
    required this.imageUnavailableLabel,
  });

  final String? imageUrl;
  final String typeLabel;
  final String purposeLabel;
  final Color purposeColor;
  final String imageUnavailableLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: AppNetworkImage(
            url: imageUrl,
            semanticLabel: imageUnavailableLabel,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.of(context).photoScrim,
            ),
          ),
        ),
        PositionedDirectional(
          bottom: AppSpacing.sm,
          start: AppSpacing.sm,
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
