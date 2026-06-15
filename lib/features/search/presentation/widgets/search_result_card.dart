// lib/features/search/presentation/widgets/search_result_card.dart
//
// Phase 14 Sub-Phase F (T027) — list-item card rendering one
// [SearchResultItem]. Tapping navigates to the Phase 13 listing details
// route. Mirrors the Phase 13 home card visual language but does NOT
// import from `lib/features/home/` (each feature owns its own UI surfaces).
//
// Image: [SearchResultItem.mainImagePath] arrives here already as a full
// public URL — the datasource (`SupabaseSearchDatasource.fetchPage`) rewrites
// the raw storage path via `storage.from('listing-images').getPublicUrl(...)`
// before constructing the entity, so [CachedNetworkImage] can consume it
// directly.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../agency/presentation/widgets/agency_badge.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';
import '../../domain/entities/search_result_item.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final governorateName = isAr
        ? item.governorateNameAr
        : item.governorateNameEn;
    final cityName = isAr ? item.cityNameAr : item.cityNameEn;
    final locationLabel = [
      governorateName,
      cityName,
    ].where((s) => s.isNotEmpty).join(', ');

    return PressScale(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: appRadius(AppRadii.lg),
          side: BorderSide(color: colors.outline),
        ),
        child: InkWell(
          // context.push (not context.go) so SearchPage stays in the stack and
          // SearchBloc survives the back-navigation (R-77 / SC-005).
          onTap: () => context.push(AppRoutes.listingDetailsFor(item.id)),
          // SizedBox gives the Row a bounded height before CrossAxisAlignment.stretch
          // is applied — without it the Row receives ListView's unbounded height and
          // the inner Column(spaceBetween, mainAxisSize.max) crashes with
          // "BoxConstraints forces an infinite height".
          child: SizedBox(
            height: 116,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 116,
                  child: Stack(
                    children: [
                      AppNetworkImage(
                        url: item.mainImagePath,
                        semanticLabel: l10n.image_unavailable,
                      ),
                      PositionedDirectional(
                        top: AppSpacing.xs,
                        end: AppSpacing.xs,
                        child: FavoriteHeartButton(
                          listingId: item.id,
                          style: FavoriteHeartStyle.onImage,
                        ),
                      ),
                      // Phase 19 D-1: verified-agency badge (compact overlay).
                      // agencyName is non-null only for approved agencies.
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
                      // Owner-listed: no agency on the listing → a subtle
                      // "By owner" pill so the lister distinction reads at a
                      // glance opposite the agency badge.
                      else if (item.agencyId == null)
                        PositionedDirectional(
                          bottom: AppSpacing.xs,
                          start: AppSpacing.xs,
                          child: _ByOwnerPill(label: l10n.search_result_by_owner),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                        ),
                        if (locationLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: AppSpacing.xs,
                            ),
                            child: Text(
                              locationLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.xs,
                          ),
                          child: Text(
                            l10n.priceWithCurrency(
                              item.primaryAmount.toStringAsFixed(0),
                              item.primaryCurrency,
                            ),
                            // Price leads in the brand primary (priceMedium's
                            // default) — consistent with the home + detail cards.
                            style: styles.priceMedium,
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
