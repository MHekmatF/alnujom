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
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/segmented_control.dart' as seg;
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../features/map/domain/entities/map_entry_context.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ads/domain/entities/ad_placement.dart';
import '../../../ads/presentation/widgets/ad_slot.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/count_filter_mode.dart';
import '../../domain/entities/display_mode.dart';
import '../../domain/entities/filter_state.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../cubit/recent_searches_cubit.dart';
import '../cubit/saved_searches_cubit.dart';
import '../widgets/inline_sort_control.dart';
import '../widgets/recent_searches_panel.dart';
import '../widgets/save_search_dialog.dart';
import '../widgets/search_filter_sheet.dart';
import '../widgets/search_map_view.dart';
import '../widgets/search_result_card.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    this.initialPropertyType,
    this.initialFilters,
    this.autofocus = false,
  });

  /// Set by [GoRouterState.extra] when the user enters via a property-type
  /// chip on Home (pre-filters by type).
  final PropertyType? initialPropertyType;

  /// Phase 25 — a full [FilterState] to seed the BLoC with, set by
  /// [GoRouterState.extra] when the user re-applies a saved search. Takes
  /// precedence over [initialPropertyType].
  final FilterState? initialFilters;

  /// Phase 25 — only auto-open the keyboard when the user entered with a clear
  /// typing intent (the Home hero search pill, via `?focus=1`). Browse-intent
  /// entries (the Search bottom-nav tab, the filter button, ads, category
  /// chips) leave the keyboard closed so results/filters stay visible.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final seedFilters =
        initialFilters ??
        (initialPropertyType != null
            ? FilterState(propertyType: initialPropertyType)
            : FilterState.empty);
    return MultiBlocProvider(
      providers: [
        BlocProvider<SearchBloc>(
          // @injectable factory — every push of /search gets a fresh BLoC (R-77).
          create: (_) =>
              getIt<SearchBloc>()
                ..add(SearchFiltersApplied(filters: seedFilters)),
        ),
        BlocProvider<RecentSearchesCubit>(
          create: (_) => getIt<RecentSearchesCubit>()..load(),
        ),
        BlocProvider<SavedSearchesCubit>(
          create: (_) => getIt<SavedSearchesCubit>(),
        ),
      ],
      child: _SearchPageView(
        autofocusSearchBar: autofocus,
        // Seed the local controller text so a re-applied saved search shows
        // its query in the bar.
        initialQuery: seedFilters.query,
      ),
    );
  }
}

class _SearchPageView extends StatefulWidget {
  const _SearchPageView({required this.autofocusSearchBar, this.initialQuery});

  final bool autofocusSearchBar;
  final String? initialQuery;

  @override
  State<_SearchPageView> createState() => _SearchPageViewState();
}

class _SearchPageViewState extends State<_SearchPageView> {
  /// True while the search bar holds focus AND its text is empty — the
  /// recent-searches panel overlays the results in that window.
  bool _showRecent = false;

