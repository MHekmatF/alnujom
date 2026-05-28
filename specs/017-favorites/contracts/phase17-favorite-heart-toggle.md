# Contract — `FavoriteHeartButton` + `FavoritesCubit` toggle

**Files**: `lib/features/favorites/presentation/widgets/favorite_heart_button.dart`, `lib/features/favorites/presentation/bloc/favorites_cubit.dart`
**Spec**: FR-002, FR-005, FR-006, FR-008, FR-009. **Decisions**: R-110, R-116, R-118.

## `FavoritesCubit` (`@lazySingleton`)

State: `FavoritesState({Set<String> favoritedIds, bool isSignedIn})`.

- Subscribes to `AuthBloc` at construction:
  - signed-in state → `LoadFavoriteIds()` → emit hydrated set, `isSignedIn=true`.
  - `Unauthenticated` → emit empty set, `isSignedIn=false`.
- `bool isFavorited(String listingId)` → `favoritedIds.contains(listingId)`.
- `Future<void> toggle(String listingId)`:
  1. Optimistically add/remove `listingId` from the set; emit.
  2. Call `AddFavorite(listingId)` (if now favorited) or `RemoveFavorite(listingId)` (if now removed).
  3. On `Result.failure`: revert the set, emit, and signal the UI to show `favorite_toggle_failed` (FR-006).

## `FavoriteHeartButton({required String listingId})`

- `BlocSelector<FavoritesCubit, FavoritesState, bool>` on `isFavorited(listingId)` → only relevant hearts rebuild (FR-005).
- Icon: `Icons.favorite` (filled, `colorScheme.error`) when favorited; `Icons.favorite_border` otherwise. Tokens only (FR-029).
- `semanticLabel`: `favorite_unsave_label` when favorited, else `favorite_heart_label`.
- `onTap`:
  - if `!state.isSignedIn` (anonymous) → show `favorite_sign_in_prompt` snackbar + `context.push(AppRoutes.login)`; NO toggle, NO pre-auth save (Q2=A / FR-008 / FR-009).
  - else → `getIt<FavoritesCubit>().toggle(listingId)`.

## Host surfaces (embed the same widget — R-118)

| Surface | File | Placement |
|---------|------|-----------|
| Home feed card | `home_listing_card.dart` | `PositionedDirectional(top, end)` on the hero `Stack` |
| Search result card | `search_result_card.dart` | top-end of the image / trailing the title |
| Map marker preview | `marker_preview_popover.dart` | action row near "View details" / close |
| Listing details | `per_listing_action_block.dart` | the existing Favorite `_ActionButton` (Share/Report untouched) |

## Behavioral contract

- A toggle on any surface updates the shared set → every visible heart for that id reconciles instantly, no server round-trip (SC-003).
- Failure reverts the optimistic state and never leaves a partial DB state (the RPC/DELETE are atomic).
