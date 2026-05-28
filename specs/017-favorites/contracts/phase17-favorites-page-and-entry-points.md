# Contract — FavoritesPage + entry points

**Files**: `lib/features/favorites/presentation/pages/favorites_page.dart`, `favorites_page_bloc.dart`, `favorites_empty_state.dart`, `lib/core/routing/app_router.dart`, `lib/features/profile/presentation/pages/profile_page.dart`
**Spec**: FR-020..FR-027. **Decisions**: R-115, R-117.

## Route

- `AppRoutes.favorites = '/favorites'`, `AppRouteNames.favorites = 'favorites'`.
- `GoRoute` builder → `FavoritesPage`. `redirect`: returns `AppRoutes.login` when `AuthBloc.state is Unauthenticated` (deep-link cold-launch hardening, R-115); else `null`.

## Entry point (Q1=A)

A `ListTile` on the Profile page, inserted immediately after the `profile_private_section` tile (current `profile_page.dart` lines 132–138) and before the sign-out divider:

```dart
ListTile(
  contentPadding: EdgeInsets.zero,
  leading: const Icon(Icons.favorite_border),
  title: Text(l10n.profile_favorites_tile),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push(AppRoutes.favorites),
)
```

## `FavoritesPageBloc`

- Events: `FavoritesPageOpened`, `FavoritesPageRefreshRequested`, `FavoritesPageMoreLoaded`.
- States: `FavoritesPageLoading`, `FavoritesPageLoaded({items, hasMore})`, `FavoritesPageError(failure)`.
- `LoadFavorites({cursor, limit: 30})` cursor on `favorited_at DESC` (R-117 / FR-027).

## `FavoritesPage` composition

- `AppBar`: `DeepLinkAwareBackButton` leading + `l10n.favorites_page_title`.
- Body: `RefreshIndicator` over `ListView.builder` of cards (image/title/price/location + embedded `FavoriteHeartButton`).
  - Available card (`is_available`): tap → `context.push(AppRoutes.listingDetailsFor(item.id))`.
  - Unavailable card (`!is_available`): renders `favorite_unavailable_indicator` badge AND stays tappable → same details route (Q4=A / FR-025).
  - Pagination: `FavoritesPageMoreLoaded` on scroll-end while `hasMore`.
- Empty (`items.isEmpty`): `FavoritesEmptyState` with `favorites_empty_state` (FR-026 / SC-012).

## Behavioral contract

- Lists exactly the caller's favorites, newest-saved first (SC-004); no other user's rows (enforced by `v_favorites` RLS).
- Un-saving from a card removes it from the list immediately and deletes the row (SC-002); persists across restart (SC-009).
- Bounded query — `LIMIT`/cursor, no unbounded scan (SC-015).
