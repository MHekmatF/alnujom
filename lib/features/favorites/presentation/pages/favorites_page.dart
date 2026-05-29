// lib/features/favorites/presentation/pages/favorites_page.dart
//
// Phase 17 Sub-Phase F (T033) — REPLACES the Sub-Phase A stub.
// Full composition per contracts/phase17-favorites-page-and-entry-points.md.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
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
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.favorites_page_title),
      ),
      body: BlocBuilder<FavoritesPageBloc, FavoritesPageState>(
        builder: (context, state) {
          return switch (state) {
            FavoritesPageLoading() =>
              const Center(child: CircularProgressIndicator()),
            FavoritesPageError(:final failure) => _ErrorBody(failure: failure),
            FavoritesPageLoaded(:final items, :final hasMore) =>
              items.isEmpty
                  ? const FavoritesEmptyState()
                  : _LoadedBody(items: items, hasMore: hasMore),
          };
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.failure});

  final Object failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: AppSpacing.xxxl),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(
              MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            ),
            onPressed: () => context.read<FavoritesPageBloc>().add(
              const FavoritesPageRefreshRequested(),
            ),
          ),
        ],
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
    return RefreshIndicator(
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

          return _FavoriteCard(item: items[index]);
        },
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

    return Card(
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
                _CardImage(
                  imagePath: item.isAvailable ? item.mainImagePath : null,
                  scheme: scheme,
                  l10n: l10n,
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
                        borderRadius:
                            BorderRadius.circular(AppSpacing.xs),
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
                      '${item.primaryAmount} ${item.primaryCurrency}',
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

class _CardImage extends StatelessWidget {
  const _CardImage({
    required this.imagePath,
    required this.scheme,
    required this.l10n,
  });

  final String? imagePath;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (imagePath == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: imagePath!,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            ColoredBox(color: scheme.surfaceContainerHighest),
        errorWidget: (_, __, ___) => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
