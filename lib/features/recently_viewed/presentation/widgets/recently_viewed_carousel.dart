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
import '../../domain/entities/recently_viewed_listing.dart';
import '../bloc/recently_viewed_cubit.dart';
import 'recently_viewed_card.dart';

/// The "شوهد مؤخراً / Recently viewed" section on the Home feed — a horizontally
/// scrolling carousel of the listings the user most recently opened, backed by
/// local storage via [RecentlyViewedCubit].
///
/// Mirrors [FeaturedListingsCarousel]'s placement and style: a section header
/// (history icon + bold title) over a directional horizontal [ListView]. Hides
/// itself entirely (zero height) when the list is empty, so it never disrupts
/// the regular feed. RTL is handled by the directional ListView + padding, and
/// the entrance stagger degrades to no-motion via [StaggeredListItem].
class RecentlyViewedCarousel extends StatelessWidget {
  const RecentlyViewedCarousel({super.key});

  /// Portion of the viewport so the next card peeks in, inviting horizontal
  /// scroll — clamped so cards never grow absurdly wide on tablets.
  static const double _maxCardWidth = 260;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecentlyViewedCubit, List<RecentlyViewedListing>>(
      builder: (context, items) {
        // Render ONLY when at least one listing has been viewed; empty collapses
        // the section to nothing.
        if (items.isEmpty) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;

        final viewportWidth = MediaQuery.sizeOf(context).width;
        final cardWidth = viewportWidth * 0.6 > _maxCardWidth
            ? _maxCardWidth
            : viewportWidth * 0.6;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RecentlyViewedHeader(title: l10n.home_recently_viewed_title),
            SizedBox(
              // The compact card is a 16:10 hero plus a short body; a loose
              // bound clamped against the text scale keeps large-font users from
              // clipping the card.
              height: _cardHeight(cardWidth, context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  return StaggeredListItem(
                    index: index,
                    child: RecentlyViewedCard(
                      item: items[index],
                      width: cardWidth,
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

  static double _cardHeight(double cardWidth, BuildContext context) {
    final heroHeight = cardWidth * 10 / 16;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return heroHeight + 120.0 * scale.toDouble();
  }
}

/// Section header for the recently-viewed carousel — a history icon in a tinted
/// chip + a bold title, mirroring the featured carousel's header rhythm.
class _RecentlyViewedHeader extends StatelessWidget {
  const _RecentlyViewedHeader({required this.title});

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
              LucideIcons.history,
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
