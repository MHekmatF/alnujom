import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../bloc/featured_listings_cubit.dart';
import 'featured_hero_card.dart';
import 'featured_mini_card.dart';

/// Phase 32 redesign — the "✨ عقارات مميّزة" section at the TOP of the home feed.
///
/// Matches the Al Nujom Design System home mockup: a single large
/// [FeaturedHeroCard] (the top featured listing, photo-led with everything
/// composited over the image) followed by a 2-up grid of compact
/// [FeaturedMiniCard]s for the remaining featured listings.
///
/// Hides itself entirely (zero height) unless the [FeaturedListingsCubit] is in
/// the `loaded` state with at least one listing — `empty` / `failure` /
/// `loading` collapse the section so it never disrupts the regular feed.
class FeaturedListingsCarousel extends StatelessWidget {
  const FeaturedListingsCarousel({super.key, required this.currenciesByCode});

  /// Phase 9 currency catalog keyed by ISO code — threaded into each featured
  /// card so it can resolve the price (mirrors the regular feed card).
  final Map<String, Currency> currenciesByCode;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeaturedListingsCubit, FeaturedListingsState>(
      builder: (context, state) {
        if (state.status != FeaturedListingsStatus.loaded ||
            state.listings.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final listings = state.listings;
        final hero = listings.first;
        final rest = listings.skip(1).toList();

        return StaggeredListItem(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeaturedSectionHeader(title: l10n.home_featured_section_title),
              FeaturedHeroCard(card: hero, currenciesByCode: currenciesByCode),
              if (rest.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.lg,
                    end: AppSpacing.lg,
                    bottom: AppSpacing.sm,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = AppSpacing.md;
                      final width = (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final card in rest)
                            SizedBox(
                              width: width,
                              child: FeaturedMiniCard(
                                card: card,
                                currenciesByCode: currenciesByCode,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Section header for the featured block — a gold sparkle tile + bold title,
/// tying the section to the gold مميّز badge on the cards.
class _FeaturedSectionHeader extends StatelessWidget {
  const _FeaturedSectionHeader({required this.title});

  final String title;

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
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xs),
            decoration: BoxDecoration(
              // Gold sparkle tile — ties the "featured" section to the gold
              // premium signal used on the cards' مميّز badge.
              color: colors.tertiary,
              borderRadius: appRadius(AppRadii.md),
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: AppSpacing.lg,
              color: Theme.of(context).colorScheme.onTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: styles.titleLarge)),
        ],
      ),
    );
  }
}
