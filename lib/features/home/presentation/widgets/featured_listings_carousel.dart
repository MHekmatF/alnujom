import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/ds/ds_listing_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../bloc/featured_listings_cubit.dart';
import 'home_card_mapper.dart';

/// The "عقارات مميّزة" section at the top of the home feed, rebuilt to the DC
/// "Blue Crown" design (`AlNujom.dc.html` §HOME): a gold-star section header
/// followed by a **horizontal rail** of compact 250px cards
/// ([DsListingCard] in its `featured` variant — gold "مميّز" chip, no heart,
/// no publisher row).
///
/// The rail has a fixed height, so unlike the old hero + 2-up grid it never
/// reflows the feed as its contents change. It stays visible whenever the cubit
/// holds featured listings — including through a pull-to-refresh reload, which
/// [FeaturedListingsCubit.load] carries the current listings through — so the
/// section no longer collapses to zero and snaps back mid-refresh.
class FeaturedListingsCarousel extends StatelessWidget {
  const FeaturedListingsCarousel({super.key, required this.currenciesByCode});

  /// Phase 9 currency catalog keyed by ISO code — threaded into each featured
  /// card so it can resolve the price (mirrors the regular feed card).
  final Map<String, Currency> currenciesByCode;

  /// Rail height: 250px card = 16/10 image (≈156) + the featured body. Cards
  /// with fewer specs are shorter and simply top-align in the rail.
  static const double _railHeight = 276;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeaturedListingsCubit, FeaturedListingsState>(
      builder: (context, state) {
        if (state.listings.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final locale = Localizations.localeOf(context);
        final listings = state.listings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FeaturedSectionHeader(
              title: l10n.home_featured_section_title,
              seeAllLabel: l10n.home_see_all,
              onSeeAll: () => context.go(AppRoutes.search),
            ),
            SizedBox(
              height: _railHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                itemCount: listings.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, i) => SizedBox(
                  width: 250,
                  child: DsListingCard(
                    data: homeCardToData(
                      listings[i],
                      currenciesByCode,
                      locale,
                      l10n,
                    ),
                    featured: true,
                    onTap: () =>
                        context.go(AppRoutes.listingDetailsFor(listings[i].id)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// DC section header for the featured block — a gold filled-star, the bold
/// section title, and a "عرض الكل" text link. The gold star ties the section to
/// the gold "مميّز" chip on the cards.
class _FeaturedSectionHeader extends StatelessWidget {
  const _FeaturedSectionHeader({
    required this.title,
    required this.seeAllLabel,
    required this.onSeeAll,
  });

  final String title;
  final String seeAllLabel;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: 20, color: colors.tertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: styles.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          InkWell(
            onTap: onSeeAll,
            borderRadius: appRadius(AppRadii.sm),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Text(
                seeAllLabel,
                style: styles.labelLarge.copyWith(color: colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
