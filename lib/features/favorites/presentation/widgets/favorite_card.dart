// lib/features/favorites/presentation/widgets/favorite_card.dart
//
// Phase 25 uplift v2 — the premium FavoritesPage card. Mirrors the home-feed
// `HomeListingCardTile` aesthetic: a photo-forward (16:10) hero with an
// over-photo favorite chip + status/type pills, then a body with a brand-blue
// price (priceLarge), title, a PropertySpecsRow (beds · baths · area), and the
// location. Unavailable rows (is_available=false) keep their FR-025 treatment
// (a "No longer available" pill, dimmed photo) and remain tappable.
//
// Token-only (no inline hex / TextStyle / numeric insets). RTL-safe; numbers
// render in the active locale's numerals via `formatLocalizedNumber`.
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
import '../../../../shared/presentation/money_formatter.dart';
import '../../../comparison/domain/entities/comparison_item.dart';
import '../../../comparison/presentation/widgets/compare_toggle_button.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/favorite_listing.dart';
import 'favorite_heart_button.dart';

/// A bold, premium card for one saved listing on the FavoritesPage.
class FavoriteCard extends StatelessWidget {
  const FavoriteCard({super.key, required this.item});

  final FavoriteListing item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    final location = _locationLabel(item);

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
          boxShadow: elevation.level2,
        ),
        child: ClipRRect(
          borderRadius: appRadius(AppRadii.lg),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              // Available AND unavailable cards tap to the details page (Q4=A).
              onTap: () => context.push(AppRoutes.listingDetailsFor(item.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(item: item, l10n: l10n),
                  // One node for the screen reader: price, title, specs and
                  // location read as a single card instead of four fragments.
                  // The hero keeps its own nodes so its buttons stay reachable.
                  MergeSemantics(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Price (null for unavailable rows) — brand-blue,
                          // priceLarge so the number reads as money.
                          if (item.primaryAmount != null &&
                              item.primaryCurrency != null) ...[
                            Text(
                              MoneyFormatter.formatAmount(
                                item.primaryAmount!,
                                item.primaryCurrency!,
                                locale: Localizations.localeOf(context),
                              ),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                              style: styles.priceLarge,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          // Title (empty string for unavailable rows per FR-025).
                          Text(
                            item.title.isEmpty ? '—' : item.title,
                            style: styles.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (PropertySpecsRow.hasAnyOf(
                            rooms: item.rooms,
                            bathrooms: item.bathrooms,
                            areaSize: item.areaSize,
                          )) ...[
                            const SizedBox(height: AppSpacing.sm),
                            PropertySpecsRow(
                              rooms: item.rooms,
                              bathrooms: item.bathrooms,
                              areaSize: item.areaSize,
                            ),
                          ],
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.map_pin,
                                  size: AppSpacing.lg,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: styles.bodyMedium.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
    );
  }

  String _locationLabel(FavoriteListing item) {
    // Prefer Arabic display names; fall back to English for unavailable rows or
    // when the Arabic name is null.
    final gov = item.governorateNameAr ?? item.governorateNameEn ?? '';
    final city = item.cityNameAr ?? item.cityNameEn ?? '';
    final parts = [if (gov.isNotEmpty) gov, if (city.isNotEmpty) city];
    return parts.join(' • ');
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.item, required this.l10n});

  final FavoriteListing item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final image = AspectRatio(
      aspectRatio: 16 / 10,
      child: AppNetworkImage(url: item.isAvailable ? item.mainImagePath : null),
    );

    return Stack(
      children: [
        image,
        // Bottom scrim keeps over-photo pills legible on bright imagery.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.of(context).photoScrim,
            ),
          ),
        ),
        // Unavailable rows are dimmed with a soft scrim so the "no longer
        // available" treatment reads at a glance (FR-025).
        if (!item.isAvailable)
          Positioned.fill(child: ColoredBox(color: colors.scrim)),
        PositionedDirectional(
          top: AppSpacing.sm,
          end: AppSpacing.sm,
          child: FavoriteHeartButton(
            listingId: item.id,
            style: FavoriteHeartStyle.onImage,
          ),
        ),
        // Compare affordance (toggles this listing into the comparison set).
        PositionedDirectional(
          top: AppSpacing.sm,
          start: AppSpacing.sm,
          child: CompareToggleButton(item: ComparisonItem.fromFavorite(item)),
        ),
        PositionedDirectional(
          bottom: AppSpacing.sm,
          start: AppSpacing.sm,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!item.isAvailable)
                StatusPill(
                  label: l10n.favorite_unavailable_indicator,
                  color: colors.error,
                  icon: LucideIcons.circle_slash,
                )
              else ...[
                StatusPill(
                  label: _purposeLabel(l10n, item.purpose),
                  color: _purposeColor(colors, item.purpose),
                ),
                const SizedBox(width: AppSpacing.xs),
                GlassPill(label: _propertyTypeLabel(l10n, item.propertyType)),
              ],
            ],
          ),
        ),
      ],
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
}
