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
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../../../shared/util/location_line.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import '../../domain/entities/home_listing_card.dart';

/// Phase 32 redesign — the **featured hero card**: the top "عقارات مميّزة"
/// listing rendered as one large, photo-led card with everything composited
/// over the image (gold مميّز badge, favourite heart, title, location, big
/// price, and frosted spec chips), matching the Al Nujom Design System home
/// mockup. Purely presentational — taps open the listing detail.
class FeaturedHeroCard extends StatelessWidget {
  const FeaturedHeroCard({
    super.key,
    required this.card,
    required this.currenciesByCode,
  });

  final HomeListingCard card;
  final Map<String, Currency> currenciesByCode;

  static const double _height = 304;

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
        margin: const EdgeInsetsDirectional.only(
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          bottom: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: appRadius(AppRadii.xl),
          boxShadow: elevation.level2,
        ),
        child: ClipRRect(
          borderRadius: appRadius(AppRadii.xl),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => context.go(AppRoutes.listingDetailsFor(card.id)),
              child: SizedBox(
                height: _height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      url: card.mainImageUrl,
                      heroTag: listingImageHeroTag(card.id),
                      semanticLabel: l10n.image_unavailable,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(gradient: gradients.photoScrim),
                    ),
                    // Gold featured badge (top-start) + heart (top-end).
                    PositionedDirectional(
                      top: AppSpacing.md,
                      start: AppSpacing.md,
                      child: StatusPill(
                        label: l10n.home_featured_badge,
                        color: colors.tertiary,
                        foreground: Theme.of(context).colorScheme.onTertiary,
                        icon: LucideIcons.star,
                      ),
                    ),
                    PositionedDirectional(
                      top: AppSpacing.md,
                      end: AppSpacing.md,
                      child: FavoriteHeartButton(
                        listingId: card.id,
                        style: FavoriteHeartStyle.onImage,
                      ),
                    ),
                    // Over-photo content block.
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.title.isEmpty ? '—' : card.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // ~21px bold over the photo — the loudest line on
                              // the hero card.
                              style: styles.headlineMedium.copyWith(
                                color: colors.onPhoto,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.map_pin,
                                  size: AppSpacing.lg,
                                  color: colors.onPhoto,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    _locationLabel(card),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: styles.bodyMedium.copyWith(
                                      color: colors.onPhoto,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _formatPrice(locale),
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.priceLarge.copyWith(
                                color: colors.onPhoto,
                              ),
                            ),
                            if (_specChips(l10n, locale).isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: _specChips(l10n, locale),
                              ),
                            ],
                          ],
                        ),
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

  List<Widget> _specChips(AppLocalizations l10n, Locale locale) {
    return [
      if (card.rooms != null)
        GlassPill(
          label: formatLocalizedNumber(card.rooms!, locale),
          icon: LucideIcons.bed_double,
        ),
      if (card.bathrooms != null)
        GlassPill(
          label: formatLocalizedNumber(card.bathrooms!, locale),
          icon: LucideIcons.bath,
        ),
      if (card.areaSize != null)
        GlassPill(
          label:
              '${formatLocalizedNumber(card.areaSize!.round(), locale)} ${l10n.spec_area_unit}',
          icon: LucideIcons.ruler,
        ),
    ];
  }

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
