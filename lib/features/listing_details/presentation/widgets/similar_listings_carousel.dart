import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/similar_listings_cubit.dart';
import 'similar_listing_card_tile.dart';

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
    this.governorateId,
    this.staggerIndex = 0,
  });

  /// The source listing id (excluded from results).
  final String listingId;

  /// Source listing's property type as the DB enum string (e.g. 'apartment').
  final String propertyType;

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
      child: _SimilarListingsBody(staggerIndex: staggerIndex),
    );
  }
}

class _SimilarListingsBody extends StatelessWidget {
  const _SimilarListingsBody({required this.staggerIndex});

  final int staggerIndex;

  /// Card footprint: a portion of the viewport so the next card peeks in,
  /// inviting the horizontal scroll.
  static const double _maxCardWidth = 280;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SimilarListingsCubit, SimilarListingsState>(
      builder: (context, state) {
        // Collapse entirely for empty / error / initial — no reflow noise.
        if (state.status == SimilarListingsStatus.empty ||
            state.status == SimilarListingsStatus.error ||
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

        final header = Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Text(
            l10n.listing_details_similar_title,
            style: styles.titleLarge.copyWith(color: colors.onSurface),
          ),
        );

        if (state.status == SimilarListingsStatus.loading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              SizedBox(
                height: cardWidth * 0.95,
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
                height: cardWidth * 0.95,
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