  void _onFocusEmptyChanged(bool show) {
    if (_showRecent == show) return;
    setState(() => _showRecent = show);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        // No back arrow when opened as the Search bottom-nav tab root (nothing
        // to pop — the bottom nav returns to Home); keep it when pushed (hero
        // search / property-type chip / deep-link).
        leading: Navigator.canPop(context)
            ? const DeepLinkAwareBackButton()
            : null,
        title: _SearchBar(
          autofocus: widget.autofocusSearchBar,
          initialQuery: widget.initialQuery,
          onFocusEmptyChanged: _onFocusEmptyChanged,
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: l10n.search_saved_searches_title,
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => context.push(AppRoutes.savedSearches),
          ),
        ],
      ),
      body: Column(
        children: [
          const _SortAndFiltersRow(),
          const _ActiveFilterChips(),
          const _DisplayModeBar(),
          Expanded(
            child: Stack(
              children: [
                const _ResultsArea(),
                if (_showRecent)
                  Positioned.fill(
                    child: RecentSearchesPanel(
                      onSelected: (query) {
                        // Dismiss focus + run the search.
                        FocusScope.of(context).unfocus();
                        _onFocusEmptyChanged(false);
                        final bloc = context.read<SearchBloc>();
                        bloc.add(
                          SearchFiltersApplied(
                            filters: bloc.state.filters.copyWith(query: query),
                          ),
                        );
                        context.read<RecentSearchesCubit>().record(query);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(current: MainTab.none),
    );
  }
}

/// The list ⇄ map presentation toggle + the "save this search" action. Hidden
/// in the initial (pre-first-search) state to keep the empty surface calm.
class _DisplayModeBar extends StatelessWidget {
  const _DisplayModeBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (p, c) =>
          p.filters.displayMode != c.filters.displayMode ||
          (p.status == SearchStatus.initial) !=
              (c.status == SearchStatus.initial),
      builder: (context, state) {
        if (state.status == SearchStatus.initial) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: seg.AppSegmentedControl<DisplayMode>(
                  value: state.filters.displayMode,
                  onChanged: (mode) => context.read<SearchBloc>().add(
                    SearchDisplayModeChanged(mode: mode),
                  ),
                  segments: [
                    seg.AppSegmentedSegment(
                      icon: Icons.view_list_outlined,
                      label: l10n.search_display_mode_list,
                      value: DisplayMode.list,
                    ),
                    seg.AppSegmentedSegment(
                      icon: Icons.map_outlined,
                      label: l10n.search_display_mode_map,
                      value: DisplayMode.map,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: l10n.search_save_this_search_action,
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: () => _onSaveSearch(context, state.filters),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onSaveSearch(BuildContext context, FilterState filters) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SavedSearchesCubit>();
    final label = await showSaveSearchDialog(
      context: context,
      suggestedLabel: filters.query ?? '',
    );
    if (label == null) return; // cancelled
    final outcome = await cubit.save(label: label, filters: filters);
    if (!context.mounted) return;
    final message = switch (outcome) {
      SaveSearchOutcome.saved => l10n.search_save_search_success,
      SaveSearchOutcome.authRequired => l10n.search_save_search_auth_required,
      SaveSearchOutcome.error => l10n.search_save_search_error,
    };
    AppToast.show(
      context,
      message,
      variant: switch (outcome) {
        SaveSearchOutcome.saved => AppToastVariant.success,
        SaveSearchOutcome.authRequired => AppToastVariant.warning,
        SaveSearchOutcome.error => AppToastVariant.error,
      },
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.autofocus,
    this.initialQuery,
    this.onFocusEmptyChanged,
  });

  final bool autofocus;
  final String? initialQuery;

  /// Fired with `true` when the bar is focused AND empty (show recent
  /// searches), `false` otherwise.
  final ValueChanged<bool>? onFocusEmptyChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  void _handleFocusChange() => _notifyFocusEmpty();
  void _handleTextChange() => _notifyFocusEmpty();

  void _notifyFocusEmpty() {
    widget.onFocusEmptyChanged?.call(
      _focusNode.hasFocus && _controller.text.trim().isEmpty,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
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
        focusNode: _focusNode,
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
          // Phase 25 — persist committed (non-empty) queries to recents.
          if (trimmed.isNotEmpty) {
            context.read<RecentSearchesCubit>().record(trimmed);
          }
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

/// A scrollable row of removable chips, one per active filter dimension, shown
/// below the sort/filters row. Tapping a chip's ✕ clears that dimension and
/// re-runs the search; a trailing "clear filters" chip clears them all (the
/// free-text query is left alone — it has its own clear control in the bar).
///
/// Location, price and area collapse to a single category chip (the search
/// state carries IDs/ranges, not display names) — tapping ✕ clears the whole
/// dimension. Purpose, type, rooms and bathrooms show their value.
class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (p, c) => p.filters != c.filters,
      builder: (context, state) {
        final f = state.filters;
        final bloc = context.read<SearchBloc>();
        final chips = <Widget>[];

        void addChip(String label, FilterState cleared) {
          chips.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: InputChip(
                label: Text(label),
                onDeleted: () =>
                    bloc.add(SearchFiltersApplied(filters: cleared)),
              ),
            ),
          );
        }

        if (f.purpose != null) {
          addChip(
            _purposeLabel(f.purpose!, l10n),
            f.copyWith(clearPurpose: true),
          );
        }
        if (f.propertyType != null) {
          addChip(
            _propertyTypeLabel(f.propertyType!, l10n),
            f.copyWith(clearPropertyType: true),
          );
        }
        if (f.governorateId != null || f.cityId != null || f.areaId != null) {
          addChip(
            l10n.search_filter_location_label,
            f.copyWith(
              clearGovernorateId: true,
              clearCityId: true,
              clearAreaId: true,
            ),
          );
        }
        if (f.priceMin != null || f.priceMax != null) {
          addChip(
            l10n.search_filter_price_range_label,
            f.copyWith(
              clearPriceMin: true,
              clearPriceMax: true,
              clearPriceCurrency: true,
            ),
          );
        }
        if (f.rooms != null) {
          final suffix = f.roomsMode == CountFilterMode.atLeast ? '+' : '';
          addChip(
            '${l10n.search_filter_rooms_label}: ${f.rooms}$suffix',
            f.copyWith(clearRooms: true),
          );
        }
        if (f.bathrooms != null) {
          addChip(
            '${l10n.search_filter_bathrooms_label}: ${f.bathrooms}',
            f.copyWith(clearBathrooms: true),
          );
        }
        if (f.areaSizeMin != null || f.areaSizeMax != null) {
          addChip(
            l10n.search_filter_area_size_label,
            f.copyWith(clearAreaSize: true),
          );
        }

        if (chips.isEmpty) return const SizedBox.shrink();

        // Trailing "clear all" — keeps the query (bar owns its own clear).
        chips.add(
          ActionChip(
            label: Text(l10n.search_empty_clear_filters),
            onPressed: () => bloc.add(
              SearchFiltersApplied(filters: FilterState(query: f.query)),
            ),
          ),
        );

        // Intrinsic height (not a fixed SizedBox) so the row grows with the
        // text scale instead of clipping the chips at large font sizes.
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.xs,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: Row(children: chips),
          ),
        );
      },
    );
  }
}

String _purposeLabel(ListingPurpose p, AppLocalizations l10n) {
  switch (p) {
    case ListingPurpose.sale:
      return l10n.listingPurposeSale;
    case ListingPurpose.rent:
      return l10n.listingPurposeRent;
    case ListingPurpose.dailyRent:
      return l10n.listingPurposeDailyRent;
    case ListingPurpose.investment:
      return l10n.listingPurposeInvestment;
  }
}

String _propertyTypeLabel(PropertyType t, AppLocalizations l10n) {
  switch (t) {
    case PropertyType.apartment:
      return l10n.propertyTypeApartment;
    case PropertyType.villa:
      return l10n.propertyTypeVilla;
    case PropertyType.land:
      return l10n.propertyTypeLand;
    case PropertyType.shop:
      return l10n.propertyTypeShop;
    case PropertyType.office:
      return l10n.propertyTypeOffice;
    case PropertyType.farm:
      return l10n.propertyTypeFarm;
    case PropertyType.warehouse:
      return l10n.propertyTypeWarehouse;
    case PropertyType.other:
      return l10n.propertyTypeOther;
  }
}

class _ResultsArea extends StatelessWidget {
  const _ResultsArea();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        // Phase 25 — embedded map presentation of the same filtered results.
        // The map owns its own load/empty/error chrome via SearchMapView.
        if (state.filters.displayMode == DisplayMode.map &&
            state.status != SearchStatus.initial) {
          return SearchMapView(filters: state.filters);
        }
        // Distinct widget types per phase → AnimatedSwitcher crossfades the
        // skeleton into results (or empty/error), but list→list during
        // pagination is the same type, so it updates in place without a fade.
        final child = switch (state.status) {
          SearchStatus.initial => Center(child: Text(l10n.search_placeholder)),
          SearchStatus.loading =>
            state.results.isEmpty
                ? const _SearchSkeleton()
                : _ResultsListView(state: state),
          SearchStatus.failure =>
            state.results.isEmpty
                ? _ErrorView(
                    message: l10n.search_error_message,
                    retryLabel: l10n.search_error_retry,
                    onRetry: () => context.read<SearchBloc>().add(
                      const SearchRefreshRequested(),
                    ),
                  )
                // Failure during pagination — keep showing existing results.
                : _ResultsListView(state: state),
          SearchStatus.success =>
            state.results.isEmpty
                ? _EmptyView(state: state)
                : _ResultsListView(state: state),
        };
        return AnimatedSwitcher(
          duration: reduceMotion(context) ? Duration.zero : AppMotion.base,
          child: child,
        );
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
            Container(
              width: AppSpacing.xxxl + AppSpacing.lg,
              height: AppSpacing.xxxl + AppSpacing.lg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.10),
              ),
              child: Icon(
                Icons.search_off,
                size: AppSpacing.xxl,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.search_empty_title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.search_empty_subtitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
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
        return StaggeredListItem(
          index: itemIndex,
          child: SearchResultCard(item: state.results[itemIndex]),
        );
      },
    );
  }
}

/// Shimmer placeholder rows (116dp, matching [SearchResultCard]) shown while the
/// first search page loads.
class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        child: SizedBox(height: 116, child: LoadingState.card()),
      ),
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
    return const Padding(
      padding: EdgeInsetsDirectional.all(AppSpacing.lg),
      child: AppSpinner(),
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
