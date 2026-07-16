import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/gradients.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/glass_pill.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/money_formatter.dart';
import '../../domain/entities/reel.dart';
import '../bloc/reels_rail_cubit.dart';
import '../pages/reels_feed_page.dart';

/// Phase 029 (Reels W4) — the home "Reels" rail: a horizontally-scrolling row
/// of 9:16 poster cards. Self-wired — it hosts its OWN [ReelsRailCubit] (via
/// [getIt] + a page-scoped [BlocProvider]) and loads the first page when it
/// mounts. Mirrors the [FeaturedListingsCarousel] idiom: the section hides
/// itself entirely (zero height) on empty / failure / loading so it never
/// disrupts the home feed.
///
/// Tapping a card opens the fullscreen [ReelsFeedPage], seeded with the rail's
/// already-loaded reels so the feed paints without a second round-trip.
class ReelsRail extends StatelessWidget {
  const ReelsRail({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return BlocProvider<ReelsRailCubit>(
      create: (_) => getIt<ReelsRailCubit>()..load(locale: locale),
      child: const _ReelsRailView(),
    );
  }
}

class _ReelsRailView extends StatelessWidget {
  const _ReelsRailView();

  /// Fixed width of each 9:16 poster card.
  static const double _cardWidth = 150;
  static const double _cardHeight = _cardWidth * 16 / 9;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReelsRailCubit, ReelsRailState>(
      builder: (context, state) {
        // Render ONLY when loaded with at least one reel; empty / failure /
        // loading collapse the section to nothing.
        if (state.status != ReelsRailStatus.loaded || state.reels.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final reels = state.reels;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReelsSectionHeader(
              title: l10n.reels_section_title,
              seeAllLabel: l10n.reels_see_all,
              onSeeAll: () => _openFeed(context, reels),
            ),
            SizedBox(
              height: _cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                itemCount: reels.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  return StaggeredListItem(
                    index: index,
                    child: _ReelPosterCard(
                      reel: reels[index],
                      width: _cardWidth,
                      onTap: () => _openFeedAt(context, reels, index),
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

  void _openFeed(BuildContext context, List<Reel> reels) =>
      _openFeedAt(context, reels, 0);

  void _openFeedAt(BuildContext context, List<Reel> reels, int index) {
    // Seed the feed with the tapped card first so it opens on that reel.
    final ordered = index == 0
        ? reels
        : [...reels.sublist(index), ...reels.sublist(0, index)];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReelsFeedPage(initialReels: ordered),
      ),
    );
  }
}

/// "Reels" section header — a video glyph + bold title, with a see-all
/// affordance on the trailing edge (mirrors the featured carousel rhythm).
class _ReelsSectionHeader extends StatelessWidget {
  const _ReelsSectionHeader({
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
        AppSpacing.sm,
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
              LucideIcons.video,
              size: AppSpacing.lg,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: styles.titleLarge)),
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              seeAllLabel,
              style: styles.labelLarge.copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One 9:16 poster card: the poster still under a scrim, a centered play glyph,
/// and a price [GlassPill] on the leading-bottom edge.
class _ReelPosterCard extends StatelessWidget {
  const _ReelPosterCard({
    required this.reel,
    required this.width,
    required this.onTap,
  });

  final Reel reel;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final elevation = AppElevation.of(context);

    return PressScale(
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: appRadius(AppRadii.lg),
            boxShadow: elevation.level2,
          ),
          child: ClipRRect(
            borderRadius: appRadius(AppRadii.lg),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      url: reel.posterImageUrl,
                      semanticLabel: l10n.image_unavailable,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.of(context).photoScrim,
                        ),
                      ),
                    ),
                    // Centered play affordance.
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.photoOverlay,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsetsDirectional.all(AppSpacing.sm),
                          child: Icon(
                            LucideIcons.play,
                            color: colors.onPhoto,
                            size: AppSpacing.xl,
                          ),
                        ),
                      ),
                    ),
                    if (reel.hasPrice)
                      Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: Padding(
                          padding:
                              const EdgeInsetsDirectional.all(AppSpacing.sm),
                          child: GlassPill(
                            label: MoneyFormatter.formatAmount(
                              num.tryParse(reel.priceAmount!) ?? 0,
                              reel.priceCurrency!,
                              locale: Localizations.localeOf(context),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
