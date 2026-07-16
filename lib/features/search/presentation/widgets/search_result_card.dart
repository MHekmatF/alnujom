// lib/features/search/presentation/widgets/search_result_card.dart
//
// Phase 14 Sub-Phase F (T027) — list-item card rendering one
// [SearchResultItem]. Tapping navigates to the Phase 13 listing details
// route. Mirrors the Phase 13 home card visual language but does NOT
// import from `lib/features/home/` (each feature owns its own UI surfaces).
//
// Phase 33 restyle — a horizontal results card matching the design system:
// a rounded (radius lg), hairline-outlined, softly-shadowed `colors.card`
// row with a 116×116 photo at the start (radius md) carrying a purpose tag
// at the top-start and a coral favourite heart at the top-end, then a body
// column of title → location → a bold blue price → a compact meta row.
// Purely visual — no data / routing / favourite-toggle change.
//
// Note: [SearchResultItem] does NOT carry rooms/bath/area facts (the search
// view projects only id/title/type/purpose/location/price/image/agency), so
// the bottom meta row renders the property-type + purpose that ARE available
// rather than inventing beds/baths/area data (which would require a non-visual
// entity/datasource/SQL change, out of scope for this restyle).
//
// Image: [SearchResultItem.mainImagePath] arrives here already as a full
// public URL — the datasource (`SupabaseSearchDatasource.fetchPage`) rewrites
// the raw storage path via `storage.from('listing-images').getPublicUrl(...)`
// before constructing the entity, so [CachedNetworkImage] can consume it
// directly.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/glass_pill.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../../agency/presentation/widgets/agency_badge.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/search_result_item.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.item});

  final SearchResultItem item;

  /// The square photo edge — the design system's horizontal-card thumbnail.
  static const double _photoSize = 116;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final governorateName = isAr
        ? item.governorateNameAr
        : item.governorateNameEn;
    final cityName = isAr ? item.cityNameAr : item.cityNameEn;
    final locationLabel = [
      governorateName,
      cityName,
    ].where((s) => s.isNotEmpty).join('، ');

    return PressScale(
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
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
              // context.push (not context.go) so SearchPage stays in the stack
              // and SearchBloc survives the back-navigation (R-77 / SC-005).
              onTap: () => context.push(AppRoutes.listingDetailsFor(item.id)),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                child: SizedBox(
                  height: _photoSize,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Photo(item: item, l10n: l10n, size: _photoSize),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _Body(
                          item: item,
                          l10n: l10n,
                          colors: colors,
                          styles: styles,
                          locationLabel: locationLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The square thumbnail (radius md) with a purpose tag over the top-start and a
/// circular favourite heart over the top-end. The verified-agency / by-owner
/// signal sits at the bottom-start, preserved from the original card.
class _Photo extends StatelessWidget {
  const _Photo({required this.item, required this.l10n, required this.size});

  final SearchResultItem item;
  final AppLocalizations l10n;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: appRadius(AppRadii.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              url: item.mainImagePath,
              semanticLabel: l10n.image_unavailable,
            ),
            // Top-start: the purpose tag (sale / rent / …) as a glass pill so
            // it reads on bright imagery.
            PositionedDirectional(
              top: AppSpacing.xs,
              start: AppSpacing.xs,
              child: GlassPill(label: _purposeLabel(item.purpose, l10n)),
            ),
            // Top-end: the coral favourite heart (circular over-photo chip).
            PositionedDirectional(
              top: AppSpacing.xs,
              end: AppSpacing.xs,
              child: FavoriteHeartButton(
                listingId: item.id,
                style: FavoriteHeartStyle.onImage,
              ),
            ),
            // Phase 19 D-1: verified-agency badge (compact overlay). agencyName
            // is non-null only for approved agencies.
            if (item.agencyName != null &&
                item.agencyName!.isNotEmpty &&
                item.agencyId != null)
              PositionedDirectional(
                bottom: AppSpacing.xs,
                start: AppSpacing.xs,
                child: AgencyBadge(
                  agencyId: item.agencyId!,
                  agencyName: item.agencyName!,
                  logoUrl: item.agencyLogoUrl,
                  compact: true,
                ),
              )
            // Owner-listed: no agency on the listing → a subtle "By owner" pill
            // so the lister distinction reads at a glance opposite the badge.
            else if (item.agencyId == null)
              PositionedDirectional(
                bottom: AppSpacing.xs,
                start: AppSpacing.xs,
                child: _ByOwnerPill(label: l10n.search_result_by_owner),
              ),
          ],
        ),
      ),
    );
  }
}

/// The body column: title → location → (pushed to the bottom) a bold blue price
/// over a compact meta row (property type · purpose). `spaceBetween` keeps the
/// price+meta anchored to the bottom of the 116dp row.
class _Body extends StatelessWidget {
  const _Body({
    required this.item,
    required this.l10n,
    required this.colors,
    required this.styles,
    required this.locationLabel,
  });

  final SearchResultItem item;
  final AppLocalizations l10n;
  final AppColors colors;
  final AppTextStyles styles;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title leads the body — a tight, bold listing name.
            Text(
              item.title,
              style: styles.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
            if (locationLabel.isNotEmpty) ...[
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
                      locationLabel,
                      style: styles.labelMedium.copyWith(
                        color: colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bold blue price — the loudest figure in the body. Rendered LTR so
            // numerals + currency read left-to-right even in RTL.
            Text(
              l10n.priceWithCurrency(
                formatLocalizedNumber(
                  item.primaryAmount.round(),
                  Localizations.localeOf(context),
                ),
                item.primaryCurrency,
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // priceMedium defaults to the brand-primary colour so the amount
              // reads as money, not body text.
              style: styles.priceMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            // Compact meta row beneath the price. The search projection carries
            // no beds/baths/area, so we surface the property type that IS
            // available (icon + value) as the card's key fact.
            _MetaItem(
              icon: _propertyTypeIcon(item.propertyType),
              label: _propertyTypeLabel(item.propertyType, l10n),
              colors: colors,
              styles: styles,
            ),
          ],
        ),
      ],
    );
  }
}

/// A small muted icon+label group for the card's meta row.
class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.colors,
    required this.styles,
  });

  final IconData icon;
  final String label;
  final AppColors colors;
  final AppTextStyles styles;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSpacing.lg, color: colors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _purposeLabel(ListingPurpose p, AppLocalizations l10n) {
  switch (p) {
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

String _propertyTypeLabel(PropertyType t, AppLocalizations l10n) {
  switch (t) {
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

IconData _propertyTypeIcon(PropertyType t) {
  switch (t) {
    case PropertyType.apartment:
      return LucideIcons.building_2;
    case PropertyType.villa:
      return LucideIcons.house;
    case PropertyType.land:
      return LucideIcons.trees;
    case PropertyType.shop:
      return LucideIcons.store;
    case PropertyType.office:
      return LucideIcons.briefcase;
    case PropertyType.farm:
      return LucideIcons.wheat;
    case PropertyType.warehouse:
      return LucideIcons.warehouse;
    case PropertyType.other:
      return LucideIcons.layout_grid;
  }
}

/// Subtle "By owner" overlay pill — the owner-listed counterpart to the
/// [AgencyBadge] (occupies the same bottom-start slot). Quiet by design
/// (surfaceVariant container, muted text) so an agency badge still reads as
/// the louder trust signal. Token-only; RTL-safe.
class _ByOwnerPill extends StatelessWidget {
  const _ByOwnerPill({required this.label});

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
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: AppSpacing.md,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: styles.labelMedium.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
