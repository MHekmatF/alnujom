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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final governorateName = isAr
        ? item.governorateNameAr
        : item.governorateNameEn;
    final cityName = isAr ? item.cityNameAr : item.cityNameEn;
    final locationLabel = [
      governorateName,
      cityName,
    ].where((s) => s.isNotEmpty).join(', ');

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
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
                    _CardImage(
                      imageUrl: item.mainImagePath,
                      fallbackLabel: l10n.image_unavailable,
                    ),
                    PositionedDirectional(
                      top: AppSpacing.xs,
                      end: AppSpacing.xs,
                      child: FavoriteHeartButton(listingId: item.id),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
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
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.imageUrl, required this.fallbackLabel});

  final String? imageUrl;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          semanticLabel: fallbackLabel,
        ),
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) {
      return placeholder;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}
