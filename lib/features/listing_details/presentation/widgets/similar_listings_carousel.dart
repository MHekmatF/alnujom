import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../bloc/similar_listings_cubit.dart';
import 'similar_listing_card_tile.dart';
import 'similar_listings_empty.dart';

/// Premium uplift v2 — the "similar listings" section at the bottom of the
/// listing-detail page: a localized section header + a horizontal carousel of
/// compact property cards sharing the source listing's type and governorate.
///
/// Self-contained: hosts its own [SimilarListingsCubit] and fires the fetch
/// once (the cubit guards against re-entry). Renders nothing when the pool is
/// empty or the fetch fails — never blocks the rest of the page.
class SimilarListingsCarousel extends StatelessWidget {
  const SimilarListingsCarousel({
    super.key,
    required this.listingId,
    required this.propertyType,
    required this.propertyTypeEnum,
    this.governorateId,
    this.staggerIndex = 0,
  });

  /// The source listing id (excluded from results).
  final String listingId;

  /// Source listing's property type as the DB enum string (e.g. 'apartment').
  final String propertyType;

  /// Source listing's property type as the enum — used to seed the empty-pool
  /// recovery card's search filter.
  final PropertyType propertyTypeEnum;

  /// Source listing's governorate id (null → property-type pool only).
  final String? governorateId;

  /// Stagger index forwarded to [StaggeredListItem] for the entrance animation.
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SimilarListingsCubit>(
      create: (_) {
        final cubit = getIt<SimilarListingsCubit>();
        cubit.load(
          listingId: listingId,
          propertyType: propertyType,
          governorateId: governorateId,
          locale: Localizations.localeOf(context),
        );
        return cubit;
      },
      child: _SimilarListingsBody(
        staggerIndex: staggerIndex,
        propertyTypeEnum: propertyTypeEnum,
        governorateId: governorateId,
      ),
    );
  }
}

class _SimilarListingsBody extends StatelessWidget {
  const _SimilarListingsBody({
    required this.staggerIndex,
    required this.propertyTypeEnum,
    required this.governorateId,
  });

  final int staggerIndex;
  final PropertyType propertyTypeEnum;
  final String? governorateId;

  /// Card footprint: a portion of the viewport so the next card peeks in,
  /// inviting the horizontal scroll.
  static const double _maxCardWidth = 280;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SimilarListingsCubit, SimilarListingsState>(
      builder: (context, state) {
        // Premium uplift — instead of collapsing on an empty pool, offer a
        // recovery card that routes to a seeded search ("browse similar in this
        // area"). Error / initial still collapse silently (no reflow noise).
        if (state.status == SimilarListingsStatus.empty) {
          return StaggeredListItem(
            index: staggerIndex,
            child: SimilarListingsEmpty(
              propertyType: propertyTypeEnum,
              governorateId: governorateId,
            ),
          );
        }
        if (state.status == SimilarListingsStatus.error ||
            state.status == SimilarListingsStatus.initial) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final colors = AppColors.of(context);
        final styles = AppTextStyles.of(context);

        final viewportWidth = MediaQuery.sizeOf(context).width;
        final cardWidth = viewportWidth * 0.72 > _maxCardWidth
            ? _maxCardWidth
            : viewportWidth * 0.72;
        // The card is a fixed-height box around a non-scrolling Column, so the
        // text block below the photo would overflow it once the OS text scale
        // grows. Let the row grow with the text instead, capped so a very large
        // scale cannot swallow the whole screen.
        final textScale = MediaQuery.textScalerOf(
          context,
        ).scale(1).clamp(1.0, 1.6);
        final rowHeight = cardWidth * 1.12 * textScale;

        final header = Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Text(
            l10n.listing_details_similar_title,
            style: styles.titleMedium.copyWith(color: colors.onSurface),
          ),
        );

        if (state.status == SimilarListingsStatus.loading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              SizedBox(
                height: rowHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: 3,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, __) => SizedBox(
                    width: cardWidth,
                    child: const LoadingState.card(),
                  ),
                ),
              ),
            ],
          );
        }

        return StaggeredListItem(
          index: staggerIndex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              SizedBox(
                height: rowHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: state.cards.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final card = state.cards[index];
                    return SimilarListingCardTile(
                      card: card,
                      currenciesByCode: state.currenciesByCode,
                      width: cardWidth,
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
