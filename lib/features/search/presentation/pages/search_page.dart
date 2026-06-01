// lib/features/search/presentation/pages/search_page.dart
//
// Phase 14 Sub-Phase F (T028) — root composition for the `/search` route.
//
// Structure (per contracts/phase14-search-page-composition.md):
//   SearchPage
//     └─ BlocProvider<SearchBloc>(create: fresh-from-DI ..add initial filters)
//          └─ _SearchPageView (Scaffold)
//                ├─ AppBar(leading: DeepLinkAwareBackButton)
//                │   └─ title: _SearchBar
//                └─ body: Column
//                      ├─ _SortAndFiltersRow
//                      └─ Expanded(_ResultsArea)
//
// Entry-point behaviour:
//   • Hero search bar tap (no extra) → /search, BLoC starts with
//     FilterState.empty, _SearchBar.autofocus=true, keyboard opens.
//   • Property-type chip tap (extra: PropertyType) → /search,
//     BLoC pre-filters by propertyType, _SearchBar.autofocus=false.
//
// Back-navigation: Q4=D `Navigator.canPop()` convention — extracted to
// DeepLinkAwareBackButton per Phase 14 DEFERRED.md §D-001 (Phase 15 is the
// third consumer trigger). Both call sites now consume the shared widget.
//
// Anonymous-access: no `AuthBloc` dependency. FR-015.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../features/map/domain/entities/map_entry_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ads/domain/entities/ad_placement.dart';
import '../../../ads/presentation/widgets/ad_slot.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/filter_state.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../widgets/inline_sort_control.dart';
import '../widgets/search_filter_sheet.dart';
import '../widgets/search_result_card.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, this.initialPropertyType});

  /// Set by [GoRouterState.extra] when the user enters via a property-type
  /// chip on Home. Null when entered via the hero search bar (autofocus).
  final PropertyType? initialPropertyType;

  @override
  Widget build(BuildContext context) {
    final initialFilters = initialPropertyType != null
        ? FilterState(propertyType: initialPropertyType)
        : FilterState.empty;
    return BlocProvider<SearchBloc>(
      // @injectable factory — every push of /search gets a fresh BLoC (R-77).
      create: (_) =>
          getIt<SearchBloc>()
            ..add(SearchFiltersApplied(filters: initialFilters)),
      child: _SearchPageView(autofocusSearchBar: initialPropertyType == null),
    );
  }
}

class _SearchPageView extends StatelessWidget {
  const _SearchPageView({required this.autofocusSearchBar});

