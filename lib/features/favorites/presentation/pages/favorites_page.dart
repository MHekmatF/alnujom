// lib/features/favorites/presentation/pages/favorites_page.dart
//
// Phase 17 Sub-Phase F (T033) — REPLACES the Sub-Phase A stub.
// Full composition per contracts/phase17-favorites-page-and-entry-points.md.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../core/widgets/star_refresh_indicator.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/favorite_listing.dart';
import '../bloc/favorites_page_bloc.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/favorites_empty_state.dart';

/// The authenticated Favorites page: lists the user's saved listings newest-
/// first with cursor pagination. Unavailable listings (is_available=false) are
/// still rendered and remain tappable (Q4=A / FR-025).
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FavoritesPageBloc>(
      create: (_) =>
          getIt<FavoritesPageBloc>()..add(const FavoritesPageOpened()),
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
      body: BlocBuilder<FavoritesPageBloc, FavoritesPageState>(
        builder: (context, state) {
          // Distinct types per phase → the skeleton crossfades into the list
          // (or empty/error); list→list during pagination updates in place.
          final child = switch (state) {
            FavoritesPageLoading() => const _FavoritesSkeleton(),
            FavoritesPageError() => const _ErrorBody(),
            FavoritesPageLoaded(:final items, :final hasMore) =>
              items.isEmpty
                  ? const FavoritesEmptyState()
                  : _LoadedBody(items: items, hasMore: hasMore),
          };
          return AnimatedSwitcher(
            duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
            child: child,
          );
        },
      ),
      bottomNavigationBar: const MainBottomNav(current: MainTab.favorites),
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
  const _LoadedBody({required this.items, required this.hasMore});

  final List<FavoriteListing> items;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return StarRefreshIndicator(
      onRefresh: () async {
        context.read<FavoritesPageBloc>().add(
          const FavoritesPageRefreshRequested(),
        );
      },
      child: ListView.builder(
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Trigger load-more near the end.
          if (index >= (items.length * 0.8).floor() && hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<FavoritesPageBloc>().add(
                const FavoritesPageMoreLoaded(),
              );
            });
          }

          // Loading spinner sentinel at the end of the list.
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return StaggeredListItem(
            index: index,
            child: _FavoriteCard(item: items[index]),
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

// ---------------------------------------------------------------------------
// Individual favorite card
// ---------------------------------------------------------------------------

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.item});

  final FavoriteListing item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PressScale(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: InkWell(
          // Available AND unavailable cards tap to the details page (Q4=A).
          onTap: () => context.push(AppRoutes.listingDetailsFor(item.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero image + heart overlay.
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AppNetworkImage(
                      url: item.isAvailable ? item.mainImagePath : null,
                      semanticLabel: l10n.image_unavailable,
                    ),
                  ),
                  PositionedDirectional(
                    top: AppSpacing.xs,
                    end: AppSpacing.xs,
                    child: FavoriteHeartButton(listingId: item.id),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unavailable indicator badge.
                    if (!item.isAvailable)
                      Container(
                        margin: const EdgeInsetsDirectional.only(
                          bottom: AppSpacing.xs,
                        ),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppSpacing.xs),
                        ),
                        child: Text(
                          l10n.favorite_unavailable_indicator,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    // Title (blank for unavailable rows — isAvailable=false gives
                    // empty string from DTO null-coalesce per FR-025 contract).
                    if (item.title.isNotEmpty)
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Price (null for unavailable rows).
                    if (item.primaryAmount != null &&
                        item.primaryCurrency != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.priceWithCurrency(
                          item.primaryAmount!.toStringAsFixed(0),
                          item.primaryCurrency!,
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    // Location (null for unavailable rows).
                    if (_locationLabel(item).isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _locationLabel(item),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _locationLabel(FavoriteListing item) {
    // Prefer Arabic display names; fall back to English for unavailable rows or
    // when the Arabic name is null. Phase 8 entry-point wiring will align this
    // with the user's active locale following the Phase 13 convention.
    final gov = item.governorateNameAr ?? item.governorateNameEn ?? '';
    final city = item.cityNameAr ?? item.cityNameEn ?? '';
    final parts = [if (gov.isNotEmpty) gov, if (city.isNotEmpty) city];
    return parts.join(' • ');
  }
}
