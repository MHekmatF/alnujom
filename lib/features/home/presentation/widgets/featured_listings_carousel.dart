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
import 'home_listing_card.dart';

/// Phase 25 (featured-listings treatment) — the "✨ عقارات مميّزة" section at the
/// TOP of the home feed: a horizontally-scrolling carousel of compact featured
/// cards.
///
/// Hides itself entirely (zero height) unless the [FeaturedListingsCubit] is in
/// the `loaded` state with at least one listing — `empty` and `failure` both
/// collapse the section so it never disrupts the regular feed. RTL is handled
/// automatically by the directional ListView + padding, and the entrance
/// stagger degrades to no-motion via [StaggeredListItem].
class FeaturedListingsCarousel extends StatelessWidget {
  const FeaturedListingsCarousel({
    super.key,
    required this.currenciesByCode,
  });

  /// Phase 9 currency catalog keyed by ISO code — threaded into each featured
  /// card so it can resolve the price (mirrors the regular feed card).
  final Map<String, Currency> currenciesByCode;

  /// Fixed width of each compact featured card. Slightly narrower than the
  /// viewport so the next card peeks in, signalling horizontal scrollability.
  static const double _cardWidth = 300;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeaturedListingsCubit, FeaturedListingsState>(
      builder: (context, state) {
        // Render ONLY when there is at least one loaded featured listing;
        // empty / failure / loading collapse the section to nothing.
        if (state.status != FeaturedListingsStatus.loaded ||
            state.listings.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final listings = state.listings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FeaturedSectionHeader(title: l10n.home_featured_section_title),
            SizedBox(
              // Tall enough for the full card (16:9 hero + body). A loose bound
              // is fine — the inner cards size themselves; this just constrains
              // the horizontal viewport height.
              height: _cardHeight(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                itemCount: listings.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final card = listings[index];
                  return StaggeredListItem(
                    index: index,
                    child: SizedBox(
                      width: _cardWidth,
                      child: HomeListingCardTile(
                        card: card,
                        currenciesByCode: currenciesByCode,
                        displayCurrencyCode: null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Carousel viewport height — derived from the card width's 16:9 hero plus a
  /// generous allowance for the price/title/location body, clamped against the
  /// text scale so large-font users don't clip the card.
  static double _cardHeight(BuildContext context) {
    final heroHeight = _cardWidth * 9 / 16;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return heroHeight + 200.0 * scale.toDouble();
  }
}

/// Section header for the featured carousel — a sparkles icon + bold title,
/// mirroring the regular feed's `_SectionHeader` rhythm but with the brand
/// sparkle that marks the featured treatment.
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
              color: colors.primaryContainer,
              borderRadius: appRadius(AppRadii.md),
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: AppSpacing.lg,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: styles.titleLarge)),
        ],
      ),
    );
  }
}