  final bool autofocusSearchBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: _SearchBar(autofocus: autofocusSearchBar),
        titleSpacing: 0,
      ),
      body: const Column(
        children: [
          _SortAndFiltersRow(),
          Expanded(child: _ResultsArea()),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.autofocus});

  final bool autofocus;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<SearchBloc, SearchState>(
      // If the BLoC's `filters.query` is cleared from somewhere else (Reset
      // in filter sheet, "Clear filters" empty-state CTA) and the local
      // controller still has text, sync the controller to match.
      listenWhen: (prev, curr) =>
          prev.filters.query != curr.filters.query &&
          curr.filters.query == null &&
          _controller.text.isNotEmpty,
      listener: (context, state) => _controller.clear(),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.search_placeholder,
          border: InputBorder.none,
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
          ),
          suffixIcon: BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (p, c) =>
                (p.filters.query != null) != (c.filters.query != null),
            builder: (context, state) {
              if (state.filters.query == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  context.read<SearchBloc>().add(
                    SearchFiltersApplied(
                      filters: state.filters.copyWith(clearQuery: true),
                    ),
                  );
                },
              );
            },
          ),
        ),
        onChanged: (v) =>
            context.read<SearchBloc>().add(SearchQueryChanged(query: v)),
        onSubmitted: (v) {
          final trimmed = v.trim();
          final current = context.read<SearchBloc>().state.filters;
          context.read<SearchBloc>().add(
            SearchFiltersApplied(
              filters: current.copyWith(
                query: trimmed.isEmpty ? null : trimmed,
                clearQuery: trimmed.isEmpty,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SortAndFiltersRow extends StatelessWidget {
  const _SortAndFiltersRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    l10n.search_sort_label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Flexible(child: InlineSortControl()),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phase 15 G3: "Show on map" entry point per
              // contracts/phase15-search-show-on-map.md. Always visible;
              // no state mutation on SearchBloc. Icon-only to fit narrow
              // viewports (the labeled variant overflowed on 336dp-wide
              // screens alongside the sort control + filters button).
              IconButton(
                onPressed: () => _openMap(context),
                icon: const Icon(Icons.map_outlined),
                tooltip: l10n.search_results_show_on_map_action,
              ),
              BlocBuilder<SearchBloc, SearchState>(
                buildWhen: (p, c) => p.filters.isEmpty != c.filters.isEmpty,
                builder: (context, state) {
                  final highlight = !state.filters.isEmpty;
                  final color = highlight
                      ? Theme.of(context).colorScheme.primary
                      : null;
                  return TextButton.icon(
                    onPressed: () => _openFilterSheet(context, state.filters),
                    icon: Icon(Icons.tune, color: color),
                    label: Text(
                      l10n.search_filters_button,
                      style: AppTextStyles.of(
                        context,
                      ).labelLarge.copyWith(color: color),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Phase 15 G3: Navigate to MapPage with the current [FilterState] snapshot.
  /// Reads the filter from [SearchBloc] without mutating it (R-77 BLoC
  /// lifetime preserved — pressing back returns to identical search results).
  void _openMap(BuildContext context) {
    final filters = context.read<SearchBloc>().state.filters;
    context.go(
      AppRoutes.map,
      extra: MapEntryFromSearch(
        filterState: filters,
        showFilterAlert: filters.hasAnyActiveFilter,
      ),
    );
  }

  void _openFilterSheet(BuildContext context, FilterState filters) {
    final bloc = context.read<SearchBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SearchFilterSheet(
        initialFilters: filters,
        onApply: (f) => bloc.add(SearchFiltersApplied(filters: f)),
      ),
    );
  }
}

class _ResultsArea extends StatelessWidget {
  const _ResultsArea();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        switch (state.status) {
          case SearchStatus.initial:
            return Center(child: Text(l10n.search_placeholder));
          case SearchStatus.loading:
            if (state.results.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ResultsListView(state: state);
          case SearchStatus.failure:
            if (state.results.isEmpty) {
              return _ErrorView(
                message: l10n.search_error_message,
                retryLabel: l10n.search_error_retry,
                onRetry: () => context.read<SearchBloc>().add(
                  const SearchRefreshRequested(),
                ),
              );
            }
            // Failure during pagination — keep showing existing results.
            return _ResultsListView(state: state);
          case SearchStatus.success:
            if (state.results.isEmpty) {
              return _EmptyView(state: state);
            }
            return _ResultsListView(state: state);
        }
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 8),
            Text(
              l10n.search_empty_title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(l10n.search_empty_subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<SearchBloc>().add(
                const SearchFiltersApplied(filters: FilterState.empty),
              ),
              child: Text(l10n.search_empty_clear_filters),
            ),
            if (state.isArabicQuery)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  l10n.search_arabic_hint(
                    _suggestionFromQuery(state.filters.query!),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultsListView extends StatelessWidget {
  const _ResultsListView({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // FR-019: Arabic exact-token hint surfaces on sparse Arabic results
    // (1-2 hits) — shown as a top banner above the list.
    final showArabicHint = state.isArabicQuery && state.results.length < 3;
    final pagingTrail = state.hasNextPage ? 1 : 0;
    final hintTrail = showArabicHint ? 1 : 0;
    // Phase 21: search-results banner slot (always one item; AdSlot collapses
    // to SizedBox.shrink when no eligible ads — FR-012).
    const adTrail = 1;

    return ListView.builder(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: state.results.length + pagingTrail + hintTrail + adTrail,
      itemBuilder: (context, index) {
        // Phase 21: search results banner at the very top (index 0).
        if (index == 0) {
          return const Padding(
            padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: AdSlot(placement: AdPlacement.searchResultsBanner),
          );
        }
        final offsetIndex = index - adTrail;
        if (showArabicHint && offsetIndex == 0) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.search_arabic_hint(
                _suggestionFromQuery(state.filters.query!),
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        final itemIndex = offsetIndex - hintTrail;
        if (itemIndex == state.results.length) {
          return const _PaginationSentinel();
        }
        return SearchResultCard(item: state.results[itemIndex]);
      },
    );
  }
}

// Fires SearchNextPageRequested exactly once when it first enters the viewport
// (in initState). Using a StatefulWidget prevents the double-dispatch that
// occurs when addPostFrameCallback is called inside ListView.builder's
// itemBuilder — which reruns on every rebuild before loading state propagates.
class _PaginationSentinel extends StatefulWidget {
  const _PaginationSentinel();

  @override
  State<_PaginationSentinel> createState() => _PaginationSentinelState();
}

class _PaginationSentinelState extends State<_PaginationSentinel> {
  @override
  void initState() {
    super.initState();
    context.read<SearchBloc>().add(const SearchNextPageRequested());
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(AppSpacing.lg),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// FR-019 — suggest a simpler search term to the user. We pick the first
/// whitespace-delimited token from the original query; the user reads this
/// as "try a shorter / exact form" guidance.
String _suggestionFromQuery(String query) {
  final parts = query.trim().split(RegExp(r'\s+'));
  return parts.isNotEmpty ? parts.first : query;
}
