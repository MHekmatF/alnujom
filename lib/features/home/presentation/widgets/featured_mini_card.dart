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
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../../shared/util/location_line.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/home_listing_card.dart';

/// Phase 32 redesign — compact featured card paired 2-up beneath the
/// [FeaturedHeroCard], matching the DS home "mini" card: a short photo with a
/// glass purpose tag, then title · price · location. Presentational; taps open
/// the listing detail.
class FeaturedMiniCard extends StatelessWidget {
  const FeaturedMiniCard({
    super.key,
    required this.card,
    required this.currenciesByCode,
  });

  final HomeListingCard card;
  final Map<String, Currency> currenciesByCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final gradients = AppGradients.of(context);
    final elevation = AppElevation.of(context);
    final locale = Localizations.localeOf(context);

    return PressScale(
      child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 104,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(
                          url: card.mainImageUrl,
                          semanticLabel: l10n.image_unavailable,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: gradients.photoTopScrim,
                          ),
                        ),
                        PositionedDirectional(
                          top: AppSpacing.sm,
                          start: AppSpacing.sm,
                          child: GlassPill(label: _purposeLabel(l10n)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title.isEmpty ? '—' : card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _formatPrice(locale),
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.priceMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: styles.labelMedium.copyWith(
                                  color: colors.textMuted,
                                ),
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
    );
  }

  String _purposeLabel(AppLocalizations l10n) => switch (card.purpose) {
    ListingPurpose.sale => l10n.listingPurposeSale,
    ListingPurpose.rent => l10n.listingPurposeRent,
    ListingPurpose.dailyRent => l10n.listingPurposeDailyRent,
    ListingPurpose.investment => l10n.listingPurposeInvestment,
  };

  String _locationLabel(HomeListingCard c) {
    final line = listingLocationLine(
      governorate: c.governorateNameLocalized,
      city: c.cityNameLocalized,
      area: c.areaNameLocalized,
    );
    return line.isEmpty ? '—' : line;
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
}
