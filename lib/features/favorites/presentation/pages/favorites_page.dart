// lib/features/favorites/presentation/pages/favorites_page.dart
//
// Phase 17 Sub-Phase F (T033) — REPLACES the Sub-Phase A stub.
// Full composition per contracts/phase17-favorites-page-and-entry-points.md.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../comparison/presentation/cubit/comparison_cubit.dart';
import '../../../comparison/presentation/widgets/compare_bottom_bar.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/publish_fab.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../core/widgets/star_refresh_indicator.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/favorite_listing.dart';
import '../../domain/entities/favorites_sort.dart';
import '../bloc/favorites_page_bloc.dart';
import '../widgets/favorite_card.dart';
import '../widgets/favorites_empty_state.dart';
import '../widgets/favorites_sort_bar.dart';

/// The authenticated Favorites page: lists the user's saved listings newest-
/// first with cursor pagination. Unavailable listings (is_available=false) are
/// still rendered and remain tappable (Q4=A / FR-025).
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FavoritesPageBloc>(
          create: (_) =>
              getIt<FavoritesPageBloc>()..add(const FavoritesPageOpened()),
        ),
        // Shared singleton — the comparison selection persists across the
        // session, so re-provide (not re-create) it for the compare affordances.
        BlocProvider<ComparisonCubit>.value(value: getIt<ComparisonCubit>()),
      ],
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        // No back arrow when opened as the Favorites bottom-nav tab root
        // (nothing to pop — the bottom nav returns to Home); keep it when
        // pushed (e.g. from the Profile menu or a deep-link).
        leading: Navigator.canPop(context)
            ? const DeepLinkAwareBackButton()
            : null,
        title: Text(l10n.favorites_page_title),
      ),
      body: Stack(
        children: [
          BlocBuilder<FavoritesPageBloc, FavoritesPageState>(
            builder: (context, state) {
              // Distinct types per phase → the skeleton crossfades into the list
              // (or empty/error); list→list during pagination updates in place.
              final child = switch (state) {
                FavoritesPageLoading() => const _FavoritesSkeleton(),
                FavoritesPageError() => const _ErrorBody(),
                FavoritesPageLoaded(
                  :final items,
                  :final hasMore,
                  :final sort,
                ) =>
                  items.isEmpty
                      ? const FavoritesEmptyState()
                      : _LoadedBody(items: items, hasMore: hasMore, sort: sort),
              };
              return AnimatedSwitcher(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : AppMotion.base,
                child: child,
              );
            },
          ),
          // Floating "Compare (N)" bar — appears once >=2 listings are selected.
          const Align(
            alignment: AlignmentDirectional.bottomCenter,
            child: CompareBottomBar(),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(current: MainTab.favorites),
      floatingActionButton: const PublishFab(),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: AppLocalizations.of(context)!.error_could_not_load_listings,
      onRetry: () => context.read<FavoritesPageBloc>().add(
        const FavoritesPageRefreshRequested(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded body (list + pagination)
// ---------------------------------------------------------------------------

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.items,
    required this.hasMore,
    required this.sort,
  });

  final List<FavoriteListing> items;
  final bool hasMore;
  final FavoritesSort sort;

  @override
  Widget build(BuildContext context) {
    // Row 0 is the sort header; rows [1 .. items.length] are the cards; a final
    // spinner row is appended while [hasMore].
    const headerCount = 1;
    final spinnerCount = hasMore ? 1 : 0;

    return StarRefreshIndicator(
      onRefresh: () async {
        context.read<FavoritesPageBloc>().add(
          const FavoritesPageRefreshRequested(),
        );
      },
      child: ListView.builder(
        itemCount: headerCount + items.length + spinnerCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return FavoritesSortBar(sort: sort);
          }

          final itemIndex = index - headerCount;

          // Trigger load-more near the end.
          if (itemIndex >= (items.length * 0.8).floor() && hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<FavoritesPageBloc>().add(
                const FavoritesPageMoreLoaded(),
              );
            });
          }

          // Loading spinner sentinel at the end of the list.
          if (itemIndex >= items.length) {
            return const Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.lg),
              child: AppSpinner(),
            );
          }

          return StaggeredListItem(
            index: itemIndex,
            child: FavoriteCard(item: items[itemIndex]),
          );
        },
      ),
    );
  }
}

/// Shimmer placeholder cards (16:9 image + lines) shown while favorites load.
class _FavoritesSkeleton extends StatelessWidget {
  const _FavoritesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: LoadingState.card()),
            SizedBox(height: AppSpacing.md),
            SizedBox(height: AppSpacing.lg, child: LoadingState.row()),
            SizedBox(height: AppSpacing.sm),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.6,
              child: SizedBox(height: AppSpacing.lg, child: LoadingState.row()),
            ),
          ],
        ),
      ),
    );
  }
}
