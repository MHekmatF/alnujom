# Contract: Home map tile entry-point

**Phase**: 15 — Map View
**Owner**: Sub-Phase G1 (entry-point wiring)
**Files**: `lib/features/home/presentation/widgets/map_entry_tile.dart` (CREATE), `lib/features/home/presentation/pages/home_page.dart` (UPDATE)
**Spec refs**: FR-007 (entry point a), US1, SC-001 (reachability), Q8=B (home entry shape)
**Research refs**: R-91 (slot decision)

## Widget composition

```dart
class MapEntryTile extends StatelessWidget {
  const MapEntryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdBorderRadius),
        child: InkWell(
          onTap: () => context.go(
            AppRoutes.map,
            extra: const MapEntryFromHome(),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.home_map_tile_title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.home_map_tile_subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_ios
                      : Icons.arrow_forward_ios,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

## Insertion point in `home_page.dart`

Per R-91, insert `const SliverToBoxAdapter(child: MapEntryTile())` between the existing `PropertyTypeShortcutRow` sliver and the "Latest listings" header sliver:

```dart
// BEFORE (Phase 14 state):
return CustomScrollView(
  controller: _scrollController,
  slivers: [
    const SliverToBoxAdapter(child: HeroSearchBar()),
    const SliverToBoxAdapter(child: PropertyTypeShortcutRow()),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
        ),
        child: Text(
          l10n.home_latest_listings_header,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
    ..._buildFeedSlivers(context, state, currenciesByCode, l10n),
  ],
);

// AFTER (Phase 15 G1 addition):
return CustomScrollView(
  controller: _scrollController,
  slivers: [
    const SliverToBoxAdapter(child: HeroSearchBar()),
    const SliverToBoxAdapter(child: PropertyTypeShortcutRow()),
    const SliverToBoxAdapter(child: MapEntryTile()),  // NEW
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
        ),
        child: Text(
          l10n.home_latest_listings_header,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
    ..._buildFeedSlivers(context, state, currenciesByCode, l10n),
  ],
);
```

## Behavioral contract

1. **Visibility**: The tile MUST be visible on the home page without scrolling on the Infinix Note 8 portrait viewport (480 dp width, ~960 dp height). With the hero search bar (~100 dp) + chip row (~120 dp) + tile (~80 dp) above the latest-listings header, the tile sits within the first ~300 dp — well above the fold.
2. **Tap target**: Entire card area is tappable (InkWell covers the whole padding).
3. **Navigation**: `onTap` calls `context.go(AppRoutes.map, extra: const MapEntryFromHome())`. The navigation MUST use `go` (not `push`) so the back button on `MapPage` lands on home (Phase 13 Q4=D pattern: `Navigator.canPop()` is false → routes to home).
4. **Localization**: Title + subtitle flow through `l10n.home_map_tile_title` + `l10n.home_map_tile_subtitle` (ARB keys added in Sub-Phase F).
5. **Theming**: All colors / typography / spacing read from `Theme.of(context)` and `AppSpacing` / `AppRadii` tokens. No inline hex literals.
6. **Direction-awareness**: The trailing chevron icon flips between `Icons.arrow_forward_ios` (LTR) and `Icons.arrow_back_ios` (RTL) based on `Directionality.of(context)`.

## Acceptance test (manual)

- Cold-launch app in `ar` + light. Home page renders. Confirm map tile is visible above the latest-listings header without scrolling. Tap tile. Confirm map page opens at Syria-wide overview.
- Repeat in `en` + light, `ar` + dark, `en` + dark. Confirm tile renders correctly in all 4 combinations.
- On `MapPage`, press back. Confirm return to home page (not to a parent route).
