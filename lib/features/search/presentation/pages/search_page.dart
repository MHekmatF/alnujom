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
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/crown_underline_tabs.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/main_bottom_nav.dart';
import '../../../../core/widgets/publish_fab.dart';
import '../../../../core/widgets/reduce_motion.dart';
import '../../../../core/widgets/staggered_list_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/localized_numbers.dart';
import '../../../../shared/util/location_line.dart';
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
import '../../../../core/settings/listing_view_mode.dart';
import '../../../../core/widgets/ds/ds_listing_card.dart';
import '../../../../core/widgets/ds/ds_listing_card_data.dart';
import '../../domain/entities/search_result_item.dart';

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
    final colors = AppColors.of(context);
    // DC "Blue Crown" — the search crown (back + field + bookmark, purpose
    // tabs, filter chips) sits on the brand header; the results live in a white
    // sheet whose rounded top corners reveal the blue crown behind them.
    return Scaffold(
      backgroundColor: colors.brandHeader,
      body: Column(
        children: [
          _SearchCrown(
            autofocusSearchBar: widget.autofocusSearchBar,
            initialQuery: widget.initialQuery,
            onFocusEmptyChanged: _onFocusEmptyChanged,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadiusDirectional.vertical(
                  top: Radius.circular(AppRadii.sheet),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const _ResultsSheetHeader(),
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
                                    filters: bloc.state.filters.copyWith(
                                      query: query,
                                    ),
                                  ),
                                );
                                context.read<RecentSearchesCubit>().record(
                                  query,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(current: MainTab.search),
      floatingActionButton: const PublishFab(),
    );
  }
}

/// DC search crown — the blue brand header carrying the back button, the white
/// search field, a "save this search" bookmark, the purpose underline tabs, and
/// the horizontal filter-chips row.
class _SearchCrown extends StatelessWidget {
  const _SearchCrown({
    required this.autofocusSearchBar,
    required this.initialQuery,
    required this.onFocusEmptyChanged,
  });

  final bool autofocusSearchBar;
  final String? initialQuery;
  final ValueChanged<bool> onFocusEmptyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      color: colors.brandHeader,
      padding: EdgeInsetsDirectional.only(
        top: topInset + AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back (when pushed) + search field + save-this-search bookmark.
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  _CrownIconButton(
                    icon: Icons.arrow_forward,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: _CrownSearchField(
                    autofocus: autofocusSearchBar,
                    initialQuery: initialQuery,
                    onFocusEmptyChanged: onFocusEmptyChanged,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                BlocBuilder<SearchBloc, SearchState>(
                  buildWhen: (p, c) => p.filters != c.filters,
                  builder: (context, state) => _CrownIconButton(
                    icon: Icons.bookmark_border,
                    onTap: () => saveCurrentSearch(context, state.filters),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Purpose tabs (للبيع/للإيجار/إيجار يومي) drive filters.purpose.
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: BlocBuilder<SearchBloc, SearchState>(
              buildWhen: (p, c) => p.filters.purpose != c.filters.purpose,
              builder: (context, state) => CrownUnderlineTabs(
                labels: [
                  l10n.listingPurposeSale,
                  l10n.listingPurposeRent,
                  l10n.listingPurposeDailyRent,
                ],
                selectedIndex: _purposeIndex(state.filters.purpose),
                fontSize: 14,
                onChanged: (i) {
                  const purposes = [
                    ListingPurpose.sale,
                    ListingPurpose.rent,
                    ListingPurpose.dailyRent,
                  ];
                  context.read<SearchBloc>().add(
                    SearchFiltersApplied(
                      filters: state.filters.copyWith(purpose: purposes[i]),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _SearchFilterChipsRow(),
        ],
      ),
    );
  }
}

int _purposeIndex(ListingPurpose? purpose) => switch (purpose) {
  ListingPurpose.sale => 0,
  ListingPurpose.rent => 1,
  ListingPurpose.dailyRent => 2,
  _ => -1,
};

/// Opens the filter bottom sheet, applying the returned filters to the bloc.
void openSearchFilterSheet(BuildContext context, FilterState filters) {
  final bloc = context.read<SearchBloc>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SearchFilterSheet(
      initialFilters: filters,
      onApply: (f) => bloc.add(SearchFiltersApplied(filters: f)),
    ),
  );
}

/// A 42px circular white-icon action button on the blue crown.
class _CrownIconButton extends StatelessWidget {
  const _CrownIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, size: 24, color: colors.onBrandHeader),
      ),
    );
  }
}

/// The DC crown search field: a white (headerField) rounded field with a
/// leading search glyph hosting the existing [_SearchBar] text field.
class _CrownSearchField extends StatelessWidget {
  const _CrownSearchField({
    required this.autofocus,
    required this.initialQuery,
    required this.onFocusEmptyChanged,
  });

  final bool autofocus;
  final String? initialQuery;
  final ValueChanged<bool> onFocusEmptyChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colors.brandHeaderField,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(Icons.search, size: 20, color: colors.onSurfaceVariant),
          Expanded(
            child: _SearchBar(
              autofocus: autofocus,
              initialQuery: initialQuery,
              onFocusEmptyChanged: onFocusEmptyChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Saves the current filters as a named saved search (the crown bookmark),
/// surfacing the outcome as a toast.
Future<void> saveCurrentSearch(
  BuildContext context,
  FilterState filters,
) async {
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

/// DC white-sheet header — the result count on the start, the sort control and a
/// list⇄map toggle pill on the end. Hidden in the initial (pre-first-search)
/// state to keep the empty surface calm.
class _ResultsSheetHeader extends StatelessWidget {
  const _ResultsSheetHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (p, c) =>
          p.results.length != c.results.length ||
          p.filters.displayMode != c.filters.displayMode ||
          (p.status == SearchStatus.initial) !=
              (c.status == SearchStatus.initial),
      builder: (context, state) {
        if (state.status == SearchStatus.initial) {
          return const SizedBox.shrink();
        }
        final isMap = state.filters.displayMode == DisplayMode.map;
        return Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.lg,
            end: AppSpacing.sm,
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.results.isNotEmpty
                      ? l10n.search_results_count(state.results.length)
                      : l10n.nav_search,
                  style: styles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Flexible(child: InlineSortControl()),
              const SizedBox(width: AppSpacing.sm),
              _OutlinePill(
                icon: isMap ? Icons.view_list : Icons.map,
                label: isMap
                    ? l10n.search_display_mode_list
                    : l10n.search_display_mode_map,
                onTap: () => context.read<SearchBloc>().add(
                  SearchDisplayModeChanged(
                    mode: isMap ? DisplayMode.list : DisplayMode.map,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small outline pill button (icon + label) — the DC sort/map affordance.
class _OutlinePill extends StatelessWidget {
  const _OutlinePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: colors.surface,
      shape: StadiumBorder(side: BorderSide(color: colors.outlineStrong)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colors.onSurface),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: styles.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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

/// DC filter-chips row on the blue crown — a tonal "الفلاتر" entry button (with
/// an active-filter count), a removable white chip per active non-purpose
/// dimension (purpose lives in the crown tabs; the query has its own clear in
/// the field), and a "الموثّقة فقط" verified toggle.
class _SearchFilterChipsRow extends StatelessWidget {
  const _SearchFilterChipsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (p, c) => p.filters != c.filters,
      builder: (context, state) {
        final f = state.filters;
        final bloc = context.read<SearchBloc>();

        final removable = <Widget>[];
        void addChip(String label, FilterState cleared) {
          removable.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: _RemovableFilterChip(
                label: label,
                onRemove: () =>
                    bloc.add(SearchFiltersApplied(filters: cleared)),
              ),
            ),
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

        final activeCount = removable.length + (f.verifiedOnly == true ? 1 : 0);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              _FiltersEntryChip(
                count: activeCount,
                onTap: () => openSearchFilterSheet(context, f),
              ),
              const SizedBox(width: AppSpacing.sm),
              ...removable,
              _VerifiedToggleChip(
                on: f.verifiedOnly == true,
                onToggle: () => bloc.add(
                  SearchFiltersApplied(
                    filters: f.verifiedOnly == true
                        ? f.copyWith(clearVerifiedOnly: true)
                        : f.copyWith(verifiedOnly: true),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The tonal "الفلاتر" entry chip that opens the filter sheet, with a badge
/// showing how many filter dimensions are active.
class _FiltersEntryChip extends StatelessWidget {
  const _FiltersEntryChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: colors.primaryContainer,
      borderRadius: appRadius(AppRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 17, color: colors.onPrimaryContainer),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.search_filters_button,
                style: styles.labelMedium.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  alignment: Alignment.center,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onPrimaryContainer,
                    borderRadius: appRadius(AppRadii.pill),
                  ),
                  child: Text(
                    formatLocalizedNumber(
                      count,
                      Localizations.localeOf(context),
                    ),
                    style: styles.labelSmall.copyWith(
                      color: colors.primaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A white (headerField) removable filter chip — label + a trailing ✕ that
/// clears that dimension.
class _RemovableFilterChip extends StatelessWidget {
  const _RemovableFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: colors.brandHeaderField,
      borderRadius: appRadius(AppRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md,
            end: AppSpacing.sm,
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: styles.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.close, size: 16, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "الموثّقة فقط" verified-only toggle chip — green when on, white when off.
class _VerifiedToggleChip extends StatelessWidget {
  const _VerifiedToggleChip({required this.on, required this.onToggle});

  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Material(
      color: on ? colors.verifiedContainer : colors.brandHeaderField,
      borderRadius: appRadius(AppRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (on) ...[
                Icon(Icons.check, size: 16, color: colors.onSuccess),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                l10n.filter_verified_only,
                style: styles.labelMedium.copyWith(
                  color: on ? colors.onSuccess : colors.onSurface,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          SearchStatus.initial => const _SearchSkeleton(),
          SearchStatus.loading =>
            state.results.isEmpty
                ? const _SearchSkeleton()
                : _ResultsListView(state: state),
          SearchStatus.failure =>
            state.results.isEmpty
                ? ErrorState(
                    title: l10n.search_error_title,
                    message: l10n.search_error_message,
                    variant: ErrorStateVariant.network,
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
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
                color: colors.primary.withValues(alpha: 0.10),
              ),
              child: Icon(
                Icons.search_off,
                size: AppSpacing.xxl,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.search_empty_title,
              style: styles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.search_empty_subtitle,
              style: styles.bodyMedium.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            // The clear-filters CTA only makes sense when something IS
            // filtered (incl. a query) — on a virgin empty catalog it would
            // be a dead button.
            if (state.filters.hasAnyActiveFilter) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.read<SearchBloc>().add(
                  const SearchFiltersApplied(filters: FilterState.empty),
                ),
                child: Text(l10n.search_empty_clear_filters),
              ),
            ],
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
      // lg horizontal padding — same single screen margin as the header rows.
      // Extra bottom clearance so the floating publish FAB never covers the
      // last card's content (035 craft wave).
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.xxxl + AppSpacing.xl,
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
          final colors = AppColors.of(context);
          final styles = AppTextStyles.of(context);
          return Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: appRadius(AppRadii.md),
            ),
            child: Text(
              l10n.search_arabic_hint(
                _suggestionFromQuery(state.filters.query!),
              ),
              style: styles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
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
          child: _SearchFeedCard(item: state.results[itemIndex]),
        );
      },
    );
  }
}

/// Phase 035 — maps a [SearchResultItem] into the unified [DsListingCard] at the
/// user's chosen [ListingViewMode]. Uses `context.push` so the search stack (and
/// [SearchBloc]) survives the back-navigation from the detail page.
class _SearchFeedCard extends StatelessWidget {
  const _SearchFeedCard({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isAr = locale.languageCode == 'ar';
    final gov = isAr ? item.governorateNameAr : item.governorateNameEn;
    final city = isAr ? item.cityNameAr : item.cityNameEn;
    // Same dedupe rules as every other feed (kills 'دمشق، دمشق').
    final location = listingLocationLine(governorate: gov, city: city);
    final data = DsListingCardData(
      id: item.id,
      title: item.title,
      priceText: l10n.priceWithCurrency(
        formatLocalizedNumber(item.primaryAmount.round(), locale),
        item.primaryCurrency,
      ),
      purpose: item.purpose,
      locationText: location.isEmpty ? '—' : location,
      imageUrl: item.mainImagePath,
      agencyId: item.agencyId,
      agencyName: item.agencyName,
      agencyLogoUrl: item.agencyLogoUrl,
      publishedAt: item.publishedAt,
    );
    return ValueListenableBuilder<ListingViewMode>(
      valueListenable: ListingViewModePref.notifier,
      builder: (context, mode, _) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        child: DsListingCard(
          data: data,
          mode: mode,
          onTap: () => context.push(AppRoutes.listingDetailsFor(item.id)),
        ),
      ),
    );
  }
}

/// Shimmer placeholder rows shown while the first search page loads. Mode-aware
/// so the skeleton height approximates the [DsListingCard] the feed will render
/// (tall photo card in comfortable/balanced, dense row in compact) instead of a
/// fixed block that jumps size on the skeleton→results swap.
class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ListingViewMode>(
      valueListenable: ListingViewModePref.notifier,
      builder: (context, mode, _) {
        final height = switch (mode) {
          ListingViewMode.comfortable => 300.0,
          ListingViewMode.balanced => 272.0,
          ListingViewMode.compact => 128.0,
        };
        return ListView.builder(
          // Mirrors _ResultsListView's lg margin so the skeleton→results
          // crossfade doesn't shift horizontally.
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: SizedBox(height: height, child: const LoadingState.card()),
          ),
        );
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
