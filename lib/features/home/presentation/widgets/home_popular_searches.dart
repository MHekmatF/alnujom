import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../../search/domain/entities/filter_state.dart';

/// Phase 035 (ui-ux-pro-max Marketplace guidance) — popular-search suggestion
/// chips directly under the hero search bar. The skill's Marketplace pattern
/// treats the search bar as the primary CTA and recommends "popular searches
/// suggestions" to reduce friction. Each chip opens Search pre-filtered.
class HomePopularSearches extends StatelessWidget {
  const HomePopularSearches({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final suggestions = <_Suggestion>[
      _Suggestion(
        icon: Icons.apartment,
        label: '${l10n.propertyTypeApartment} · ${l10n.listingPurposeRent}',
        filters: const FilterState(
          propertyType: PropertyType.apartment,
          purpose: ListingPurpose.rent,
        ),
      ),
      _Suggestion(
        icon: Icons.villa_outlined,
        label: '${l10n.propertyTypeVilla} · ${l10n.listingPurposeSale}',
        filters: const FilterState(
          propertyType: PropertyType.villa,
          purpose: ListingPurpose.sale,
        ),
      ),
      _Suggestion(
        icon: Icons.landscape_outlined,
        label: l10n.propertyTypeLand,
        filters: const FilterState(propertyType: PropertyType.land),
      ),
      _Suggestion(
        icon: Icons.verified_outlined,
        label: l10n.detail_verified_badge,
        filters: const FilterState(verifiedOnly: true),
        emphasize: true,
      ),
    ];

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: SizedBox(
        height: MediaQuery.textScalerOf(context).scale(kAppMinTouchTarget),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          itemCount: suggestions.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Center(
                child: Text(
                  l10n.home_popular_searches,
                  style: styles.labelMedium.copyWith(color: colors.textMuted),
                ),
              );
            }
            return _Chip(suggestion: suggestions[i - 1]);
          },
        ),
      ),
    );
  }
}

class _Suggestion {
  const _Suggestion({
    required this.icon,
    required this.label,
    required this.filters,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final FilterState filters;
  final bool emphasize;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.suggestion});

  final _Suggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final fg = suggestion.emphasize ? colors.verified : colors.onSurface;
    final border = suggestion.emphasize ? colors.verified : colors.outline;

    return PressScale(
      child: Material(
        color: colors.card,
        borderRadius: appRadius(AppRadii.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.go(AppRoutes.search, extra: suggestion.filters);
          },
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: appRadius(AppRadii.pill),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(suggestion.icon, size: AppSpacing.lg, color: fg),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  suggestion.label,
                  style: styles.labelMedium.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
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
